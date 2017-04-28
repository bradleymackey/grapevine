//
//  BCFirebaseChatCategory.swift
//  Backchat
//
//  Created by Bradley Mackey on 30/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation

/// # BCFirebaseChatCategory
/// The type of chat that the user is currently looking at, so we know if they are the current user or not to perform custom behaviour for each.
public enum BCFirebaseChatCategory {
	case user, currentUser
}
