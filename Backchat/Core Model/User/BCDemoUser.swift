//
//  DemoPerson.swift
//  Backchat
//
//  Created by Bradley Mackey on 21/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation
import UIKit

/// # BCDemoUser
/// Represents the class used to display the demo user.
/// - Note: This class is seperate from `User` as we do not retrieve this from Realm, we just generate it on the fly.
final class BCDemoUser {
	public let name = "Kevin"
	public let profilePicture = UIImage(named: "default")!
}
