//
//  BCAboutController.swift
//  Backchat
//
//  Created by Bradley Mackey on 24/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit
import FacebookLogin
import SafariServices
import MessageUI
import FirebaseAnalytics
import OneSignal
import JDStatusBarNotification

/// # BCAboutController
/// The class used for displaying the about view with the FAQ, more info and logout button.
final class BCAboutController: UITableViewController, MFMailComposeViewControllerDelegate, BCLogoutManagerDelegate {
	
	static let basicCellID = "BCBasicCell"
	static let subtitleCellID = "BCContentCell"

	private let faqQuestions:[String] = ["Why can't I see all my Facebook friends?",
	                                     "What does 'resets in' mean underneath the Grapevine title?",
	                                     "Why can't I see all the messages in a chat?",
	                                         "How do I know the person is who they say they are?",
	                             "Why can I only change my profile every 3 days?",
	                             "Why have I stopped getting push notifications?",
	                             "Should I turn on Background App Refresh?",
	                             "Why can't I ever change my profile?",
	                             "How can I deactivate my account?"]
	private let faqAnswers:[String] = ["You can only see friends that have downloaded and authorised Grapevine.",
	                                   "Once every 24 hours, every message in Grapevine is deleted. It doesn't matter how old each individual message is. You can see when this will happen each day by looking at the countdown timer.",
	                                   "You can only see the 25 most recent messages sent in each chat. If you stay in the chat, you'll see new messages as they are posted. But remember, everytime the reset timer runs out, every message in Grapevine is deleted.",
	                                       "Messages have the ✔️ emoji and real name if they are sent by the person who's chat you are currently in. As for anyone else, who knows. 💁🏽",
	                           "To reduce impersonations of other users.",
	                           "Push notifications are sent to your most recently logged in device. To get push notifications on your current device, log out and back in again. If this is your most recently logged in device, turn the notification switch off and on again.",
	                           "Background App Refresh allows you to see a little number by each friends name so you know how many notifications you've had from each person. So, if you want this, turn it on.",
	                           "Remember, you can only change your profile every 3 days. Also make sure the time and date on your device is accurate (turn on 'Set Automatically' in your Date and Time settings).",
	                           "You need to go to 'facebook.com/settings' and deactivate Grapevine from the 'Apps' panel. Your profile will then be removed from everyone's devices."]
	private let moreData:[String] = ["Terms of Service",
	                         "Privacy Policy",
	                         "Third Party Libraries",
	                         "Contact the Developer"]
	
	private var loggingOut:Bool = false
	private var searchController:BCSearchController!
    
    /// whether the switch should be enabled or not (set independantly from setting the notificaitons)
    public static var notificationsDisabled:Bool {
        get {
            return UserDefaults.standard.bool(forKey: "notificationsDisabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "notificationsDisabled")
			if newValue {
				FIRAnalytics.logEvent(withName: "enable_push_notifications", parameters: nil)
			} else {
				FIRAnalytics.logEvent(withName: "disable_push_notifications", parameters: nil)
			}
        }
    }
	
	public static var onlyMeNotifications:Bool {
		get { return UserDefaults.standard.bool(forKey: "onlyMeNotifications") }
		set { UserDefaults.standard.set(newValue, forKey: "onlyMeNotifications") }
	}
	
	public static var hideFlaggedMessages:Bool {
		get { return UserDefaults.standard.bool(forKey: "hideFlaggedMessages") }
		set { UserDefaults.standard.set(newValue, forKey: "hideFlaggedMessages") }
	}
    
    /// The facebookID of the current user
    public var facebookID:String?

	
	private enum TableSection: Int {
		case clearRecents = 0 // the clear recents button
        case notifications = 1 // the push notification cell
		case content = 2 // content options
		case faq    = 3 // FAQ (all stuff in notes plus a bit more technical stuff
		case more   = 4 // More (about me, version number etc)
		case logout = 5 // a single logout cell
	}

    override func viewDidLoad() {
        super.viewDidLoad()
		
		// assert that questions equals answers, otherwise something is very wrong.
		precondition(faqQuestions.count == faqAnswers.count)
		
		self.title = "Settings"
		
		self.tableView.rowHeight = UITableViewAutomaticDimension
		self.tableView.estimatedRowHeight = 50
		
		// build info label
		let label = UILabel(frame: .zero)
		label.textColor = .lightGray
		label.textAlignment = .center
		label.font = UIFont.boldSystemFont(ofSize: UIFont.smallSystemFontSize)
		label.text = "😄"
		// set the label to the appropriate build if we can
		let build:String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
		let version:String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
		label.text = "🛠 Version \(version) (\(build))"
		label.sizeToFit()
		label.center = CGPoint(x: self.view.frame.size.width/2, y: -120)
		self.tableView.addSubview(label)
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		self.tableView.reloadData()
		loggingOut = false
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		if loggingOut {
			searchController.performSegue(withIdentifier: "presentLoginFlow", sender: searchController)
		}
	}

    // MARK: - DATA SOURCE

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 6
    }
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard let sectionName = TableSection(rawValue: indexPath.section) else { fatalError("invalid section") }
		switch sectionName {
		case .faq, .notifications:
			break
		case .clearRecents:
			if BCSearchDataManager.shared.recentUsers.count > 0 || BCCurrentUser.isRecent {
				confirmClearRecentlyViewed()
			} else {
				break
			}
		case .logout:
			confirmLogoutAlert()
		case .more:
			switch indexPath.row {
			case 0: // terms of service
				showSafariVC(with: URL(string: "https://justgetgrapevine.com/terms/"))
			case 1: // privacy policy
				showSafariVC(with: URL(string: "https://justgetgrapevine.com/privacy/"))
			case 2: // 3rd party
				showSafariVC(with: URL(string: "https://justgetgrapevine.com/thirdparty/"))
			case 3: // contact developer
				if MFMailComposeViewController.canSendMail() {
					let mail = MFMailComposeViewController()
					mail.mailComposeDelegate = self
					mail.setToRecipients(["grapevine.enquiries@yahoo.com"])
					present(mail, animated: true)
				}
			default: fatalError("invaild row for about controller")
			}
		case .content:
			switch indexPath.row {
			case 0: // show flagged posts
				break
			case 1: // unblock all
				self.confirmUnblockAll()
			default: fatalError("invalid row")
			}
		}
		tableView.deselectRow(at: indexPath, animated: true)
	}

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		guard let sectionName = TableSection(rawValue: section) else { fatalError("invalid section") }
		switch sectionName {
        case .notifications: return 2
		case .logout: return 1
		case .faq:    return faqQuestions.count
		case .more:   return moreData.count
		case .clearRecents: return 1
		case .content: return 2
		}
		
    }
	
	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		guard let sectionName = TableSection(rawValue: section) else { fatalError("invaild section") }
		switch sectionName {
		case .logout: return nil
		case .notifications: return "Push Notifications"
		case .faq: return "Question and Answer"
		case .more: return "More Information"
		case .clearRecents: return "Clear Recents"
		case .content: return "Content"
		}
	}
	
	override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		guard let sectionName = TableSection(rawValue: section) else { fatalError("invaild section") }
		switch sectionName {
			// no footer for these sections
		case .faq, .more, .clearRecents, .logout, .content: return nil
        case .notifications:
			if UIApplication.shared.isRegisteredForRemoteNotifications {
				return "'Recent Chat Notifications' sends you notifications on your friends' profiles for the next 10 messages after you post. Turning this off will stop these notifications for any future messages you post - you will still get notifications for messages you have already posted whilst this setting was on."
			} else {
				return "Enable notifications in your settings to control it here."
			}
		}
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let sectionName = TableSection(rawValue: indexPath.section) else { fatalError("invaild section") }
		switch sectionName {
		case .clearRecents:
			return actionCell(for: indexPath, category: .clearRecents)
		case .logout:
			return actionCell(for: indexPath, category: .logout)
		case .faq:
			return faqCell(for: indexPath)
		case .more:
			return moreCell(for: indexPath)
        case .notifications:
			let category:BCSwitchCell.Category = indexPath.row == 0 ? .allNotifications : .friendNotifications
			return switchCell(for: indexPath, category: category)
		case .content:
			if indexPath.row == 0 {
				return switchCell(for: indexPath, category: .flaggedMessages)
			} else {
				return actionCell(for: indexPath, category: .unblock)
			}
		}
	}
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        guard let section = TableSection(rawValue: indexPath.section) else { return false }
        switch section {
        case .notifications, .faq: return false
        case .more, .logout: return true
		case .clearRecents:
			// only highlight the recents button so that we can 
			if BCSearchDataManager.shared.recentUsers.count > 0 || BCCurrentUser.isRecent {
				return true
			} else {
				return false
			}
		case .content:
			// only highlight the 'unblock users' button
			if indexPath.row == 0 { return false } else { return true }
        }
    }
	
	// MARK: - Cells
	
	private enum BCActionCellCategory:String {
		case clearRecents = "Clear Recently Viewed"
		case logout = "Log Out"
		case unblock = "Unblock All Users"
	}

	/// Returns an instance of the SingleCell used for various actions
	private func actionCell(for indexPath: IndexPath, category:BCActionCellCategory) -> BCSingleCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: BCSingleCell.id, for: indexPath) as! BCSingleCell
		cell.titleLabel.text = category.rawValue
		switch category {
		case .clearRecents:
			if !(BCSearchDataManager.shared.recentUsers.count > 0 || BCCurrentUser.isRecent) {
				cell.titleLabel.textColor = .lightGray
				return cell
			}
		case .logout, .unblock: break
		}
		cell.titleLabel.textColor = .red
		return cell
	}
	
	/// Returns a subtitle cell used for displaying a question and an answer
	private func faqCell(for indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: BCAboutController.subtitleCellID, for: indexPath) as! BCContentCell
		cell.titleLabel.text = faqQuestions[indexPath.row]
		cell.bodyLabel.text = faqAnswers[indexPath.row]
		cell.isUserInteractionEnabled = false
		return cell
	}
	
	/// Returns a default UITableViewCell used for displaying the cells for more info about the app.
	private func moreCell(for indexPath:IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: BCAboutController.basicCellID, for: indexPath)
		cell.textLabel?.text = moreData[indexPath.row]
		cell.accessoryType = .disclosureIndicator
		return cell
	}
    
	private func switchCell(for indexPath:IndexPath, category: BCSwitchCell.Category) -> BCSwitchCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BCSwitchCell.id, for: indexPath) as! BCSwitchCell
		// set the category
		cell.category = category
		// set the call title
		cell.titleLabel.text = category.title
		switch category {
		case .notDetermined: fatalError("invalid switchCell category")
		case .allNotifications:
			cell.switcher.isOn = !BCAboutController.notificationsDisabled
			//disabled if notifications not enabled
			if UIApplication.shared.isRegisteredForRemoteNotifications == false {
				cell.switcher.isOn = false
				cell.switcher.isEnabled = false
			}
		case .friendNotifications:
			cell.switcher.isOn = !BCAboutController.onlyMeNotifications
			if BCAboutController.notificationsDisabled {
				cell.switcher.isOn = false
			}
			// whether the switch can be interacted with
			if BCAboutController.notificationsDisabled {
				cell.switcher.isEnabled = false
			} else {
				cell.switcher.isEnabled = true
			}
			// disbaled if notifications not enabled
			if UIApplication.shared.isRegisteredForRemoteNotifications == false {
				cell.switcher.isOn = false
				cell.switcher.isEnabled = false
			}
		case .flaggedMessages:
			cell.switcher.isOn = !BCAboutController.hideFlaggedMessages
		}

        return cell
    }
	
	// MARK: - HELPER FUNCTIONS
	
	
	private func showSafariVC(with url:URL?) {
		guard let confirmedUrl = url else { return }
		if SFSafariViewController.canOpen(confirmedUrl) {
			let svc = SFSafariViewController(url: confirmedUrl, entersReaderIfAvailable: false)
			self.present(svc, animated: true, completion: nil)
		}
	}
	
	/// Displays a confirmation alert asking the user whether they would really like to clear all the recents.
	/// - parameter recentlyViewed: the users to remove
	private func confirmClearRecentlyViewed() {
		let alert = UIAlertController(title: "Clear Recently Viewed?", message: "This will remove everyone from your view history.", preferredStyle: .alert)
		let clearButton = UIAlertAction(title: "Clear", style: .destructive, handler: { alertAction in
			// change the clear friends cell to have gray text and deactivated
			BCSearchDataManager.shared.clearRecentlyViewed()
			let recentSection = TableSection.clearRecents.rawValue
			let ip = IndexPath(row: 0, section: recentSection)
			let cell = self.tableView.cellForRow(at: ip) as! BCSingleCell
			cell.titleLabel.textColor = .lightGray
			self.tableView.reloadRows(at: [ip], with: .none)
		})
		let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		[clearButton, cancelButton].forEach {
			alert.addAction($0)
		}
		self.present(alert, animated: true, completion: nil)
	}
	
	func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
		controller.dismiss(animated: true, completion: nil)
	}
	
	/// Produces an alert asking the user to confirm the logout, so they don't accidently click the button.
	private func confirmLogoutAlert() {
		let alert = UIAlertController(title: "Log out of Grapevine?", message: nil, preferredStyle: .alert)
		let logoutButton = UIAlertAction(title: "Log Out", style: .destructive, handler: { alertAction in
			// begin the logout process
			let logoutManager = BCLogoutManager(facebookID: self.facebookID)
			logoutManager.delegate = self
			logoutManager.logOut()
			self.loggingOut = true
			self.view.isUserInteractionEnabled = false
		})
		let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		[logoutButton, cancelButton].forEach {
			alert.addAction($0)
		}
		self.present(alert, animated: true, completion: nil)
	}
	
	private func confirmUnblockAll() {
		let alert = UIAlertController(title: "Unblock all?", message: "Everybody you have blocked will be able to view and comment on your profile again.", preferredStyle: .alert)
		let yes = UIAlertAction(title: "Yes", style: .destructive) { (alertAction) in
			self.unblockAll()
		}
		let no = UIAlertAction(title: "No", style: .cancel, handler: nil)
		[yes,no].forEach { alert.addAction($0) }
		self.present(alert, animated: true, completion: nil)
	}
	
	private func unblockAll() {
		guard let id = facebookID else {
			unblockAllCompleted(success: false); return
		}
		let unblock = BCFirebaseUnblockAll(facebookID: id)
		unblock.unblockAll { (completed) in
			self.unblockAllCompleted(success: completed)
		}
	}
	
	private func unblockAllCompleted(success:Bool) {
		let title = success ? "Unblocked all" : "Could not unblock"
		let message = success ? nil : "Make sure you have an internet connection."
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let dismiss = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(dismiss)
		DispatchQueue.main.async {
			self.present(alert, animated: true, completion: nil)
		}
	}
	

	// MARK: - IBACTION
    
    /// One of the switches in a notification cell was switched.
    @IBAction func switchSwitched(_ sender: UISwitch) {
		
		guard let category = BCSwitchCell.Category(rawValue: sender.tag) else { sender.setOn(!sender.isOn, animated: true); return }
		
		switch category {
		case .notDetermined:
			// we don't know what sent this, so just reverse the action
			sender.setOn(!sender.isOn, animated: true)
		case .allNotifications:
			BCAboutController.notificationsDisabled = !sender.isOn
			BCPushNotification.setNotifications(enabled: sender.isOn)
			// enable or disable the other switch accordingly
			let indexPath = IndexPath(row: 1, section: TableSection.notifications.rawValue)
			let cell = tableView.cellForRow(at: indexPath) as! BCSwitchCell
			if !sender.isOn {
				cell.switcher.setOn(false, animated: true)
			} else {
				cell.switcher.setOn(!BCAboutController.onlyMeNotifications, animated: true)
			}
			cell.switcher.isEnabled = sender.isOn
		case .friendNotifications:
			BCAboutController.onlyMeNotifications = !sender.isOn
		case .flaggedMessages:
			BCAboutController.hideFlaggedMessages = !sender.isOn
		}

    }
	
	// MARK: - LogoutManagerDelegate
	
	internal func logoutSucceeded() {
		self.performSegue(withIdentifier: "unwindToSearchVC", sender: self)
	}
	
	internal func logoutFailed() {
		self.loggingOut = false
		self.view.isUserInteractionEnabled = true
		let alert = UIAlertController(title: "Log Out Error", message: "You couldn't be logged out. Restart the app and try again", preferredStyle: .alert)
		let dismiss = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(dismiss)
		self.present(alert, animated: true, completion: nil)
	}
	
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
		if segue.identifier == "unwindToSearchVC" {
			searchController = segue.destination as! BCSearchController
		}
    }
}
