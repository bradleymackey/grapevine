//
//  BCCurrentUser.swift
//  Backchat
//
//  Created by Bradley Mackey on 07/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation
import UIKit
import Firebase // analytics
import Locksmith

/// # BCCurrentUser
/// This class represents the Facebook user that is currently using the app.
/// Most of the properties in here are static, because there is only 1 current user, we don't care about instances so much.
/// - important: The actual data about the user is contained within the Firebase Auth Object, we can just constuct this if needed to easily carry about the data.
public final class BCCurrentUser {
	
	public var name:String
	public var facebookID:String
	
	public init(name:String, facebookID:String) {
		self.name = name
		self.facebookID = facebookID
	}
	
	// MARK: - Static Properties
	
	public static var currentNotifications:Int {
		get { return UserDefaults.standard.integer(forKey: "currentNotifications")}
		set {UserDefaults.standard.set(newValue, forKey: "currentNotifications")}
	}
	
	public static var searchDate:Date {
		get {
			let double = UserDefaults.standard.double(forKey: "currentUserDateUserSearched")
			if double <= 0 {
				BCCurrentUser.searchDate = Date()
				return Date()
			}
			return Date(timeIntervalSince1970: TimeInterval(double))
		}
		set {
			let double = Double(newValue.timeIntervalSince1970)
			UserDefaults.standard.set(double, forKey: "currentUserDateUserSearched")
		}
	}
	
	public static var isRecent:Bool {
		get { return UserDefaults.standard.bool(forKey: "currentUserIsRecent") }
		set { UserDefaults.standard.set(newValue, forKey: "currentUserIsRecent") }
	}
    
    public static var tutorialComplete:Bool {
        get { return UserDefaults.standard.bool(forKey: "tutorialComplete") }
        set { UserDefaults.standard.set(newValue, forKey: "tutorialComplete") }
    }
	
	public static var username:String {
		get {
			return UserDefaults.standard.string(forKey: "username") ?? "username"
		}
		set {
			DispatchQueue.global(qos: .userInitiated).async {
				UserDefaults.standard.set(newValue, forKey: "username")
				let threeDaysTime = Date(timeIntervalSinceNow: TimeInterval(3600*24*3))
				do {
					try Locksmith.saveData(data: ["whenCanSetProfile": threeDaysTime], forUserAccount: "user")
				} catch {
					print(error)
					do {
						try Locksmith.updateData(data: ["whenCanSetProfile": threeDaysTime], forUserAccount: "user")
					} catch {
						FIRCrashMessage("could not set date for username \(error)")
					}
				}
				FIRAnalytics.logEvent(withName: "set_username", parameters: ["username":newValue as NSObject])
			}
		}
	}
	
	public static var emoji:String {
		get {
			return UserDefaults.standard.string(forKey: "emoji") ?? "🐵"
		}
		set {
			// if the user tries to set something that's not a single emoji, just bail and don't set anything
			if newValue == "" { return }
			if !newValue.isSingleEmoji { return }
			DispatchQueue.global(qos: .userInitiated).async {
				UserDefaults.standard.set(newValue, forKey: "emoji")
				let threeDaysTime = Date(timeIntervalSinceNow: TimeInterval(3600*24*3))
				do {
					try Locksmith.saveData(data: ["whenCanSetProfile": threeDaysTime], forUserAccount: "user")
				} catch {
					print(error)
					do {
						try Locksmith.updateData(data: ["whenCanSetProfile": threeDaysTime], forUserAccount: "user")
					} catch {
						FIRCrashMessage("could not set date for emoji \(error)")
					}
				}
				FIRAnalytics.logEvent(withName: "set_emoji", parameters: ["emoji":newValue as NSObject])
			}
		}
	}
	
	public static var colourLetter:String {
		get {
			return UserDefaults.standard.string(forKey: "colour") ?? BCColourLetter.black.rawValue
		}
		set {
			DispatchQueue.global(qos: .userInitiated).async {
				UserDefaults.standard.set(newValue, forKey: "colour")
				let threeDaysTime = Date(timeIntervalSinceNow: TimeInterval(3600*24*3))
				do {
					try Locksmith.saveData(data: ["whenCanSetProfile": threeDaysTime], forUserAccount: "user")
				} catch {
					do {
						try Locksmith.updateData(data: ["whenCanSetProfile": threeDaysTime], forUserAccount: "user")
					} catch {
						FIRCrashMessage("could not set date for colour \(error)")
					}
				}
				FIRAnalytics.logEvent(withName: "set_colour", parameters: ["colour":newValue as NSObject])
			}
		}
	}
	
	/// Returns whether or not enough time has passed for the user to change their profile.
	public static var canSetProfile:Bool {
		if BCUsernameController.easterEggCounter > 10 { return true } // TODO: remove easter egg
		let dictionary = Locksmith.loadDataForUserAccount(userAccount: "user")
		guard let date = dictionary?["whenCanSetProfile"] as? Date else { return true }
		let seconds = date.timeIntervalSinceNow
		if seconds <= 0 { return true } else { return false }
	}
	
	/// The amount of time required until the user can change their profile again.
	public static func periodUntilProfileCanChange() -> (time:Int,denomination:String) {
		let dictionary = Locksmith.loadDataForUserAccount(userAccount: "user")
		guard let date = dictionary?["whenCanSetProfile"] as? Date else { return (0,"seconds") }
		let seconds = date.timeIntervalSinceNow
		let minutes = seconds/60
		let hours = seconds/3600
		let days = hours/24
		if days >= 1 { return (Int(days+1), "days") }
		if hours >= 1 { return (Int(hours), "hours") }
		if minutes >= 1 { return (Int(minutes), "minutes") }
		return (1, "minute") // if less than a minute, just say 1 minute
	}
	
	/// Whether or not kevin is currently hidden from our device.
	public static var kevinHidden:Bool {
		get { return UserDefaults.standard.bool(forKey: "kevinVisible") }
		set { UserDefaults.standard.set(newValue, forKey: "kevinVisible") }
	}
	
	/// Whether the user said 'Keep Kevin' or not at the end of the demo tutorial.
	public static var wantToKeepKevin:Bool {
		get { return UserDefaults.standard.bool(forKey: "keepKevin") }
		set { UserDefaults.standard.set(newValue, forKey: "keepKevin") }
	}
	
   
}
