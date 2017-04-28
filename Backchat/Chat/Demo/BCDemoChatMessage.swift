//
//  BCDemoChatMessage.swift
//  Backchat
//
//  Created by Bradley Mackey on 07/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import RealmSwift

/// # BCDemoChatMessage
/// The chat message class used by Realm for the `BCDemoChatController`, with very similar fields to `BCFirebaseChatMessage`, except this is a class specialised to be stored in Realm, whilst `BCFirebaseChatMessage` is a struct optimised for performance.
/// - note: Realm does not like initalisers.
final public class BCDemoChatMessage:Object {
	
	// MARK: - Properties
	
	/// The username string as it should be displayed
	dynamic public var username:String = ""
	/// The chat message string
	dynamic public var message:String = ""
	/// The profile emoji of the user
	dynamic public var emoji:String = ""
	/// The colour letter of the user
	dynamic public var colourLetter:String = ""
	/// The timestamp of the current message (initialised to be the current date on the current device)
	dynamic public var timestamp:Date = Date()
	/// The name of a potential image
	dynamic public var imageName:String = ""
	

}
