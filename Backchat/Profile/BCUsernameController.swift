//
//  BCUsernameController.swift
//  Backchat
//
//  Created by Bradley Mackey on 01/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit
import JDStatusBarNotification
import Firebase

final class BCUsernameController: UIViewController, UITextFieldDelegate {
	
	static var easterEggCounter = 0
	
	// MARK: - TextFields
	private enum TextField: Int {
		case username = 0
		case emoji    = 1
	}
	
	/// Enum of the possible states we can be in, in regard to allowing a user to change their profile.
	private enum ProfileSetStatus {
		case fetchingTime
		case invalidTime
		case timeFetchError
		case tooEarly
		case canSet
	}
	
	// MARK: - Properties
	@IBOutlet weak var newUsernameButton: UIButton! {
		didSet {
			newUsernameButton?.titleLabel?.minimumScaleFactor = 0.3
		}
	}
	@IBOutlet weak var changeColourButton: UIButton!
	@IBOutlet weak var changeEmojiButton: UIButton!
	@IBOutlet weak var tapToChangeLabel: UILabel!
	

	private var previousUsername:String!
	private var previousEmoji:String!
	
	/// The current colour letter of the user
	private var currentColorLetter:BCColourLetter = .black {
		didSet {
			newUsernameButton.setTitleColor(BCColourLetter.colourFromLetter(letter: currentColorLetter.rawValue), for: .normal)
			newUsernameButton.bounce(1, completion: nil)
		}
	}
	
	
	/// Local value of 'canSetProfile' set in viewDidLoad, local because we only prevent changes once the user has backed out of the view and comes back in.
	private var profileSetStatus:ProfileSetStatus = .fetchingTime {
		didSet { self.setProfile(for: profileSetStatus) }
	}

	
	// MARK: - View controller lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
		
		// FYI: EDGE INSETS ON UIBUTTONS SET TO -1 IN STORYBOARD TO WRAP CLOSER TO THE CONTENT - LIKE UILABELS
		
        // Set the title of the ViewController
		self.title = "My Profile"
		// Make sure that the username can fit in the width
		self.newUsernameButton.titleLabel?.adjustsFontSizeToFitWidth = true
        // set all the correct values for the profile
		self.setUserValuesFromDefaults()
		// set the tutorial as complete, so we don't automatically show the profile screen again
        BCCurrentUser.tutorialComplete = true
		
		
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		// make sure the time is accurate every time the view appears
		profileSetStatus = .fetchingTime
		// if it's not yet time, then disallow, no point checking clock accuracy.
		if !BCCurrentUser.canSetProfile {
			profileSetStatus = .tooEarly; return
		}
		// time seems valid. Now check if the user's clock is accurate so we know they are not cheating
		BCTimeCheck.checkTimeAccuracy { (response) in
			// perform this on the main thread as we will need to do some modification of UI
			DispatchQueue.main.async {
				switch response {
				case .accurate:
					self.profileSetStatus = .canSet
				case .inaccurate:
					self.profileSetStatus = .invalidTime
				case .error:
					self.profileSetStatus = .timeFetchError
				}
			}
		}
	}


	// MARK: - Methods
	
	private func setProfile(for status:ProfileSetStatus) {
		tapToChangeLabel.bounce(1, completion: nil) // bounce to show it changed
		switch profileSetStatus {
		case .fetchingTime:
			setButtons(enabled: false)
			tapToChangeLabel.text = "Please wait. Checking your time is accurate..."
		case .invalidTime:
			setButtons(enabled: false)
			tapToChangeLabel.text = "The date or time on your device is incorrect. See Settings for help."
		case .tooEarly:
			setButtons(enabled: false)
			let period = BCCurrentUser.periodUntilProfileCanChange()
			tapToChangeLabel.text = "Wait \(period.time) \(period.denomination) until you can change your profile."
		case .canSet:
			setButtons(enabled: true)
			tapToChangeLabel.text = "Tap details to change."
		case .timeFetchError:
			setButtons(enabled: false)
			tapToChangeLabel.text = "Couldn't check your time accuracy. Make sure you have an internet connection."
		}
	}
	
	private func setButtons(enabled:Bool) {
		[newUsernameButton, changeEmojiButton, changeColourButton].forEach {
			$0?.isEnabled = enabled
		}
	}
	
	private func setUserValuesFromDefaults() {
		// initially set these value without animation, otherwise it can look a bit glitchy
		UIView.performWithoutAnimation {
			// set default values
			let username = BCCurrentUser.username
			newUsernameButton.setTitle(username, for: .normal)
			previousUsername = username
			
			// set current colour letter and colour for the username
			let color = BCColourLetter.colourFromCurrentUserLetter()
			newUsernameButton.setTitleColor(color, for: .normal)
			if let currentCol = BCColourLetter(rawValue: BCCurrentUser.colourLetter) {
				currentColorLetter = currentCol
			} else {
				currentColorLetter = .black
			}
			
			let emoji = BCCurrentUser.emoji
			changeEmojiButton.titleLabel?.text = emoji
			changeEmojiButton.setTitle(emoji, for: .normal)
			previousEmoji = emoji
		}
	}

	@IBAction func changeUsernameButtonPressed(_ sender: UIButton) {
		let alertController = UIAlertController(title: "Change Username", message: "Your username must be 20 characters or less.", preferredStyle: .alert)
		alertController.addTextField { textField in
			textField.text = self.previousUsername
			textField.placeholder = "Username"
			textField.delegate = self
			textField.clearButtonMode = .whileEditing
			textField.tag = TextField.username.rawValue
		}
		let okAction = UIAlertAction(title: "OK", style: .default) { aController in
			guard let textField = alertController.textFields?.first else { return }
			guard let text = textField.text else { return }
			if self.profileSetStatus != .canSet { return }
			if text == "anon" || text == "anonymous" { return } // name is not allowed to be anonymous
			if text.characters.count > 0 && text.characters.count <= 20 { // a username must be more than 0 characters less than 20
				let trimmedUsername = text.trimmingCharacters(in: .whitespacesAndNewlines)
				BCCurrentUser.username = trimmedUsername // set the value for defaults
				self.newUsernameButton.setTitle(trimmedUsername, for: .normal)
				self.previousUsername = trimmedUsername
				self.newUsernameButton.bounce(1, completion: nil)
			}
		}
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		[okAction,cancelAction].forEach {
			alertController.addAction($0)
		}
		if profileSetStatus == .canSet {
			self.present(alertController, animated: true, completion: nil)
		}
	}
	
	@IBAction func changeColourButtonPressed(_ sender: UIButton) {
		FIRAnalytics.logEvent(withName: "change_colour_pressed", parameters: nil)
        currentColorLetter = BCColourLetter.nextColour(currentColour: currentColorLetter)
		if profileSetStatus == .canSet { BCCurrentUser.colourLetter = currentColorLetter.rawValue }
	}
	
	@IBAction func changeEmojiButtonPressed(_ sender: UIButton) {
		let alertController = UIAlertController(title: "Change Emoji", message: "This will be your profile emoji.", preferredStyle: .alert)
		alertController.addTextField { textField in
			textField.text = self.previousEmoji
			textField.delegate = self
			textField.clearButtonMode = .never
			textField.tag = TextField.emoji.rawValue
			textField.font = UIFont.systemFont(ofSize: 33)
			textField.textAlignment = NSTextAlignment.center
		}
		let okAction = UIAlertAction(title: "OK", style: .default) { aController in
			guard let textField = alertController.textFields?.first else { return }
			guard let text = textField.text else { return }
			if self.profileSetStatus != .canSet { return } // ensure we can set profile
			if text.characters.count == 0 { return } // ensure text is not blank
			if !text.isSingleEmoji { return } // ensure this is a single emoji
			BCCurrentUser.emoji = text // set the value for defaults
			self.changeEmojiButton.setTitle(text, for: .normal)
			self.previousEmoji = text
			self.changeEmojiButton.bounce(1, completion: nil)
		}
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		[okAction,cancelAction].forEach {
			alertController.addAction($0)
		}
		if profileSetStatus == .canSet {
			self.present(alertController, animated: true, completion: nil)
		}
	}
	
	// MARK: - TextFieldDelegate

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		
		// backspace is always allowed
		let char = string.cString(using: String.Encoding.utf8)!
		let characterID = strcmp(char, "\\b")
		if characterID == -92 { return true}
		guard let text = textField.text else { return false }
		guard let tagName = TextField(rawValue: textField.tag) else {
			FIRCrashMessage("invaild textField tag (UsernameController)")
			return false
		}
		
		if profileSetStatus != .canSet { return false }
		
		switch tagName {
		case .username:
			for char in string.characters {
				if char == " " { return false }
			}
			// username cannot be longer than 20 characters
			if (string.characters.count + text.characters.count) > 20 {
				return false
			}
			if (text.characters.count > 20) { return false }
			
			if (string.containsEmoji) { return false }
		
			switch string {
			case " ", "\n", "\r": // no space, new line or return characters allowed
				return false
			default:
				return true
			}
			
		case .emoji:
			// always deny the currentUser tick. (consider it a banned emoji)
			if string == "✔️" { return false }
			if string.isSingleEmoji {
				textField.text = ""
				return true
			} else {
				return false
			}
		}
	}
	
	// MARK: - Easter Egg
	
	override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
		if event?.subtype == UIEventSubtype.motionShake {
			//BCUsernameController.easterEggCounter += 1
		}
	}

}
