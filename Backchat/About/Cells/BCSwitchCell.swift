//
//  BCNotificationCell.swift
//  Backchat
//
//  Created by Bradley Mackey on 09/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import UIKit

/// # BCNotificationCell
/// A cell used to display the notification toggle cells in the `BCAboutController`.
final class BCSwitchCell: UITableViewCell {
	
	// Used to identify and link the table cell to the table cell's switch
	public enum Category:Int {
		
		case notDetermined = 0
		case allNotifications = 1
		case friendNotifications = 2
		case flaggedMessages = 3
		
		public var title:String {
			switch self {
			case .notDetermined: return ""
			case .allNotifications: return "My Profile Notifications"
			case .friendNotifications: return "Recent Chat Notifications"
			case .flaggedMessages: return "Show Flagged Messages"
			}
		}
	}
	
    static let id = "BCSwitchCell"
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var switcher: UISwitch!
	public var category:BCSwitchCell.Category = .notDetermined {
		didSet {
			// assign the switch tag to be the same as the cel
			switcher.tag = category.rawValue
		}
	}

}
