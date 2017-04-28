//
//  BCWelcomeController.swift
//  Backchat
//
//  Created by Bradley Mackey on 01/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit
import SafariServices
import FBSDKLoginKit

/// # BCWelcomeController
/// The view controller displayed when a user is not logged in and needs to, so we display this controller with all the controls needed to log a user in.
final class BCWelcomeController: UIViewController, BCLoginManagerDelegate, UITextViewDelegate, FBSDKLoginButtonDelegate {
	
    // MARK: - Properties
	@IBOutlet weak var mainTitleLabel: UILabel!
	@IBOutlet weak var taglineLabel: UILabel!
	@IBOutlet weak var mainInfoText: UITextView!
	@IBOutlet weak var disclaimerText: UITextView!
	
	@IBOutlet weak var loginButton: FBSDKLoginButton!
	
	@IBOutlet weak var loggingInLabel: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		loggingInLabel.alpha = 0
		loginButton.delegate = self
		loginButton.loginBehavior = .native
		loginButton.readPermissions = ["public_profile","user_friends"]
		disclaimerText.delegate = self
	}
	
    // MARK: - Methods
	
	private func displayErrorAlert(description:String) {
		let alert = UIAlertController(title: "Error", message: "You couldn't be signed in. \(description).", preferredStyle: .alert)
		let ok = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(ok)
		self.present(alert, animated: true, completion: nil)
	}
    
    // MARK: - BCLoginManagerDelegate
    
    func loginFailed() {
		toggleLoginButton(hidden:false)
        self.displayErrorAlert(description: "Make sure you have an internet connection")
    }
    
    func loginSucceeded() {
        self.dismiss(animated: true)
    }
	
	func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
		if SFSafariViewController.canOpen(URL) {
			let svc = SFSafariViewController(url: URL)
			self.present(svc, animated: true, completion: nil)
			return false
		}
		return true
	}
	
	// MARK: - FBSDKLoginButtonDelegate
	
	func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!) {
		if let err = error {
			toggleLoginButton(hidden:false)
			displayErrorAlert(description: err.localizedDescription)
			return
		}
		if result.isCancelled {
			toggleLoginButton(hidden:false)
			return
		}
		guard let token = result.token?.tokenString else {
			toggleLoginButton(hidden:false)
			displayErrorAlert(description: "Make sure you have an internet connection")
			return
		}
		// begin the login process
		let loginManager = BCLoginManager()
		loginManager.delegate = self
		loginManager.logIn(with: token)
	}
	
	func loginButtonWillLogin(_ loginButton: FBSDKLoginButton!) -> Bool {
		toggleLoginButton(hidden:true)
		return true
	}

	// do nothing, we don't log out here
	func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {}
	
	/// Hides the login button and shows some 'logging in' text
	private func toggleLoginButton(hidden:Bool) {
		let labelAlpha:CGFloat = hidden ? 1 : 0
		let buttonAlpha:CGFloat = hidden ? 0 : 1
		UIView.animate(withDuration: 0.2) {
			self.loggingInLabel.alpha = labelAlpha
			self.loginButton.alpha = buttonAlpha
		}
	}
	
}
