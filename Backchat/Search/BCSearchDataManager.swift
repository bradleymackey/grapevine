//
//  BCSearchDataManager.swift
//  Backchat
//
//  Created by Bradley Mackey on 05/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import RealmSwift
import Firebase

/// # BCSearchDataManagerDelegate
/// The delegate used to notify when we have changes to our model.
public protocol BCSearchDataManagerDelegate:class {
	/// The whole tableView should reload.
	func tableViewShouldReload()
	/// Some individual rows should be updates
	func updateRows(for section:BCSearchTableSection, rows: [Int])
}

/// # BCSearchDataManager
/// This class manages the entire data source for the SearchController, managing all data for `BCUser` objects that should be displayed and the `BCCurrentUser` object - for the current user.
/// - important: This is a singleton because the `BCSearchController` persists the entire time we are running the app. It should never be evicted from memory because it is at the base of the `UINavigationController` stack.
public final class BCSearchDataManager {
	
	// MARK: - Singleton
	public static let shared = BCSearchDataManager()
	
	// MARK: - Lifecycle
	private init() {
		setRealm()
		observeTables()
	}
	
	deinit {
		// stop the notification tokens to prevent memory leaks
		allUsersToken?.stop()
//		recentUsersToken?.stop()
	}
	
	// MARK: - Properties
	
	// MARK: Public
	/// The delegate: `BCSearchControllerDataDelegate`
	public weak var delegate:BCSearchDataManagerDelegate?
	
	/// The current user.
	/// - returns: the current user or nil if we can't access the current user
	public var currentUser:BCCurrentUser? {
		guard let authuser = FIRAuth.auth()?.currentUser?.providerData.first else { return nil }
		guard let displayName = authuser.displayName else { return nil }
		let user = BCCurrentUser(name: displayName, facebookID: authuser.uid)
		return user
	}
	
	/// Users that should be present in the 'Recents' section of the tableView.
	/// - returns: the list of users, sorted by time.
	public var recentUsers:Results<BCUser> {
		let recents = realm.objects(BCUser.self)
						   .filter("isRecent = YES")
						   .sorted(byKeyPath: "searchDate", ascending: false)
		return recents
	}
	
	/// All the users that should be displayed within the 'All' section of the tableView.
	/// - returns: the sorted list of all the users.
	public var allUsers:Results<BCUser> {
		let all = realm.objects(BCUser.self)
			           .sorted(byKeyPath: "name", ascending: true)
		return all
	}
	
	/// Where the results of a local search are stored.
	/// If no current search is being performed, the value will be `nil`.
	/// - important: the value of this is set during a search via the `makeUserRecent(:)` method.
	public var filteredPeople:Results<BCUser>?

	
	// MARK: Private
	/// Our Realm instance used to interface with the database
	private var realm:Realm!
	
	/// NotificationToken that observes the list of all users (not the list of recent users), so we can notifiy the delegate of changes
	private var allUsersToken:NotificationToken!
	
	/// NotificationsToken used for monitoring recent users, so that we can notify of ONLY CHANGES to individual rows in the recents list
//	private var recentUsersToken:NotificationToken!

	
	// MARK: - Methods
	
	// MARK: Initalisation
	/// Sets the value of our realm property to use within the class.
	private func setRealm() {
		// Initialise our realm property to connect to Realm database
		self.realm = try! Realm()
	}
	
	private func observeTables() {
		// Observe Results Notifications
		allUsersToken = allUsers.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
			guard let strongSelf = self else { return }
			switch changes {
			case .initial:
				// Results are now popularted and can be accessed without blocking the UI
				strongSelf.delegate?.tableViewShouldReload()
				break
			case .update(_, let deletions, let insertions, let modifications):
				print("reload table for updated model")
				if deletions.isEmpty && insertions.isEmpty {
					strongSelf.delegate?.updateRows(for: .all, rows: modifications)
				} else {
					// reload the data source as some rows have been inserted or deleted (too much effort to manager the row updatse)
					strongSelf.delegate?.tableViewShouldReload()
				}
			case .error(let error):
				// An error occurred while opening the Realm file on the background worker thread
				fatalError("\(error)")
			}
		}
//		recentUsersToken = recentUsers.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
//			guard let strongSelf = self else { return }
//			switch changes {
//			case .initial:
//				break
//			case .update(_, let deletions, let insertions, let modifications):
//				if deletions.isEmpty && insertions.isEmpty {
//					strongSelf.delegate?.updateRows(for: .recents, rows: modifications)
//				}
//			case .error(let error):
//				// An error occurred while opening the Realm file on the background worker thread
//				fatalError("\(error)")
//			}
//		}
	}
	
	// MARK: Searching
	/// Performs a local search on all users stored in the realm.
	/// - parameter searchText: the string for which the search should be conducted.
	/// - returns: a realm `Results` object with the users matching the search.
	/// - note: conform to `BCSearchDataDelegate` to get tableView reload notifications
	/// - important: this sets the value of `filteredPeople`, which should be monitored for the results.
	public func searchFor(searchText: String) {
		defer { delegate?.tableViewShouldReload() }
		if searchText == "" { filteredPeople = nil; return }
		// perform a non-case-sensitive query for the names
		let people = realm.objects(BCUser.self).filter("name CONTAINS[c] '\(searchText)'")
		filteredPeople = people
	}
	
	// MARK: Data Manipulation
	/// Function that removes all recent users from the Realm.
	public func clearRecentlyViewed() {
		FIRAnalytics.logEvent(withName: "clear_recent", parameters: nil)
		self.realm.beginWrite()
		for person in recentUsers {
			person.isRecent = false
			self.realm.add(person, update: true)
		}
		BCCurrentUser.isRecent = false
		// don't notify tokens because we will reload the table view when we get back to the SearchController on viewWillAppear. this avoids an inconsitency crash.
		try! self.realm.commitWrite(withoutNotifying: [allUsersToken])
	}
	
	/// A user has just been viewed, so add them to the list of recently viewed people with the most current date.
	/// - parameter facebookID: the facebookID of the user that has just been viewed
	public func makeUserRecentAndRemoveNotifications(facebookID:String) {
		// make sure we have this user in memory
		guard let currentPerson = realm.object(ofType: BCUser.self, forPrimaryKey: facebookID) else { return }
		realm.beginWrite()
		currentPerson.searchDate = Date()
		currentPerson.isRecent = true
		currentPerson.notifications = 0
		realm.add(currentPerson, update: true)
		// don't notify tokens because we will reload the table view when we get back to the SearchController on viewWillAppear. it means the glitching doesn't happen.
		try! realm.commitWrite(withoutNotifying: [allUsersToken])
	}
	
	public func clearAllUserAndDemoData() {
		let allUsers = realm.objects(BCUser.self)
		let allDemoMessages = realm.objects(BCDemoChatMessage.self)
		realm.beginWrite()
		realm.delete(allUsers)
		realm.delete(allDemoMessages)
		// don't notify tokens because we will reload the table view when we get back to the SearchController on viewWillAppear. it means the glitching doesn't happen and we don't need to manually delete the cells from searchController.
		try! realm.commitWrite(withoutNotifying: [allUsersToken])
	}

}
