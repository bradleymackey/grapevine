//
//  Reachability.swift
//  Backchat
//
//  Created by Bradley Mackey on 21/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase

/// # BCFirebaseDatabase
/// A singleton instance that monitors some connection to the Database and performs some generic database operations.
/// - note: access the singleton via the `shared` property
final class BCFirebaseDatabase {
    // MARK: - Lifecycle
	/// The singleton instance.
	static let shared = BCFirebaseDatabase()
	private init() {
		observeRealtimeDatabaseConnection()
	}
	
	deinit {
		FIRDatabase.database().reference(withPath: ".info/connected").removeAllObservers()
	}
	
	// MARK: - Properties

	/// Whether or not a user is connected to the Firebase Realtime Database.
	public var hasConnectionToRealtimeDatabase:Bool = true
	
	// MARK: - Singleton Methods
	
	/// Begin to observe the connection status to the Realtime Database.
	public func observeRealtimeDatabaseConnection() {
		let connectedRef = FIRDatabase.database().reference(withPath: ".info/connected")
		connectedRef.observe(.value, with: { snapshot in
			if let connected = snapshot.value as? Bool, connected {
				print("Connected to Realtime Database")
				FIRAnalytics.logEvent(withName: "connected_database", parameters: nil)
				self.hasConnectionToRealtimeDatabase = true
			} else {
				print("Disconnected from Realtime Database")
				self.hasConnectionToRealtimeDatabase = false
			}
		})
	}

//	public func addCurrentlyCachedFriendsToFirebase() {
//		self.uploadStatusForCurrentGraphResponse = .uploading
//		var friendDict = cachedFriendsAsFirebaseObject as [String:AnyObject]
//		// add the database secret to the list to 'authenticate' the write transaction of friends
//		friendDict["123856431437383"] = true as AnyObject
//		// add the server timestamp so we can authenticate the list is being sent within valid time
//		friendDict["ts"] = FIRServerValue.timestamp() as AnyObject
//		print("posting friends to firebase: \(friendDict)")
//		guard let facebookID = FIRAuth.auth()?.currentUser?.providerData.first?.uid else { return }
//		let friendRef = FIRDatabase.database().reference().child("people/\(facebookID)/f")
//		friendRef.setValue(friendDict) { (error, ref) in
//			if let err = error {
//				self.uploadStatusForCurrentGraphResponse = .notUploaded
//				print("could not upload friends")
//				FIRCrashMessage("could not upload friends " + err.localizedDescription)
//			} else {
//				self.uploadStatusForCurrentGraphResponse = .uploaded
//				print("uploaded friends")
//			}
//		}
//	}
	
	// MARK: - Static Methods
	
	public static func removeOutstandingWrites() {
		FIRDatabase.database().purgeOutstandingWrites()
	}
}
