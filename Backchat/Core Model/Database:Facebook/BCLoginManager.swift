//
//  BCLoginManager.swift
//  Backchat
//
//  Created by Bradley Mackey on 10/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase
import FacebookLogin
import FacebookCore

/// # BCLoginManagerDelegate
/// Conform to this protocol to recieve notifications when `BCLoginManager` either succeeds or fails.
protocol BCLoginManagerDelegate:class {
	/// The login was succesful.
	func loginSucceeded()
	/// Called if we were not able to login, for whatever reason.
	func loginFailed()
}

/// # BCLoginManager
/// Utility class used to login to Firebase Auth.
final class BCLoginManager {
    
    // MARK: - Properties
    /// The delegate used to report on the status of login
    public weak var delegate:BCLoginManagerDelegate!

    // MARK: - Methods
	
	/// Login to Firebase using a facebook authentication token
    public func logIn(with facebookToken:String) {
        let credential = FIRFacebookAuthProvider.credential(withAccessToken: facebookToken)
        guard let auth = FIRAuth.auth() else {
            print("Could not init FIRAuth.auth()")
            FIRCrashMessage("Could not init FIRAuth.auth()")
            self.delegate.loginFailed()
            return
        }
        auth.signIn(with: credential) { (user, error) in
            if error != nil {
                print("Firebase login failed. \(error)")
                FIRCrashMessage("Firebase login failed. \(error)")
                self.delegate.loginFailed()
            } else {
                print("Logged in!")
                
                // set notifications enabled again (default value)
                BCPushNotification.setNotificationTokenForSession = false
                BCPushNotification.setNotifications(enabled: true)
				BCAboutController.onlyMeNotifications = false
                BCAboutController.notificationsDisabled = false
                self.delegate.loginSucceeded()
            }
        }
    }
    
}
