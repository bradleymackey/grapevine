//
//  BCChatController.swift
//  Backchat
//
//  Created by Bradley Mackey on 18/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import UIKit
import SlackTextViewController
import TTTAttributedLabel
import SafariServices
import MessageUI
import JDStatusBarNotification
import Firebase
import Photos
import MBProgressHUD

/// # BCChatController
/// This is the base class used by the `BCFirebaseChatController` and `BCDemoChatController`, which sets up the default appearence of how the SLKTextViewController should look.
/// - note: there is not much shared model interaction code because of the fact that the subclasses should have very different data sources and such interactions. This is solely for the basic look and function of some aspects of the view controller.
public class BCChatController: SLKTextViewController, TTTAttributedLabelDelegate, MFMailComposeViewControllerDelegate {
	
	// MARK: - Properties
	
	/// Force unwrap the tableView, as we know it will be there (required by SlackViewController)
	override public var tableView: UITableView { return super.tableView! }
	
	/// The view that contains the title (name) label and subtitle (view count) label.
	public var subtitleView: BCSubtitleLabelView!
	
	public var saveHud:MBProgressHUD?
	
	// MARK: - Lifecycle

    override public func viewDidLoad() {
        super.viewDidLoad()
		
		// Register the custom cell nibs for display in the tableView
		let chatNib = UINib(nibName: "BCChatCell", bundle: Bundle.main)
		self.tableView.register(chatNib, forCellReuseIdentifier: BCChatCell.id)
		let mediaNib = UINib(nibName: "BCMediaCell", bundle: Bundle.main)
		self.tableView.register(mediaNib, forCellReuseIdentifier: BCMediaCell.id)
		let noContentNib = UINib(nibName: "BCNoContentCell", bundle: Bundle.main)
		self.tableView.register(noContentNib, forCellReuseIdentifier: BCNoContentCell.id)
		
		// setup the view
		setNavigationBarTitleView()
		setupLongPressGestureRecogniser()
		setupTableView()
		setupTextInputBar()
    }
	
	override public func viewDidAppear(_ animated: Bool) {
		// workaround to not flash scroll indicator incorrectly
		self.tableView.showsVerticalScrollIndicator = false
		super.viewDidAppear(animated)
		self.tableView.showsVerticalScrollIndicator = true
	}
	
	// MARK: - Setup
	
	/// Creates a `BCNaigationSubtitleView` instance to use as the titleView on on the `navigationItem` at sets it with the appropraite title and subtitle.
	private func setNavigationBarTitleView() {
		subtitleView = BCSubtitleLabelView(frame: .zero, viewWidth: self.view.frame.size.width)
		self.navigationItem.titleView = subtitleView
	}
	
	/// Used for copying text and images that get posted.
	private func setupLongPressGestureRecogniser() {
		let gestureRecogniser = UILongPressGestureRecognizer(target: self, action: #selector(BCChatController.longPress(_:)))
		gestureRecogniser.numberOfTouchesRequired = 1
		self.view.addGestureRecognizer(gestureRecogniser)
	}
	
	/// Sets up the appearance of the table.
	private func setupTableView() {
		// so that the uibutton on videos doesnt steal the touch as easily
		self.tableView.delaysContentTouches = false
		self.tableView.canCancelContentTouches = true
		// dynamically size the tableview cells
		self.tableView.rowHeight = UITableViewAutomaticDimension
		self.tableView.estimatedRowHeight = 60
		self.tableView.separatorColor = UIColor(colorLiteralRed: 0.9, green: 0.9, blue: 0.9, alpha: 1)
		self.tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
		self.tableView.separatorStyle = .singleLine
		self.tableView.tableFooterView = UIView() // hides separator lines for non-existent cells
		// Fix weird glitch on iOS 10 where the message scrolls up too far
		self.automaticallyAdjustsScrollViewInsets = false
		self.tableView.contentInset = .zero
		
		// MARK: SLKTVC's setup
		self.bounces = true
		self.shakeToClearEnabled = false
		self.isKeyboardPanningEnabled = true
		self.shouldScrollToBottomAfterKeyboardShows = true
		self.isInverted = true // inverts so messages go to bottom and we see the bottom of the tableView first.
	}
	
	
	
	/// Sets up the send button and appearance of the text input bar.
	private func setupTextInputBar() {
		self.rightButton.setTitle(NSLocalizedString("Send", comment: "send button for messages"), for: UIControlState())
		
		self.textInputbar.autoHideRightButton = true
		self.textInputbar.maxCharCount = 200
		self.textInputbar.counterStyle = .split
		self.textInputbar.counterPosition = .top
		
		self.textInputbar.editorTitle.textColor = UIColor.darkGray
		self.textInputbar.editorRightButton.tintColor = .black
		self.textInputbar.editorLeftButton.tintColor = .black
		
		self.textView.keyboardType = .default
		self.textView.returnKeyType = .default
		self.textView.enablesReturnKeyAutomatically = true
		//self.textView.delegate = self
		self.textView.maxNumberOfLines = 5
		
		self.textView.placeholder = "Type a message..."
		
		// so that 'typing' messages stay until we manually dismiss them
		self.typingIndicatorView?.interval = 0
	}
	
	
	// MARK: - Table View
	
	/// Cells should not highlight with the table
	override public func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
		return false
	}
	
	public override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		// call the reuse thing here so that any video will stop playing as soon as it's off the screen,
		cell.prepareForReuse()
	}
	
	
	
	// MARK: - Long press guesture
	
	/// This is the function that copies the message and displays a 'Copied' indication to the user.
	@objc private func longPress(_ sender: UILongPressGestureRecognizer) {
		// Copy the message and display a 'Copied' indication to the user.
		if sender.state != .began { return }
		let location = sender.location(in: self.tableView)
		guard let indexPath = tableView.indexPathForRow(at: location) else { return }
		guard let cell = tableView.cellForRow(at: indexPath) else { return }
		// if this is just a text cell, then copy the text inside the cell
		if let textCell = cell as? BCChatCell {
			
			
			guard let flagReportInfo = textCell.flagReportOnlyInfo else {
				shareFor(textCell: textCell); return
			}
			guard let message = textCell.message else {
				let halfAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
				let share = UIAlertAction(title: "Copy Text", style: .default, handler: { (alertAction) in
					self.shareFor(textCell: textCell)
				})
				let more = UIAlertAction(title: "More Options", style: .destructive, handler: { (alertAction) in
					self.showHalfOptions(flagReportInfo: flagReportInfo)
				})
				let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
				[share,more,cancel].forEach { halfAlert.addAction($0) }
				self.present(halfAlert, animated: true, completion: nil)
				return
			}
			let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
			let share = UIAlertAction(title: "Copy Text", style: .default, handler: { (alertAction) in
				self.shareFor(textCell: textCell)
			})
			let more = UIAlertAction(title: "More Options", style: .destructive, handler: { (alertAction) in
				self.showFullOptions(message: message, flagReportInfo: flagReportInfo)
			})
			let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
			[share,more,cancel].forEach { alert.addAction($0) }
			self.present(alert, animated: true, completion: nil)
			
		} else

		// this is a media cell, so interact with the image accordingly, displaying a share sheet
		if let mediaCell = cell as? BCMediaCell {
			
			guard let flagReportInfo = mediaCell.flagReportOnlyInfo else {
				shareFor(mediaCell: mediaCell); return
			}
			// if there's no attached message, just present the standard share information
			guard let message = mediaCell.message else {
				let halfAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
				let share = UIAlertAction(title: "Share Post", style: .default, handler: { (alertAction) in
					self.shareFor(mediaCell: mediaCell)
				})
				let more = UIAlertAction(title: "More Options", style: .destructive, handler: { (alertAction) in
					self.showHalfOptions(flagReportInfo: flagReportInfo)
				})
				let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
				[share,more,cancel].forEach { halfAlert.addAction($0) }
				self.present(halfAlert, animated: true, completion: nil)
				return
			}
			
			let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
			let share = UIAlertAction(title: "Share Post", style: .default, handler: { (alertAction) in
				self.shareFor(mediaCell: mediaCell)
			})
			let more = UIAlertAction(title: "More Options", style: .destructive, handler: { (alertAction) in
				self.showFullOptions(message: message, flagReportInfo: flagReportInfo)
			})
			let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
			[share,more,cancel].forEach { alert.addAction($0) }
			self.present(alert, animated: true, completion: nil)
		}
	}
	
	private func blockConfirmAlert(message:BCFirebaseChatMessage) {
		let alert = UIAlertController(title: "Block user?", message: "The only way to unblock this user again is to unblock everybody.", preferredStyle: .alert)
		let delete = UIAlertAction(title: "Block", style: .destructive) { (alertAction) in
			self.blockUser(chatMessage: message)
		}
		let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		[delete,cancel].forEach { alert.addAction($0) }
		DispatchQueue.main.async {
			self.present(alert, animated: true, completion: nil)
		}
	}
	
	private func deleteConfirmAlert(message:BCFirebaseChatMessage) {
		let alert = UIAlertController(title: "Delete message?", message: nil, preferredStyle: .alert)
		let delete = UIAlertAction(title: "Delete", style: .destructive) { (alertAction) in
			self.deleteMessage(chatMessage: message)
		}
		let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		[delete,cancel].forEach { alert.addAction($0) }
		DispatchQueue.main.async {
			self.present(alert, animated: true, completion: nil)
		}
	}
	
	private func cannotFlagAlert() {
		let alert = UIAlertController(title: "Cannot flag message", message: "Log out and back in again.", preferredStyle: .alert)
		let dismiss = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(dismiss)
		DispatchQueue.main.async {
			self.present(alert, animated: true, completion: nil)
		}
	}
	
	/// The alert to show when a user is in another user's chat
	private func showHalfOptions(flagReportInfo:(key:String,uid:String,content:String)) {
		let alert = UIAlertController(title: "More Options", message: nil, preferredStyle: .actionSheet)
		let flag = UIAlertAction(title: "Flag Inappropriate", style: .destructive) { (alertAction) in
			self.flagMessage(key: flagReportInfo.key, uid: flagReportInfo.uid)
		}
		let report = UIAlertAction(title: "Report User", style: .destructive) { (alertAction) in
			self.reportUser(key: flagReportInfo.key, uid: flagReportInfo.uid, content: flagReportInfo.content)
		}
		let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		[flag,report,cancel].forEach { alert.addAction($0) }
		DispatchQueue.main.async {
			self.present(alert, animated: true, completion: nil)
		}
	}
	
	/// The alert to show when a user is in their own chat
	private func showFullOptions(message:BCFirebaseChatMessage,flagReportInfo:(key:String,uid:String,content:String)) {
		let alert = UIAlertController(title: "More Options", message: nil, preferredStyle: .actionSheet)
		let flag = UIAlertAction(title: "Flag Inappropriate", style: .destructive) { (alertAction) in
			if let key = message.firebaseDatabaseKey {
				self.flagMessage(key: key, uid: message.uid)
			} else {
				self.cannotFlagAlert()
			}
		}
		let remove = UIAlertAction(title: "Delete Message", style: .destructive) { (alertAction) in
			self.deleteConfirmAlert(message: message)
		}
		let block = UIAlertAction(title: "Block User", style: .destructive) { (alertAction) in
			self.blockConfirmAlert(message: message)
		}
		let report = UIAlertAction(title: "Report User", style: .destructive) { (alertAction) in
			self.reportUser(key: flagReportInfo.key, uid: flagReportInfo.uid, content: flagReportInfo.content)
		}
		let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		[flag,remove,block,report,cancel].forEach { alert.addAction($0) }
		DispatchQueue.main.async {
			self.present(alert, animated: true, completion: nil)
		}
	}
	
	public func reportUser(key:String,uid:String,content:String) {
		if MFMailComposeViewController.canSendMail() {
			let mail = MFMailComposeViewController()
			mail.mailComposeDelegate = self
			mail.setToRecipients(["grapevine.contentreport@yahoo.com"])
			mail.setSubject("[USER REPORT] - " + UUID().uuidString)
			let combined = key + uid + content
			let hash = combined.MD5
			let body = "'ORIGINKEY':\(key)'USERUID':\(uid)'CONTENT':\(content)'MD5HASH':\(hash)'DATE':\(Date())"
			var finalBody = ""
			do {
				finalBody = try body.aesEncrypt(key: "7LPL&5qwqu&XgW884l*13QmGdOaliHon", iv: "fXc0tz!gakA2kFdz")
			} catch {
				FIRCrashMessage("Error encrypting, sending unencrypted.")
				finalBody = body
			}
			mail.setMessageBody("WRITE ANY COMMENTS HERE:\n\n\n\n\n\n\n\n\n\n\n\n--------------------------\n[REPORT INFO] (do not edit):\n--------------------------\(finalBody)", isHTML: false)
			DispatchQueue.main.async {
				self.present(mail, animated: true)
			}
		} else {
			DispatchQueue.main.async {
				self.displayErrorAlert(title: "Cannot Send Email", message: "Check that you have email setup.")
			}
		}
	}

	public func flagMessage(key:String, uid:String) {
		fatalError("override me for specific datasource")
	}
	
	public func deleteMessage(chatMessage:BCFirebaseChatMessage) {
		fatalError("override me for specific dataSource")
	}
	
	public func blockUser(chatMessage:BCFirebaseChatMessage) {
		fatalError("override me for specific dataSource")
	}
	
	private func shareFor(textCell:BCChatCell) {
		UIPasteboard.general.string = textCell.messageLabel.text
		self.showCopyAlert()
		DispatchQueue.main.async {
			textCell.messageLabel.bounce(1, completion: nil)
		}
	}
	
	private func shareFor(mediaCell:BCMediaCell) {
		if let vidURL = mediaCell.videoURL {
			// show the loading indicator, as downloading may take some time
			hud(show: true)
			DispatchQueue.global(qos: .userInitiated).async {
				do {
					// begin to download the video to a directory where we can do something useful with it
					let data = try Data(contentsOf: vidURL)
					let temp = URL(fileURLWithPath: NSTemporaryDirectory().appending("sharevideo.mp4"))
					try data.write(to: temp, options: .atomic)
					
					let objectsToShare = [temp] as [Any]
					let activityVc = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
					activityVc.popoverPresentationController?.sourceView = self.view
					DispatchQueue.main.async {
						self.hud(show: false)
						self.present(activityVc, animated: true, completion: nil)
					}
				} catch {
					FIRCrashMessage("Could not save video from remote")
					FIRAnalytics.logEvent(withName: "failed_save_video", parameters: nil)
					DispatchQueue.main.async {
						self.hud(show: false)
						JDStatusBarNotification.show(withStatus: "Error sharing video", dismissAfter: 3, styleName: JDStatusBarStyleError)
					}
				}
			}
		} else {
			DispatchQueue.global(qos: .userInitiated).async {
				// make sure we actually have an image we can interact with
				guard let image = mediaCell.messageImage.image else { return }
				let objectsToShare = [image] as [Any]
				let activityVc = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
				activityVc.popoverPresentationController?.sourceView = self.view
				DispatchQueue.main.async {
					self.present(activityVc, animated: true, completion: nil)
				}
			}
			
		}

	}
	
	private func hud(show:Bool) {
		if show {
			self.saveHud = MBProgressHUD.showAdded(to: self.view, animated: true)
			self.saveHud?.mode = .indeterminate
			self.saveHud?.label.text = "Preparing to share..."
		} else {
			MBProgressHUD.hide(for: self.view, animated: true)
		}
	}
	
	/// Displays a little alert to the user letting them know that the copy was completed.
	private func showCopyAlert() {
		// present a new notification only if not already visible, because there may be a more important message displayed already
		if JDStatusBarNotification.isVisible() == false {
			JDStatusBarNotification.show(withStatus: "Copied", dismissAfter: 1.5, styleName: JDStatusBarStyleDefault)
		}
	}
	
	// MARK: - Label Delegate
	
	/// Called when a link was clicked within a message, we can handle it accordingly.
	public func attributedLabel(_ label: TTTAttributedLabel!, didSelectLinkWith url: URL!) {
		
		if url.absoluteString.hasPrefix("mailto:") {
			// The link is an email address, start a compose window
			if MFMailComposeViewController.canSendMail() {
				let mail = MFMailComposeViewController()
				mail.mailComposeDelegate = self
				let index = url.absoluteString.index(url.absoluteString.startIndex, offsetBy: 7)
				mail.setToRecipients([url.absoluteString.substring(from: index)])
				
				self.present(mail, animated: true)
			} else {
				// unable to send email
				displayErrorAlert(title: "Cannot Send Email", message: "Check that you have email setup.")
			}
		} else {
			// This is a normal link, so open it if we can
			if SFSafariViewController.canOpen(url) {
				let svc = SFSafariViewController(url: url)
				self.present(svc, animated: true, completion: nil)
			} else {
				// unable to open the link
				displayErrorAlert(title: "Cannot Open Page", message: "The link is invaild.")
			}
		}
	}
	
	/// Called when a URL is long-pressed.
	/// - note: This is basically the same as invoking the long press guesture recogniser, but will also invoke the functionality here because the touch may be recognised on the link, not on the cell itself.
	public func attributedLabel(_ label: TTTAttributedLabel!, didLongPressLinkWith url: URL!, at point: CGPoint) {
		UIPasteboard.general.string = url.absoluteString
		label.bounce(1, completion: nil)
		showCopyAlert()
	}
	
	// MARK: - Mail Delegate
	
	/// Called when the user dismisses the email window.
	public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
		controller.dismiss(animated: true, completion: nil)
	}
	
	// MARK: - Utility
	
	/// A simple utility function for displaying a UIAlert to the user.
	private func displayErrorAlert(title: String, message: String) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
		let dismiss = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(dismiss)
		self.present(alert, animated: true, completion: nil)
	}
	
}


