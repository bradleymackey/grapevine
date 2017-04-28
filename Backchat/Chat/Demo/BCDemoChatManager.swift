//
//  BCDemoChatManager.swift
//  Backchat
//
//  Created by Bradley Mackey on 08/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase // for crash reporting
import RealmSwift

/// Conform to this delegate to recieve notifications for a tableView about changes to the realm for the demo.
public protocol BCDemoChatManagerDelegate: class {
	/// The whole table view should be reloaded.
	func tableViewShouldReload()
	/// insert rows at the specified indicies.
	func rowsToUpdate(insertions:[Int], deletions:[Int], modifications:[Int])
	/// Kevin has exhasted all replies, display a popup asking if you want to delete him.
	func kevinFinished()
}

/// # BCDemoChatInterface
/// Manages all chat and view count operations to the demo 'Kevin' profile, with all data being written and read to/from Realm.
final public class BCDemoChatManager {
	
	// MARK: - Properties
	/// Delegate to notify view controller of model changes.
	public weak var delegate:BCDemoChatManagerDelegate?
	
	/// The dataSource of the messages to Kevin.
	public var dataSource:Results<BCDemoChatMessage> {
		return realm.objects(BCDemoChatMessage.self)
					.sorted(byKeyPath: "timestamp", ascending: false)
	}
	
	private static var realNameMessage:String {
		return FIRAuth.auth()?.currentUser?.providerData.first?.displayName ?? "(your real name)"
	}
	
	/// The replies that Kevin should say whenever the user types a comment.
	public static let replies:[String] = ["Hey \(BCCurrentUser.username) 👋 My name is Kevin and I'm here so show you round. Try typing a message! 🔤",
		"image/t%6RReIIk43djuuJk/demo_kevin", // picture of kevin, instant after
		"You can change your profile username and emoji under the 'Me' section.",
		"image/t%6RReIIk43djuuJk/demo_profile_section", // picture of the change profile section, highlighted, instant after
		"This will be shown on your friends' profiles when you post a message.",
		"Let's go over how Grapevine works! 📝",
		"Every 24 hours, every message sent inside Grapevine is deleted. It doen't matter how old each individual message is.",
		"You can see when this will happen each day by looking at the countdown timer underneath the Grapevine title.",
		"image/t%6RReIIk43djuuJk/demo_backchat_timer", // picture of the countdown timer, instant after
		"You can also only see the 25 most recent messages sent in each chat.",
		"If you send a message to your own profile your username will be changed to '✔️ \(BCDemoChatManager.realNameMessage)' so that you can't lie about yourself!",
		"By the way, you can only see your Facebook friends that have already downloaded Grapevine, so invite your friends! ✉️",
		"Hold down on a message to copy or share it, and send links inside chats as well! 😀",
		"Everyone has a view counter below their name inside a chat. This is the total number of views they have on their profile from all their friends (not just you!) since the last time Grapevine reset (every 24 hours).",
		"Get notified when someone says something about you. Push notifications can be disabled in Settings 🛠 if you don't want them. 🤐",
		"image/t%6RReIIk43djuuJk/demo_push_notifications", // picture of push notification settings, instant after
		"You can also get push notifications on your friends' profiles if you've recently commented on them. This can also be disabled in Settings 🛠 if you don't want this.",
		"If you have Background App Refresh turned on you'll be able to see a little notification number by each name so you know how many notifications you've had from each person!",
		"What's your favourite movie btw? 🎥",
		"I don't like that one",
		"Yikes, almost time for me to go. But before I do, remember to be nice. Everyone has feelings! You can disable your account at any time by going to http://facebook.com/settings",
		"And if you like the app, I'm sure the developer would appreciate a nice rating in the App Store! 😉",
		"Anyway, see ya \(BCCurrentUser.username), have fun with your friends! 😇"]
	
	/// Variable who's value is saved within the UserDefaults so that we can recover the value each time that we launch the DemoChatController - so that we know which reply Kevin is currently on and he doesn't repeat himself.
	public static var replyCounter:Int {
		get { return UserDefaults.standard.integer(forKey: "replyCounter") }
		set { UserDefaults.standard.set(newValue, forKey: "replyCounter") }
	}
	
	/// Our Realm instance.
	private let realm:Realm
	
	/// The notification token used by Realm so that we can update the tableView each time the user or KevinFan#1 says a comment.
	/// - note: needed because we save the messages directly to Realm and don't display them, so we use the token to notify the tableView of any changes.
	private var newMessageNotificationToken:NotificationToken?
	
	/// The number of views that the user has on Kevin (saved in the UserDefaults)
	public static var views:Int {
		get { return UserDefaults.standard.integer(forKey: "kevin_views") }
		set { UserDefaults.standard.set(newValue, forKey: "kevin_views") }
	}
	
	// MARK: - Lifecycle
	
	public init() {
		realm = try! Realm()
		
		let results = realm.objects(BCDemoChatMessage.self).sorted(byKeyPath: "timestamp", ascending: false)
		
		// observe for changes in the realm, and notify the delegate as to when updates are needed for tableView's and such.
		newMessageNotificationToken = results.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
			guard let strongSelf = self else { return }
			switch changes {
			case .initial:
				// Results are now populated and can be accessed without blocking the UI
				strongSelf.delegate?.tableViewShouldReload()
				strongSelf.postDemoReplyIfNeeded()
			case .update(_, let deletions, let insertions, let modifications):
				// Query results have changed, so apply them to the UITableView
				strongSelf.delegate?.rowsToUpdate(insertions: insertions, deletions: deletions, modifications: modifications)
				strongSelf.postDemoReplyIfNeeded()
			case .error(let error):
				// An error occurred while opening the Realm file on the background worker thread
				FIRCrashMessage("Error occured trying to access realm (#103)")
				fatalError("\(error)")
			}
		}
	}
	
	deinit {
		// remove the notification token to prevent it leaking
		newMessageNotificationToken?.stop()
	}
	
	// MARK: - Methods
	
	/// Posts a message as Kevin to Realm - only if it's Kevin's turn to talk and he actually has something left to say (his list of replies is not yet exhasted)
	private func postDemoReplyIfNeeded() {
		let messages = realm.objects(BCDemoChatMessage.self)
		if (messages.count % 2) != 0 { return } // only post a message if the current count is even
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
			if BCDemoChatManager.replyCounter >= BCDemoChatManager.replies.count { // only post a message if we have messages left
				if BCCurrentUser.wantToKeepKevin == false {
					// only display the 'kevin's' done alert if the user hasn't already said they want to keep kevin.
					self.delegate?.kevinFinished()
				}
				return
			}
			let message = BCDemoChatMessage()
			message.username = "Kevin" // he's simply called Kevin
			if BCDemoChatManager.replies[BCDemoChatManager.replyCounter].contains("image/t%6RReIIk43djuuJk/") {
				let full = BCDemoChatManager.replies[BCDemoChatManager.replyCounter]
				let index = full.index(full.startIndex, offsetBy: 24)
				message.imageName = full.substring(from: index)
			} else {
				message.message = BCDemoChatManager.replies[BCDemoChatManager.replyCounter]
			}
			message.emoji = "✔️" // "✔️" is the special emoji for the current user
			message.colourLetter = "f" // 'f' is the special letter for the current user.
			try! self.realm.write {
				self.realm.add(message)
			}
			BCDemoChatManager.replyCounter += 1
		}
	}
	
	/// Method that sends a message to the demo chat using the user's current profile.
	/// - parameter textMessage: the message that should be used in the message
	public func sendMessageToChat(_ textMessage:String) {
		if textMessage.characters.count > 200 { return }
		let message = BCDemoChatMessage()
		message.username = BCCurrentUser.username
		message.message = textMessage
		message.emoji = BCCurrentUser.emoji
		message.colourLetter = BCCurrentUser.colourLetter
		try! realm.write {
			realm.add(message)
		}
	}
	
	
}
