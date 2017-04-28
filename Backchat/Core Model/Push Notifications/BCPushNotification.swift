//
//  PushNotifications.swift
//  Backchat
//
//  Created by Bradley Mackey on 06/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase
import OneSignal

/// # BCPushNotification
/// A utility class that is used to send push notifications alongside messages, to let user's know when there are new comments.
final class BCPushNotification {
	
	// MARK: - Static Properties
	
	/// The current user's push notificiation token so we can attach this to their messages
	public static var currentUserNotificationToken:String?
	
	/// Whether or not we have set the token in Firebase for the current session because we don't want to use too much bandwidth by setting it too much
	public static var setNotificationTokenForSession = false
	
	/// Whether or not we have asked the user about notifications yet so we don't display the notifications view controller too much and annoy them.
	/// - note: this is a property that is saved to the `UserDefaults` so the data can persist across sessions
	public static var askedNotifications:Bool {
		get { return UserDefaults.standard.bool(forKey: "askedNotifications") }
		set { UserDefaults.standard.set(newValue, forKey: "askedNotifications") }
	}
	
	/// We store a cache of the tokens that we gather so we don't have to redownload them for every message that gets sent. This is cleared every time the app restarts, in case the user has changed their token recently.
	/// - note: in the form [facebookID:token]
	private static var cachedTokens = [String:String?]() {
		didSet {
			// if the dict gets too big, clear it out (it shouldn't, but just in case)
			if cachedTokens.count > 5000 { cachedTokens = [:] }
		}
	}
	
	// MARK: - Static Methods
	
	public static func setNotificationTokenInFirebaseForCurrentUserIfPossible(facebookID:String) {
		// if we have already set the notification token, don't set it again in Firebase for the session - we don't want to use too much data
		if BCPushNotification.setNotificationTokenForSession { return }
		OneSignal.idsAvailable { (userId, pushToken) in
			if let id = userId {
				print("OneSignal userID: \(id)")
				self.currentUserNotificationToken = id
				// the user can only set 1 push notification token, which will be the most recently logged in device
				let userID = facebookID + "_" + facebookID.saltedMD5
				let ref = FIRDatabase.database().reference().child("info/\(userID)/token")
				ref.setValue(id) { (error, ref) in
					// if we managed to set the value in Firebase, make sure we know it was successful
					BCPushNotification.setNotificationTokenForSession = (error == nil)
				}
			} else { print("no id, user did not accept notifications") }
		}
	}
	
	public static func removeNotificationToken(for facebookID:String) {
		let userID = facebookID + "_" + facebookID.saltedMD5
		let tokenRef = FIRDatabase.database().reference().child("info/\(userID)/token")
		tokenRef.removeValue()
	}
	
	public static func setNotifications(enabled:Bool) {
		OneSignal.setSubscription(enabled)
		if enabled {
			print("enabling push notifications")
		} else {
			print("disabling push notifications")
		}
	}
	
	public static func promptForNotifications() {
		OneSignal.registerForPushNotifications()
	}
	
	// MARK: - Instance properties
	
	/// The facebook ID of the chat that the notificaition is being sent in (the 'owners' chat). 
	/// - note: We need this so that we can get the owner's notification token from their area in the Firebase database.
	public let ownerFacebookID:String
	
	/// The real name of the person who's chat the notification is being sent in.
	/// - note: We need this so we can put it in the title of the notification.
	public let ownerName:String
	
	/// The notification tokens of the other people in the chat who should also recieve a notification.
	public var otherUserTokens:Set<String>
	
	/// The username of the person sending the notification.
	public let senderUsername:String
	
	/// The emoji of the person sending the notification.
	public let senderEmoji:String
	
	/// The text contents of the message.
	/// - important: If this is `nil` then we assume this is a media post.
	public let senderMessage:String?
	
	/// Whether or not this is the current owner of the chat sending the push notification, so we know
	public let chatCategory:BCFirebaseChatCategory
	
	/// If this is a media post, is it a video post? If so, this should be true (if it's just a normal message post then this doesn't matter)
	public var isMediaVideo:Bool = false
	
	// MARK: - Lifecycle
	
	/// Initalise a new push notification object.
	public init(ownerFacebookID:String,
	            ownerName:String,
	            otherUserTokens:Set<String>,
	            senderUsername:String,
	            senderEmoji:String,
	            senderMessage:String?,
	            chatCategory:BCFirebaseChatCategory) {
		self.ownerFacebookID = ownerFacebookID
		self.ownerName = ownerName
		self.otherUserTokens = otherUserTokens
		self.senderUsername = senderUsername
		self.senderEmoji = senderEmoji
		self.senderMessage = senderMessage
		self.chatCategory = chatCategory
	}
	
	// MARK: - Instance Methods
	
	public func sendNotification() {
		// if the current user has a token, remove the possibility of this being included in the recipients of this notification.
		if let currentUserToken = BCPushNotification.currentUserNotificationToken {
			otherUserTokens.remove(currentUserToken)
		}
		
		// if we have the token cached then use that
		if let cachedToken = BCPushNotification.cachedTokens[ownerFacebookID] {
			// this will only send the payload to the owner if the owner had a token the last time we checked, we won't keep trying to get it.
			sendPayload(ownerToken: cachedToken)
		} else {
			if chatCategory == .currentUser {
				// this is the current user, so just send (we don't want to send a notification to ourself). `sendPayload(_:)` will handle using the real name as the name and using the correct emoji
				sendPayload(ownerToken: nil)
			} else {
				// not the current user, so fetch the notification token and then send the notification after.
				fetchNotificationTokenThenPush()
			}
		}
	}
	
	
	private func fetchNotificationTokenThenPush() {
		print("Getting push token from Firebase for \(ownerFacebookID)")
		let userID = ownerFacebookID + "_" + ownerFacebookID.saltedMD5
		let tokenRef = FIRDatabase.database().reference().child("info/\(userID)/token")
		// get the token for this user
		tokenRef.observeSingleEvent(of: .value, with: { (snapshot) in
			guard let token = snapshot.value as? String else {
				print("User has no push token. Sending notification only to other chatters.")
				BCPushNotification.cachedTokens[self.ownerFacebookID] = nil
				self.sendPayload(ownerToken: nil)
				return
			}
			print("Got token from Firebase: \(token)")
			BCPushNotification.cachedTokens[self.ownerFacebookID] = token
			// try to send the notification again
			self.sendPayload(ownerToken: token)
		})
	}
	
	
	private func sendPayload(ownerToken:String?) {
		// if the owner has a token, then add it to the set, otherwise don't because there is no token to add.
		if let token = ownerToken {
			otherUserTokens.insert(token)
		}
		
		var data:[AnyHashable:Any] = ["include_player_ids": Array(otherUserTokens),
									  "ios_sound": "pop.caf",
									  "content_available":true,
									  "ios_badgeType": "Increase",
									  "ios_badgeCount": 1,
									  "headings": ["en": ownerName]]

		if let message = senderMessage {
			// there is a message, so this must be a normal text post
			data["contents"] = ["en": "\(senderEmoji) \(senderUsername): \(message)"]
		} else {
			// there is no message, so this must be a media post
			let content = isMediaVideo ? "📹 Video" : "📷 Image"
			data["contents"] = ["en": "\(content) by \(senderEmoji) \(senderUsername)"]
		}
		// set the data so we can open the correct chat on tap
		data["data"] = ["name":ownerName, "id":ownerFacebookID]
		
		// send the push notification via the OneSignal API
		OneSignal.postNotification(data, onSuccess: { (data) in
			guard let sentData = data else { return }
			FIRAnalytics.logEvent(withName: "sent_push", parameters: nil)
			print("Sent Push Notification: \(sentData)")
		}, onFailure: { (error) in
			guard let sendError = error else { return }
			FIRCrashMessage("Could not send Push Notification: \(sendError)")
			print("push notification send error: \(error)")
		})
	}

}
