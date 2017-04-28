//
//  Person.swift
//  Backchat
//
//  Created by Bradley Mackey on 30/11/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation
import RealmSwift

/// # BCUser
/// A Realm class that represents a Facebook User (not the current user) within the application.
public final class BCUser:Object {
	
	// MARK: - Properties
	/// The Facebook ID of this user.
	dynamic public var facebookID:String = ""
	/// The name of this user, according to Facebook.
	dynamic public var name:String = ""
	/// The `Date` of the last time that this user was searched.
	dynamic public var searchDate:Date = Date()
	/// Whether or not this user is stored in the 'Recents' section.
	dynamic public var isRecent:Bool = false
	/// For monitoring Users on fetching new users from realm (so we know if a user has been deactivated Grapevine for example)
	dynamic public var sessionTag:String = ""
	/// the number of notifications recieved about this user whilst in the background.
	dynamic public var notifications:Int = 0
	
	
	// MARK: - Methods
	override public var description: String {
		return "\(name), Facebook ID: \(facebookID),  In Recents: \(isRecent), SessionTag: \(sessionTag)"
	}
	
	override public static func primaryKey() -> String? {
		return "facebookID"
	}
	
	public static func getProfilePictureURL(facebookID: String) -> URL {
		return URL(string: "https://graph.facebook.com/\(facebookID)/picture?type=large&width=200&height=200")!
	}
}

