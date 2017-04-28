//
//  BCFirebaseChatMessage.swift
//  Backchat
//
//  Created by Bradley Mackey on 30/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase
import JDStatusBarNotification

/// # BCFirebaseChatMessage
/// This represents a chat message for the Firebase chat.
public struct BCFirebaseChatMessage: Equatable {
	
	// MARK: - Properties
	
	/// The key in the realtime database of this message (so we can delete it later)
	public let firebaseDatabaseKey:String?
	/// The username of the user (as it should be displayed)
	public let username:String
	/// The message that should be displayed
	public let message:String?
	/// The link to an image in Firebase Storage
	public let imageLink:URL?
	/// The link to a video in Firebase Storage
	public let videoLink:URL?
	/// The user's profile emoji
	public let emoji:String
	/// The user's colour letter (use this to get a UIColor)
	public let colourLetter:String
	/// The time that this message was sent
	public let timestamp:Date
	/// The notification token for the user that sent the message
	public let notificationToken:String?
	/// The user's UID (used for blocking)
	public let uid:String
	/// The chat catergory to which we are posting in
	public let chatCategory:BCFirebaseChatCategory
	
	// MARK: - Lifecycle

	/// Initalise a `BCFirebaseChatMessage` from an `FIRDataSnapshot`.
	/// - parameter snapshot: the message snapshot as we get from the `childAdded` event.
	public init(from snapshot:FIRDataSnapshot) {
		// get the key, so we know which message to delete later on
		firebaseDatabaseKey = snapshot.key
		
		// we can set the message, link and notification property directly because we get `String?`, which we want - because these properties are allowed to be optional
		message = snapshot.childSnapshot(forPath: BCFirebaseDBConstants.message).value as? String
		notificationToken = snapshot.childSnapshot(forPath: BCFirebaseDBConstants.messageNotificationToken).value as? String
		uid = snapshot.childSnapshot(forPath: BCFirebaseDBConstants.userID).value as? String ?? "ERROR"
		// set the image link
		if let imageLinkValue = snapshot.childSnapshot(forPath: BCFirebaseDBConstants.imageLink).value as? String {
			imageLink = URL(string: imageLinkValue)
		} else {
			imageLink = nil
		}
		
		
		if let videoLinkValue = snapshot.childSnapshot(forPath: BCFirebaseDBConstants.videoLink).value as? String {
			videoLink = URL(string: videoLinkValue)
		} else {
			videoLink = nil
		}
		
		// properties for which there MUST be a value, so we do a little bit of error handling first, loading some default values in if we can't load this data for whatever reason.
		let rawEmoji = snapshot.childSnapshot(forPath: BCFirebaseDBConstants.emoji).value as? String
		let unixTimestamp = (snapshot.childSnapshot(forPath: BCFirebaseDBConstants.timestamp).value as AnyObject).description
		let rawUsername = snapshot.childSnapshot(forPath: BCFirebaseDBConstants.username).value as? String
		let typedUsername = BCFirebaseChatMessage.username(from: rawUsername)
		let usernameElements = BCFirebaseChatMessage.colourUsername(from: typedUsername)
		username = usernameElements.username
		colourLetter = usernameElements.colourLetter
		emoji = BCFirebaseChatMessage.appropriateEmoji(from: rawEmoji)
		timestamp = BCFirebaseChatMessage.timestamp(from: unixTimestamp)
		chatCategory = .user // doesn't matter, only used for posting
	}
	
	/// Initalise a `BCFirebaseChatMessage` from the given message contents, ready to post the Realtime Database.
	/// - parameter message: the text message contents of the message
	/// - parameter link: the link to an image file in Firebase Storage
	/// - important: only ONE of the `link` and the `message`, the other should be nil (because we can't have a combo text message and image post). We can, however, have both an imageLink and a videoLink, because videos need a thumbnail URL.
	public init?(message:String?, imageLink:URL?, videoLink:URL?, chatCategory:BCFirebaseChatCategory) {
		self.firebaseDatabaseKey = nil // we are about to post the this object, so we don't know this
		self.message = message
		self.imageLink = imageLink
		self.videoLink = videoLink
		self.chatCategory = chatCategory
		switch chatCategory {
		case .user:
			self.username = BCCurrentUser.username
			self.emoji = BCCurrentUser.emoji
			self.colourLetter = BCCurrentUser.colourLetter
		case .currentUser:
			guard let realName = FIRAuth.auth()?.currentUser?.providerData.first?.displayName else {
				// user has no name in their token, or auth not initalised
				return nil
			}
			self.username = realName
			self.emoji = "✔️"
			self.colourLetter = "f"
		}
		self.notificationToken = BCPushNotification.currentUserNotificationToken
		self.timestamp = Date() // doesn't matter, we don't end up posting this anyway, we use FIRServerValue (we just require this to be initalised)
		guard let auth = FIRAuth.auth()?.currentUser?.uid else { return nil }
		self.uid = auth
	}
	
	// MARK: - Instance Methods
	
	/// Initiate the posting of this chat message to the correct user's chat.
	/// - parameter facebookID: the facebookID of the chat we want this message to be posted to
	/// - parameter notificationMetadata: metadata used for sending push notification after the message posts
	/// - parameter postError: block executes if we cannot post for some reason.
	public func postMessage(facebookID:String, notificationMetadata meta:BCPushNotificationMetadata, postError: @escaping () -> Void) {
		guard let messageObject = self.toFirebaseObject() else {
			FIRCrashMessage("cannot form firebase object from message")
			postError(); return
		}
		// Set the reference of where we should post the message
		let userID = facebookID + "_" + facebookID.saltedMD5
		let messageChatRef = FIRDatabase.database().reference().child("\(BCFirebaseDBConstants.ephemeral)/\(userID)/\(BCFirebaseDBConstants.messages)")
		let newMsgRef = messageChatRef.childByAutoId()
		// Set the message in the database
		FIRAnalytics.logEvent(withName: "post_message", parameters: nil)
		newMsgRef.setValue(messageObject) { (error, ref) in
			// if there was an error, report this
			if let err = error {
				print(err)
				FIRCrashMessage("message post error: " + err.localizedDescription)
				postError(); return
			}
			
			// make sure the chat actually has a name, otherwise don't send any notification (no real issue)
			guard let name = meta.nameOfChat else { return }
			
			// send a push notification with the appropriate contents
			let push = BCPushNotification(ownerFacebookID:meta.ownerFacebookID,
			                              ownerName:name,
			                              otherUserTokens:meta.otherTokens,
			                              senderUsername:self.username,
			                              senderEmoji:self.emoji,
			                              senderMessage:self.message,
			                              chatCategory: meta.chatCategory)
			// if the message has a video link, it must be a video
			push.isMediaVideo = (self.videoLink != nil)
			push.sendNotification()
		}
		
		// let the user know they dont currently have a connection, if they don't have a Realtime Database connection.
		if (BCFirebaseDatabase.shared.hasConnectionToRealtimeDatabase == false) {
			// perform UI operation on the main thread.
			DispatchQueue.main.async {
				JDStatusBarNotification.show(withStatus: "Check your connection.", dismissAfter: 4, styleName: JDStatusBarStyleError)
			}
		}
	}
	
	/// Returns a Firebase compatible `AnyObject` from the current Chat Message.
	/// - returns: a Firebase compatable `AnyObject` or `nil` if we cannot get the Current User's real name from their auth credentials (if they are posting in their own chat).
	private func toFirebaseObject() -> AnyObject? {
		var object = [String:AnyObject]()
		object[BCFirebaseDBConstants.username] = (colourLetter + username) as AnyObject
		// apply the appropriate payload
		if let msg = message {
			object[BCFirebaseDBConstants.message] = msg as AnyObject
		} else {
			// may or may not be a video, we don't care
			if let vidLnk = videoLink {
				object[BCFirebaseDBConstants.videoLink] = vidLnk.absoluteString as AnyObject
			}
			// vital there is an image (either on it's own or as the video thumbnail)
			if let imgLnk = imageLink {
				object[BCFirebaseDBConstants.imageLink] = imgLnk.absoluteString as AnyObject
			} else {
				// there is no payload, so we don't have a complete object and can't post this.
				return nil
			}
		}
		object[BCFirebaseDBConstants.timestamp] = FIRServerValue.timestamp() as AnyObject
		object[BCFirebaseDBConstants.emoji] = emoji as AnyObject
		
		switch chatCategory {
		case .user:
			object[BCFirebaseDBConstants.userID] = uid as AnyObject
		case .currentUser:
			// if they are the current user, just set the value to 0
			object[BCFirebaseDBConstants.userID] = "current" as AnyObject
		}
		
		// if the user has a token, set this as the token.
		if let myToken = notificationToken {
			// only add the id token if the user has notifications for other chats enabled because this will mean that they get notifications for the chat they are posting in
			if BCAboutController.onlyMeNotifications == false && BCAboutController.notificationsDisabled == false {
				object[BCFirebaseDBConstants.messageNotificationToken] = myToken as AnyObject
			}
		}
		return object as AnyObject
	}
	
	// MARK: - Deleting
	
	/// Deletes this message from the Realtime Database (for user saftey)
	public func deleteMessage(facebookIDLocation:String, completion: @escaping (_ completed:Bool,_ reason:String) -> Void) {
		if self.uid == "current" { completion(false,"You can't delete your own messages."); return }
		guard let messageKey = self.firebaseDatabaseKey else { completion(false,"Message does not exist."); return }
		let messageRef = FIRDatabase.database().reference().child(BCFirebaseDBConstants.ephemeral).child(facebookIDLocation).child(BCFirebaseDBConstants.messages).child(messageKey)
		DispatchQueue.main.async {
			JDStatusBarNotification.show(withStatus: "Deleting...", dismissAfter: 1.5, styleName: JDStatusBarStyleError)
		}
		messageRef.removeValue { (error, ref) in
			if let err = error {
				FIRCrashMessage("could not delete message for user saftey: \(err.localizedDescription)")
				completion(false,"Try again.")
				return
			}
			completion(true,"Success.")
			DispatchQueue.main.async {
				JDStatusBarNotification.show(withStatus: "Deleted!", dismissAfter: 1.5, styleName: JDStatusBarStyleError)
			}
		}
	}
	
	
	// MARK: - Static Methods
	
	// MARK: Data Extraction (recieving)

	/// Function that gets the colour letter and username from the username as represented in Firebase.
	/// - parameter username: the username as it is stored in Firebase.
	private static func colourUsername(from username:String) -> (colourLetter:String, username:String) {
		// in the form {color_1char}{username}
		let index = username.index(username.startIndex, offsetBy: 1)
		return (username.substring(to: index), username.substring(from: index))
	}
	
	/// Function that gets the timestamp from the value as stored in Firebase.
	/// - parameter timestamp: the timestamp as stored in Firebase (epoch milliseconds as a string)
	/// - returns: a `Date` instance from the epoch
	private static func timestamp(from snapshotValue:String?) -> Date {
		guard let timestamp = snapshotValue else {
			print("timestamp can't be unwrapped")
			FIRCrashMessage("timestamp can't be unwrapped")
			return Date(timeIntervalSince1970: 0)
		}
		guard let doubleTimestamp = Double(timestamp) else {
			print("timestamp can't be converted to double")
			FIRCrashMessage("timestamp can't be converted to double")
			return Date(timeIntervalSince1970: 0)
		}
		return Date(timeIntervalSince1970: TimeInterval(doubleTimestamp/1000))
	}
	
	/// Function that gets the username from the username value as stored in Firebase
	/// - parameter username: the username as retrieved from firebase
	/// - returns: the username preceeded by the colour letter. This value to be processed to extract these values separately.
	private static func username(from snapshotValue:String?) -> String {
		guard let username = snapshotValue else {
			print("username can't be unwrapped in chat message")
			FIRCrashMessage("username can't be unwrapped in chat message")
			// can't get at username for whatever reason, just give the default 'username' username with a black colour
			return "xusername"
		}
		return username
	}
	
	/// Function that gets the best emoji on the user's device for the emoji value stored in Firebase.
	/// - parameter emoji: the emoji value as retrieved from Firebase
	/// - returns: the emoji that we should display
	private static func appropriateEmoji(from snapshotValue:String?) -> String {
		guard let emoji = snapshotValue else {
			print("emoji can't be unwrapped in chat message")
			FIRCrashMessage("emoji can't be unwrapped in chat message")
			return "🐵"
		}
		
		if emoji == "" || emoji.characters.count < 1 { return "🐵" }
		
		if emoji.isSingleEmoji {
			// if it is an emoji, just return the emoji
			return emoji
		} else {
			// if this is not an emoji, only consider the first character
			let index = emoji.index(emoji.startIndex, offsetBy: 1)
			let cutEmoji = emoji.substring(to: index)
			// make sure the first character is actually an emoji
			if cutEmoji.isSingleEmoji { return cutEmoji }
		}
		return "🐵" // return monkey if all else fails
	}
	
	public static func == (lhs: BCFirebaseChatMessage, rhs: BCFirebaseChatMessage) -> Bool {
		guard let leftKey = lhs.firebaseDatabaseKey else { return false }
		guard let rightKey = rhs.firebaseDatabaseKey else { return false }
		return leftKey == rightKey
	}
	
	
}
