//
//  UIViewController+Alerts.swift
//  Backchat
//
//  Created by Bradley Mackey on 11/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase // for analytics
import UIKit

extension BCFirebaseChatController {
	
	/// When there was an error with posting media.
	/// - parameter errorCode: the code of the error, so we can track this down later.
	/// - parameter resolve: what the user can do to resolve the situation (defults to "Try logging out and back in again.")
	public func mediaErrorAlert(_ errorCode:String, resolve:String = "Try logging out and back in again.") {
		FIRCrashMessage("Media upload failed with error code \(errorCode)")
		FIRAnalytics.logEvent(withName: "image_post_error_other", parameters: ["code":errorCode as NSObject])
		let alert = UIAlertController(title: "Error #\(errorCode)", message: "Media could not be uploaded. " + resolve, preferredStyle: .alert)
		let dismiss = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(dismiss)
		self.present(alert, animated: true, completion: nil)
	}
	
	/// Called if we could not post to the realtime database. This shouldn't happen at all really.
	public func couldNotPostAlert(reason:String) {
		FIRCrashMessage("Could not post to realtime database (blocked by user)")
		FIRAnalytics.logEvent(withName: "post_error_blocked", parameters: nil)
		let alert = UIAlertController(title: "Can't Post", message: reason, preferredStyle: .alert)
		let ok = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(ok)
		self.present(alert, animated: true, completion: nil)
		self.view.isUserInteractionEnabled = true
		self.navigationController?.navigationBar.isUserInteractionEnabled = true
	}
	
	/// Alert to display if we cannot capture/choose media for a given chat.
	/// - parameter title: the type of action that we cannot perform.
	public func mediaNotAvalibleAlert(title:String) {
		let alert = UIAlertController(title: "Can't \(title) 😣", message: "Try reinstalling Grapevine.", preferredStyle: .alert)
		let dismiss = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(dismiss)
		self.present(alert, animated: true, completion: nil)
	}
	
	/// Lets the user know if camera access has been denied
	/// - parameter thingNotAuthorised: 'Camera' or 'Microphone'
	public func cameraNotAuthorised(thingNotAuthorised:String) {
		FIRCrashMessage("\(thingNotAuthorised)_not_authorised")
		FIRAnalytics.logEvent(withName: "\(thingNotAuthorised)_not_authorised", parameters: nil)
		let alert = UIAlertController(title: "\(thingNotAuthorised) Access Denied", message: "Allow \(thingNotAuthorised) access in your privacy settings to capture.", preferredStyle: .alert)
		let openSettings = UIAlertAction(title: "Settings", style: .cancel) { (alertAction) in
			// open the app settings so the user can allow access
			let settingsUrl = URL(string: UIApplicationOpenSettingsURLString)
			guard let url = settingsUrl else { return }
			UIApplication.shared.openURL(url)
		}
		let dismiss = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
		[dismiss, openSettings].forEach { alert.addAction($0) }
		self.present(alert, animated: true, completion: nil)
	}
	
}
