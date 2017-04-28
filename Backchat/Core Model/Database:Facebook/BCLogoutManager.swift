//
//  BCLogoutManager.swift
//  Backchat
//
//  Created by Bradley Mackey on 11/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import FacebookLogin
import Firebase
import RealmSwift
import SDWebImage

protocol BCLogoutManagerDelegate: class {
	func logoutSucceeded()
	func logoutFailed()
}

/// Handles fully logging out.
final class BCLogoutManager {
	
	// MARK: - Properties
	
	/// The delegate to report logout events.
	public weak var delegate:BCLogoutManagerDelegate!
	
	/// The facebook ID of the user being logged out (for removing notification token from the Realtime Database)
	public let facebookID:String?
	
	// MARK: - Lifecycle
	
	/// Create a new logout instance.
	/// - parameter facebookID: the facebook ID of the user being logged out
	public init(facebookID:String?) {
		self.facebookID = facebookID
	}
	
	// MARK: - Methods
	
	/// Log the user out and delete any friend and session data from usage.
	public func logOut() {
		guard let auth = FIRAuth.auth() else {
			delegate.logoutFailed(); return
		}
		do {
			try auth.signOut()
			let fbLoginManager = LoginManager()
			fbLoginManager.logOut()
			self.resetUserProfile()
			delegate.logoutSucceeded()
		} catch {
			delegate.logoutFailed()
		}
	}
	
	/// Spins off a load of functions to delete all the user's session and friend data.
	private func resetUserProfile() {
		DispatchQueue.global(qos: .background).async {
			self.resetProfile()
			self.resetCurrentUserSpecificsAndDemo()
			self.resetPushNotifications()
			self.resetFacebook()
			self.resetFirebase()
			self.clearSDWebImageCache()
		}
		// clear all of the data from the search data model, as well as all the Demo Messages in Kevin.
		// must be on the main thread 'because Realm'
		BCSearchDataManager.shared.clearAllUserAndDemoData()
	}
	
	// MARK: - Specific Details to reset
	
	private func resetProfile() {
		// set username properties manually so that they don't trigger the timer and means that you can't change your username for the time limit
		// Although, we don't reset the timer, otherwise people could just logout and back in to change their username.
		UserDefaults.standard.set("username", forKey: "username")
		UserDefaults.standard.set("🐵", forKey: "emoji")
		UserDefaults.standard.set("x", forKey: "colour")
	}
	
	private func resetCurrentUserSpecificsAndDemo() {
		// set tutorial as not complete so we can see it again on next login
		BCCurrentUser.tutorialComplete = false
		// Reset Kevin, ready for the next user
		BCCurrentUser.kevinHidden = false
		BCDemoChatManager.replyCounter = 0
		BCCurrentUser.isRecent = false
		// reset the fact that they want to keep kevin or not
		BCCurrentUser.wantToKeepKevin = false
		BCCurrentUser.currentNotifications = 0
		// reset kevin views
		BCDemoChatManager.views = 0
	}
	
	private func resetPushNotifications() {
		// remove the notification token for the user in firebase, so this device is no longer associated with that facebook account.
		if let id = facebookID {
			BCPushNotification.removeNotificationToken(for: id)
		}
		
		// set notifications disabled when you log out, so you don't keep getting notifications for the old profile
		BCPushNotification.setNotifications(enabled: false)
		BCAboutController.notificationsDisabled = true
	}
	
	private func resetFacebook() {
		// reset session data for next login
		BCFacebookRequest.shared.resetSessionData()
	}
	
	private func resetFirebase() {
		// remove any writes queued up for the current user, so they won't go ahead if another user logs in.
		BCFirebaseDatabase.removeOutstandingWrites()
	}
	
	private func clearSDWebImageCache() {
		let imageCache = SDImageCache.shared()
		imageCache.clearDisk()
		imageCache.clearMemory()
	}
	
}
