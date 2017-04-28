//
//  BCNotificationController.swift
//  Backchat
//
//  Created by Bradley Mackey on 10/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import UIKit

/// # BCNotificationController
/// The view controller which displays the notification info popup.
final class BCNotificationController: UIViewController {
	
	@IBAction func notificationButtonPressed(_ sender: UIButton) {
		BCPushNotification.promptForNotifications()
		self.dismiss(animated: true, completion: nil)
	}
	
}
