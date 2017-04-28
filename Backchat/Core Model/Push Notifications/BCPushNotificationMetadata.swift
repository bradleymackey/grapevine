//
//  BCPushNotificationMetadata.swift
//  Backchat
//
//  Created by Bradley Mackey on 26/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation

/// # BCPushNotificationMetadata
/// The data that should be passed about so that when we post an image or chat message, we know after the upload has completed what the title of the notification should be, who to send it to etc.
public struct BCPushNotificationMetadata {
	/// The notification tokens of the other users to whom notifications should be sent to
	public let otherTokens:Set<String>
	/// The id of the user who's chat we are posting into
	public let ownerFacebookID:String
	/// The real name of the person who's chat we are posting into
	public let nameOfChat:String?
	/// Whether or not the current user is posting in their own chat
	public let chatCategory:BCFirebaseChatCategory
}
