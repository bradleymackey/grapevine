//
//  BCFirebaseChatManager.swift
//  Backchat
//
//  Created by Bradley Mackey on 07/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase
import JDStatusBarNotification
import MBProgressHUD
import SDWebImage

/// # BCChatInterfaceDelegate
/// The protocol that should be conformed to recieve event notifications from `BCChatInterface`
/// - note: this protocol is of type `class` which guarantees it will only be used on classes, so we can declare the `delegate` as weak.
public protocol BCFirebaseChatManagerDelegate: class {
	/// A new message was added to the chat, you should render this in your `tableView`
	func childAdded(message:BCFirebaseChatMessage)
	/// The number of views on a profile has changed, so the new value to a user.
	func viewConuterChange(views:Int)
	/// Called if user lost permission to view the current chat.
	func lostPermissionForChat()
	/// Called when other users start/stop typing
	func otherUsersAre(typing:Bool)
	/// Called if we could not delete a message for some reason.
	func couldNotDeleteMessage(reason:String)
	/// Called when we should remove an individual messsage
	func removeMessageFromView(message: BCFirebaseChatMessage)
	/// Called when the blocking operation is complete
	func userBlockFinished(success:Bool,reason:String)
	/// Called when the flagging operation is complete
	func messageFlagFinished(success:Bool,reason:String?)
	
	
}

/// # BCChatInterface
/// Manages all chat, view count and typing operations to a user's profile in the Realtime Database. It basically is the controller of most of the interactions to take place with the Realtime Database.
public final class BCFirebaseChatManager {
	
	// MARK: - Properties
	
	/// How many previous messages should be fetched from the realtime database on each fetch call
	public let getLast:UInt
	/// An instance of `BCChatInterfaceDelegate`, called when needed.
	/// - important: this must be weak to avoid a strong reference cycle to the `BCFirebaseChatController`.
	public weak var delegate:BCFirebaseChatManagerDelegate?
	/// A reference to the user's ephemeral node.
	public let userEphemeralRef:FIRDatabaseReference
	/// A reference to the user's info node
	public let userInfoRef:FIRDatabaseReference
	/// The current category of the chat being viewed, so we know whether this is the current user or another user.
	public let chatCategory:BCFirebaseChatCategory
	/// The facebook ID of the user chat currently being looked at.
	public let facebookID:String
	
	/// The number of times that we should try and increment the view counter before we give up.
	public static let retryIncrementViewCounterLimit = 4
	
	/// The number of times we have tried to set the view counter. Exists so we don't retry too many times and use loads of data.
	private var retryIncrementFails:Int = 0 {
		willSet {
			if newValue >= BCFirebaseChatManager.retryIncrementViewCounterLimit {
				FIRCrashMessage("Failed to increment the counter for \(facebookID) - retry limit reached")
				FIRAnalytics.logEvent(withName: "view_increment_failed", parameters: nil)
			}
		}
	}
	
	/// This property indicates whether or not we have already registered the view on the profile, which should occur the first time that we observe the view counter.
	private var hasIncremeatedViewCounter = false {
		didSet {
			// check whether we should try to increment the view counter or not
			if hasIncremeatedViewCounter == false && chatCategory == .user && retryIncrementFails < BCFirebaseChatManager.retryIncrementViewCounterLimit {
				// increment the counter, because we haven't yet
				retryIncrementFails += 1
				attemptToIncrementCounter()
			}
		}
	}
	
	/// the current display status of the typing indicator - when set this will either add or remove the typing indicator
	/// - important: this is only set every 3 seconds to avoid glitchy behaviour, the actual real value of the current typing indicator can be seen at `currentTypingValue`.
	public var otherUsersTyping:Bool = false {
		willSet {
			// notify the view controller of the new typing value
			self.delegate?.otherUsersAre(typing: newValue)
		}
	}
	
	/// The current typing value as reflected from the Realtime Database
	private var currentTypingValue:Bool = false
	
	/// whether or not the typing value should get set due to if we are currently typing or not.
	private var shouldSetTypingValue:Bool = true
	
	/// where we save the URL's for all the downloaded images
	private var imageURLsForSavedCache = Set<URL>()
	
	/// background queue to process messages on (everything should be dispatched `sync`, because the datasource in the ChatController is simply an array, so order MUST be maintained)
	private let messageQueue = DispatchQueue(label: "com.bradleymackey.Backchat.messageQueue", qos: .userInitiated)
	
	
	private var updateTimer:Timer!
	
	
	/// This should be set from the view controller to tell the database when we are typing (or not typing)
	public var typingStatus = false {
		didSet {
			// so that we only set the typing value if we need to
			if currentTypingValue != typingStatus {
				set(typing: typingStatus)
			}
		}
	}

	// MARK: - Lifecycle
	
	init(facebookID:String, getLast:UInt, chatCategory:BCFirebaseChatCategory) {
		// log that we have viewed a chat
		FIRAnalytics.logEvent(withName: "view_chat", parameters: ["facebookID": facebookID as NSObject])
		// get the correct reference via hashing
		let userID = facebookID + "_" + facebookID.saltedMD5
		// set reference and observe chat
		self.getLast = getLast
		self.userEphemeralRef = FIRDatabase.database().reference().child("\(BCFirebaseDBConstants.ephemeral)/\(userID)")
		self.userInfoRef = FIRDatabase.database().reference().child("\(BCFirebaseDBConstants.info)/\(userID)")
		userInfoRef.child(BCFirebaseDBConstants.typing).onDisconnectRemoveValue() // remove typing value when we disconnnect
		self.chatCategory = chatCategory
		self.facebookID = facebookID
		observeChat()
		observeViews()
		observeTyping()
		// only increment counter if they are not the current user.
		if chatCategory == .user {
			attemptToIncrementCounter()
		}
	}
	
	deinit {
		// dispatch to a background queue
		// Remove all the observed areas of the user's profile.
		self.userEphemeralRef.child(BCFirebaseDBConstants.messages).removeAllObservers()
		self.userEphemeralRef.child(BCFirebaseDBConstants.views).removeAllObservers()
		self.userInfoRef.child(BCFirebaseDBConstants.typing).removeAllObservers()
		// remove the images downloaded in this chat from the in memory cache, to save on memory
		for url in self.imageURLsForSavedCache {
			SDImageCache.shared().removeImage(forKey: url.absoluteString, fromDisk: false)
		}
		
	}
	
	// MARK: - Database Reading Methods
	
	/// Starts an oberver on the 'msgs' node for a current user, ordered by timestamp.
	private func observeChat() {
		// CHECK if the user wants to view flagged messages, if they don't then
		let messagesRef = userEphemeralRef.child(BCFirebaseDBConstants.messages)
		let query = BCAboutController.hideFlaggedMessages ? messagesRef.queryOrdered(byChild: "flg").queryEnding(atValue: false) : messagesRef.queryOrdered(byChild: BCFirebaseDBConstants.timestamp)
		query.queryLimited(toLast: getLast).observe(.childAdded, with: { [weak self] snapshot in
			guard let strongSelf = self else { return }
			// add the new message to the messageQueue
			strongSelf.messageQueue.async {
				// create the ChatMessage and notify the delegate
				let chatMessage = BCFirebaseChatMessage(from: snapshot)
				// if this message has an image associated with it, save the URL to the list of URLs so we know what images to clear when we leave the chat.
				if let url = chatMessage.imageLink {
					strongSelf.imageURLsForSavedCache.insert(url)
				}
				// notify the delegate of childAdded
				DispatchQueue.main.sync {
					strongSelf.delegate?.childAdded(message: chatMessage)
					// message recieved, so remove the typing indicator, otherwise it could cause confusion (even if there are other users typing), because of the fact we persist the typing indicator whilst the current user is typing, so if the current user is still typing and recieves a message (from the only other present user in the chat) it would have shown that someone was still typing, when they are not becuase the message has just been recieved.
					strongSelf.otherUsersTyping = false
					
				}
			}
			
			}, withCancel: { [weak self] error in
				// This block is executed if the client no longer has permission to read this area for whatever reason
				guard let strongSelf = self else { return }
				strongSelf.delegate?.lostPermissionForChat()
		})
	}
	
	/// Starts an oberver on the views node for a current user
	private func observeViews() {
		// we must increment the counter in here because the value we set depends on the value we get.
		userEphemeralRef.child(BCFirebaseDBConstants.views).observe(.value, with: { [weak self] snapshot in
			guard let strongSelf = self else { return }
			guard let views = Int((snapshot.value as AnyObject).description) else {
				// notify delegate that there are 0 views
				strongSelf.delegate?.viewConuterChange(views: 0); return
			}
			strongSelf.delegate?.viewConuterChange(views: views) // notify the delegate of the new view count
		})
	}
	
	/// Starts an oberver on the typing node for a current user
	private func observeTyping() {
		
		userInfoRef.child(BCFirebaseDBConstants.typing).observe(.value, with: { [weak self] snapshot in
			guard let strongSelf = self else { return }
			guard snapshot.value is Bool else {
				// no value means users are not typing
				print("typing stopped")
				strongSelf.currentTypingValue = false; return
			}
			print("type")
			// if there is a value here, it means they are typing.
			strongSelf.currentTypingValue = true
		})
	}
	
	// prevent memory leaks
	public func stopUpdateTimer() {
		updateTimer?.invalidate()
	}
	
	// restart if we come back
	public func restartUpdateTimer() {
		updateTimer?.invalidate()
		// set the timer that should monitor that we only send updated values to the delegate every 3 seconds
		updateTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(BCFirebaseChatManager.notifyDelegateOfTypingStatusChangeIfNeeded), userInfo: nil, repeats: true)
	}
	
	/// Function that only notifys the `BCFirebaseChatManagerDelegate` of a typing change at certain intervals. Otherwise there could be glitchy flashing of the typing indicator if people start and stop typing in rapid succession.
	@objc private func notifyDelegateOfTypingStatusChangeIfNeeded() {
		// if there has been a change, notify the delegate, as long as we're sure it wasnt us who did the typing
		if (currentTypingValue != otherUsersTyping) && shouldSetTypingValue {
			otherUsersTyping = currentTypingValue
		}
	}
	
	// MARK: - Database Writing Methods
	
	/// Will increment the counter if the security rules of the database allow it. This may not be allowed the first time due to data sync, so this function may be called a few times in succession
	private func attemptToIncrementCounter() {
		userEphemeralRef.child(BCFirebaseDBConstants.views).observeSingleEvent(of: .value, with: { [weak self] snapshot in
			guard let strongSelf = self else { return }
			guard let views = Int((snapshot.value as AnyObject).description) else {
				strongSelf.set(views: 1)
				return
			}
			strongSelf.set(views: views+1)
		})
	}
	
	/// Function that physically increments the view counter in the database.
	private func set(views:Int) {
		userEphemeralRef.child(BCFirebaseDBConstants.views).setValue(views) { [weak self] (error, ref) in
			guard let strongSelf = self else { return }
			// if there was an error, we will have to try and set the view counter again
			strongSelf.hasIncremeatedViewCounter = (error == nil)
		}
	}
	
	/// Sets whether there should be typing indicator or not in a chat.
	private func set(typing:Bool) {
		if typing {
			// if we are typing, we should persist the state that the typing indicator was in for the whole time we are typing, this will ignore any updates posted by ourself
			shouldSetTypingValue = false
			// set that we are typing in the database
			userInfoRef.child(BCFirebaseDBConstants.typing).setValue(true) { err, ref in
				print(ref)
			}
		} else {
			// we should now be able to view the actual value of the typing indicator as set by other users
			shouldSetTypingValue = true
			// restart update timer so we don't see our own typing
			restartUpdateTimer()
			// set that we are no longer typing in the database
			userInfoRef.child(BCFirebaseDBConstants.typing).removeValue()
		}
	}
	
	// MARK: - Blocking
	
	/// Deletes a SINGLE given message from a chat (only works if they are the current user for the chat)
	/// - important: this code should only be used for removing a single message
	public func delete(message:BCFirebaseChatMessage) {
		let userID = facebookID + "_" + facebookID.saltedMD5
		message.deleteMessage(facebookIDLocation: userID) { (completed, statusMessage) in
			if !completed {
				self.delegate?.couldNotDeleteMessage(reason: statusMessage)
			} else {
				self.delegate?.removeMessageFromView(message: message)
			}
		}
	}
	
	/// Blocks a user from a given message in the data source.
	public func block(message:BCFirebaseChatMessage) {
		// user not allowed to block themself
		if message.uid == "current" { self.delegate?.userBlockFinished(success: false, reason: "You cannot block yourself."); return }
		let userIDtoBlock = message.uid
		let userSaltedID = facebookID + "_" + facebookID.saltedMD5
		let toBlockRef = FIRDatabase.database().reference().child(BCFirebaseDBConstants.block).child(userSaltedID).child(userIDtoBlock)
		// set this user as blocked (with their username as the value incase I one day add the ability to remove a blocked user)
		toBlockRef.setValue(message.username) { error, ref in
			let reason = error == nil ? "This user can no longer view or post to your chat." : "Check your internet connection and try again."
			self.delegate?.userBlockFinished(success: error == nil, reason: reason)
			if let err = error {
				FIRCrashMessage("could not block user: \(err.localizedDescription)")
			}
		}
	}
	
	public func flag(messageFor key:String, uid:String) {
		if uid == "current" { self.delegate?.messageFlagFinished(success: false, reason: "You cannot flag your own messages."); return }
		let flagRef = self.userEphemeralRef.child(BCFirebaseDBConstants.messages).child(key).child("flg")
		flagRef.setValue(true) { (error, ref) in
			let message = error == nil ? nil : "This message has already been flagged."
			self.delegate?.messageFlagFinished(success: error == nil, reason: message)
		}
	}
	
	
}
