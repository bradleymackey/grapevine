//
//  BCFirebaseChatController.swift
//  Backchat
//
//  Created by Bradley Mackey on 30/11/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit
import JDStatusBarNotification
import TTTAttributedLabel
import SlackTextViewController
import SDWebImage
import Firebase
import MBProgressHUD
import AVFoundation

public final class BCFirebaseChatController: BCChatController, FBAdViewDelegate {
    
    // MARK: - STATIC PROPERTIES
	
    /// Maximum number of messages allowed to be stored in the tableView, before we start removing the older messages, 1-by-1.
	public static let maxMessagesInMemory = 100
    
    /// Keeps of track of who user is currently looking at, so we know whether or not to show the notificiation at the top of the screen.
    public static var currentlyViewing:String?
	
	// MARK: INSTANCE PROPERTIES
    
    /// Set by SearchController during segue, so we know who we're looking at.
    public var facebookPersonId:String! {
        willSet { BCFirebaseChatController.currentlyViewing = newValue }
    }
    
    /// Set during segue so we know if this is the current user's chat for their own profile.
    /// - note: Defaults to user category, because most of the time, that will be that case.
    public var chatCategory:BCFirebaseChatCategory = .user
	
    /// The accompanying model class used as a helper for this class to communicate to the database.
	public var chatManager:BCFirebaseChatManager!
	
	/// Contains all the messages.
	public var dataSource = [BCFirebaseChatMessage]()
	
	/// The indicator that displays when we are uploading an image, so we can show user's progress
	public var hud:MBProgressHUD!
	
	/// The current media being uploaded. exists just so that we know what to cancel if the user shakes, all other interesting events should be passed through the delegate `BCFirebaseChatMediaUploadStatusDelegate`
	public var mediaUploadInProgress:BCFirebaseChatMedia?
	
	/// When the initial fetching from firebase has completed (when we update the view count for the first time) so we know to allow user interaction with the chat
	public var initialLoadingCompleted = false {
		willSet {
			if newValue == true {
				self.textInputbar.isUserInteractionEnabled = true
				self.textView.placeholder = "Type a message..."
				self.loadingIndicator.stopAnimating()
			}
		}
	}
	
	/// Timer for displaying a no internet alert after a delay if a user has connection to the Database.
	private var noInternetTimer:Timer!
	
	/// Displays until we can load the initial data from firebase - so the user knows that something is loading.
	var loadingIndicator = UIActivityIndicatorView()

    // MARK: - LIFECYCLE
	
    override public func viewDidLoad() {
		super.viewDidLoad()
		
		BCAdvertManager.shared.updateAdsEnabled()
		if BCAdvertManager.shared.adsEnabled {
			BCAdvert.shared.adView.delegate = self
			// place the ad at the top of the view
			BCAdvert.shared.adView.center = CGPoint(x: self.view.center.x, y: 20+self.navigationController!.navigationBar.frame.size.height+(BCAdvert.shared.adView.frame.height/2))
			self.view.addSubview(BCAdvert.shared.adView)
		}
		
		setupLoadingIndicator()
		
		// set the chatObserver
		chatManager = BCFirebaseChatManager(facebookID: facebookPersonId, getLast: 25, chatCategory: chatCategory)
		chatManager.delegate = self

        // setup the view
		setupTitles()
		setupPictureSendButton()
		
		// check for existing upload tasks
		if let task = BCFirebaseChatMedia.uploadsInProgress[facebookPersonId] {
			// add the delegate and progress indicator to this upload
			task.delegate = self
			showProgressHUD()
			if let taskProgress = task.currentUploadProgress {
				hud.progress = Float(taskProgress.fractionCompleted)
			}
			// set the upload task, so we know what to cancel if the user shakes
			mediaUploadInProgress = task
		}
		
		// set the text input bar as initally loading, so not user interactive
		self.textInputbar.isUserInteractionEnabled = false
		self.textView.placeholder = "Loading..."
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
		// set who we are currently viewing, so we know whether to ignore the notifications or not
        if let id = facebookPersonId {
            BCFirebaseChatController.currentlyViewing = id
        }
		// restart the update timer (because we stopped it in viewDidDisappear).
		chatManager.restartUpdateTimer()
    }
	
	override public func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		self.resignFirstResponder()
		// set all notifications equal to 0, if and set the user we are viewing as a recent user
		if let currentUser = BCSearchDataManager.shared.currentUser {
			// set this data if they are the current user
			if currentUser.facebookID == facebookPersonId {
				BCCurrentUser.isRecent = true
				BCCurrentUser.searchDate = Date()
				BCCurrentUser.currentNotifications = 0
			}
		}
		// remove notifications and set this user as recent
		BCSearchDataManager.shared.makeUserRecentAndRemoveNotifications(facebookID: facebookPersonId)
		// prepare for reuse if the cell will disappear (stops video from playing)
		self.tableView.visibleCells.forEach {
			$0.prepareForReuse()
		}
	}
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
		// set we are not viewing anyone
        BCFirebaseChatController.currentlyViewing = nil
		noInternetTimer?.invalidate()
		chatManager.stopUpdateTimer()
		// set the typing indicator to false when we leave the view
		chatManager.typingStatus = false
    }
	
	override public func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		// start the timer - if the user has no internet after the period specified, then display the no internet alert.
		noInternetTimer = Timer.scheduledTimer(timeInterval: 7, target: self, selector: #selector(BCFirebaseChatController.postNoInternetAlertIfNeeded), userInfo: nil, repeats: false)
		// check if we have any pending alerts to display
		if let alertStatus = BCFirebaseChatImage.completionResponseForChat[facebookPersonId] {
			handleImageUploadStatus(alertStatus)
		}
	}
	
	override public func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// we've hit memory warning, so clear image memory
		SDImageCache.shared().clearMemory()
	}
	
	deinit {
		if BCAdvertManager.shared.adsEnabled {
			BCAdvert.shared.adView.delegate = nil
		}
	}
	

    // MARK: - SETUP
	
	private func setupLoadingIndicator() {
		// start the loading indicator animating
		loadingIndicator.activityIndicatorViewStyle = .whiteLarge
		loadingIndicator.color = .lightGray
		loadingIndicator.center = self.view.center
		loadingIndicator.startAnimating()
		self.view.addSubview(loadingIndicator)
	}
	
	/// Set the title of the view, from the subtitle view.
	private func setupTitles() {
		if chatCategory == .currentUser {
			subtitleView.topLabel.text = "Me"
		} else {
			subtitleView.topLabel.text = self.title ?? "User"
		}
	}

	/// Adds the picture send button to the text input bar.
	private func setupPictureSendButton() {
		// add the image share button
		self.leftButton.setImage(UIImage(named: "camera"), for: UIControlState())
		self.leftButton.tintColor = UIColor.gray
	}
	
	/// Posts an alert telling the user to check their connection, if they have no connection to the Firebase Database.
	@objc private func postNoInternetAlertIfNeeded() {
		if BCFirebaseDatabase.shared.hasConnectionToRealtimeDatabase == false {
			JDStatusBarNotification.show(withStatus: "Check your connection.", dismissAfter: 3, styleName: JDStatusBarStyleError)
		}
	}
	
    // MARK: - DATA SOURCE

	override public func numberOfSections(in tableView: UITableView) -> Int {
		return 1
    }

	override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
	
	override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let messageForRow = self.dataSource[indexPath.row]
		// display the right type of cell for the right content, display an error cell if there is no content.
		if let chatMessage = messageForRow.message {
			return chatCell(for: messageForRow, messageContent: chatMessage)
		}
		if let mediaLink = messageForRow.imageLink {
			return mediaCell(for: messageForRow, linkContent: mediaLink)
		}
		return noContentCell(for: messageForRow)
	}
	
    /// Returns the time since the message was sent, as a human readable String value.
    private func offsetStringFrom(_ unixTimeMilliseconds:Double) -> String {
        let date = Date(timeIntervalSince1970: unixTimeMilliseconds/1000)
        return Date().offsetFrom(date)
    }
	
	// MARK: - CELLS
	
	private func chatCell(for message:BCFirebaseChatMessage, messageContent:String) -> BCChatCell {
		let cell = self.tableView.dequeueReusableCell(withIdentifier: BCChatCell.id) as! BCChatCell
		cell.usernameLabel.text = message.username
		cell.usernameLabel.textColor = BCColourLetter.colourFromLetter(letter: message.colourLetter)
		cell.timestampLabel.text = Date().offsetFrom(message.timestamp)
		cell.emojiLabel.text = message.emoji
		cell.messageLabel.text = messageContent
		cell.messageLabel.delegate = self
		// only be able to delete messages and block people from the current chat
		switch chatCategory {
		case .currentUser:
			cell.message = message
		case .user:
			break
		}
		if let key = message.firebaseDatabaseKey {
			if let msg = message.message {
				cell.flagReportOnlyInfo = (key, message.uid, msg)
			}
		}
		// Apply the tableView's transform to the cell, as our tableView is inverted.
		cell.transform = self.tableView.transform
		
		return cell
	}
	
	private func mediaCell(for message:BCFirebaseChatMessage, linkContent:URL) -> BCMediaCell {
		let cell = self.tableView.dequeueReusableCell(withIdentifier: BCMediaCell.id) as! BCMediaCell
		cell.usernameLabel.text = message.username
		cell.usernameLabel.textColor = BCColourLetter.colourFromLetter(letter: message.colourLetter)
		cell.timestampLabel.text = Date().offsetFrom(message.timestamp)
		cell.emojiLabel.text = message.emoji
		cell.messageImage.sd_setImage(with: linkContent, placeholderImage: UIImage(named: "image_placeholder")!, options: [.retryFailed], completed: nil)
		cell.messageImage.clipsToBounds = true
		cell.videoURL = message.videoLink
		// only be able to delete messages and block people from the current chat
		switch chatCategory {
		case .currentUser:
			cell.message = message
		case .user:
			break
		}
		if let key = message.firebaseDatabaseKey {
			if let vidLink = message.videoLink {
				cell.flagReportOnlyInfo = (key, message.uid, vidLink.absoluteString)
			} else if let imgLink = message.imageLink {
				cell.flagReportOnlyInfo = (key, message.uid, imgLink.absoluteString)
			}
		}
		// Apply the tableView's transform to the cell, as our tableView is inverted.
		cell.transform = self.tableView.transform
		return cell
	}
	
	/// The cell that is displayed in the unlikley event that a message has no content.
	private func noContentCell(for message:BCFirebaseChatMessage) -> BCNoContentCell {
		let cell = self.tableView.dequeueReusableCell(withIdentifier: BCNoContentCell.id) as! BCNoContentCell
		cell.usernameLabel.text = message.username
		cell.usernameLabel.textColor = BCColourLetter.colourFromLetter(letter: message.colourLetter)
		cell.timestampLabel.text = Date().offsetFrom(message.timestamp)
		cell.emojiLabel.text = message.emoji
		cell.transform = self.tableView.transform
		return cell
	}
	
	
	
	// MARK: - SHAKE TO CANCEL
	
	override public func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
		if event?.subtype == UIEventSubtype.motionShake {
			// device was shaken, should cancel any upload in progress
			guard let uploadTask = mediaUploadInProgress else { return }
			uploadTask.cancelUpload()
			mediaUploadInProgress = nil // remove the reference to upload, deinitalising it
		}
	}

	// MARK: - SENDING BUTTONS
	
	// MARK: MESSAGE SEND
    /// The send button was pressed within a chat, post any relevant message to the database.
	override public func didPressRightButton(_ sender: Any!) {
		defer { super.didPressRightButton(sender) }
		// ensure there is text in the text field
		guard let text = textView.text else { return }
		if text.characters.count <= 0 { return }
		// create + post message on a background thread
		DispatchQueue.global(qos: .userInitiated).async {
			// get the current notification tokens from datasource and post message
			let tokens = BCFirebaseChatController.last10(tokensFor: self.dataSource)
			let trimmedMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
			guard let message = BCFirebaseChatMessage(message: trimmedMessage, imageLink: nil, videoLink: nil, chatCategory: self.chatCategory) else {
				// user has no name in their auth token
				// show alert on the main thread
				DispatchQueue.main.async { self.couldNotPostAlert(reason: "Try logging out and back in again.") }
				return
			}
			let metadata = BCPushNotificationMetadata(otherTokens: tokens, ownerFacebookID: self.facebookPersonId, nameOfChat: self.title, chatCategory: self.chatCategory)
			message.postMessage(facebookID: self.facebookPersonId, notificationMetadata: metadata) {
				// error posting for some reason (likley blocked)
				DispatchQueue.main.async { self.couldNotPostAlert(reason: "You have been blocked by this user.") }
			}
		}
	}
	
	// MARK: IMAGE SELECTION
	/// The camera icon button was pressed.
	override public func didPressLeftButton(_ sender: Any?) {
		defer { super.didPressLeftButton(sender) }
		let actions = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
		// setup the capture button
		let captureMediaTitle = "Take photo or video"
		let camera = UIAlertAction(title: captureMediaTitle, style: .default) { alertAction in
			if self.cameraAuthorised() == false { return }
			self.presentImagePickerWithSettings(for: .camera, title: captureMediaTitle)
		}
		// setup the select button
		let pickMediaTitle = "Select from library"
		let library = UIAlertAction(title: pickMediaTitle, style: .default) { (alertAction) in
			self.presentImagePickerWithSettings(for: .photoLibrary, title: pickMediaTitle)
		}
		let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		// add the buttons to the action sheet
		[camera, library, cancel].forEach { actions.addAction($0) }
		self.present(actions, animated: true, completion: nil)
	}
	
		
	// MARK: Message Token Extraction (posting)
	
	/// Gets the notification tokens from the 10 most recent messages.
	/// - parameter messages: the messages for which we should extract tokens from
	/// - returns: a `Set` of the tokens we should send notifications to.
	public static func last10(tokensFor messages:[BCFirebaseChatMessage]) -> Set<String> {
		var tokens = Set<String>()
		var i = 0
		// only loop through at most 10 messages
		for message in messages {
			i += 1
			if i > 10 { break }
			if let t = message.notificationToken {
				// if the message has a token, insert it. (we don't care if it doesn't)
				tokens.insert(t)
			}
		}
		return tokens
	}
	
	// MARK: - ADVERTS
	
	public func adView(_ adView: FBAdView, didFailWithError error: Error) {
		FIRAnalytics.logEvent(withName: "ad_load_failed", parameters: nil)
	}
	
	public func adViewDidLoad(_ adView: FBAdView) {
		FIRAnalytics.logEvent(withName: "ad_loaded", parameters: nil)
	}
	
	public func adViewDidClick(_ adView: FBAdView) {
		FIRAnalytics.logEvent(withName: "ad_clicked", parameters: nil)
	}
	
	// MARK: - Delete
	
	public override func flagMessage(key: String, uid:String) {
		chatManager.flag(messageFor: key, uid: uid)
	}
	
	public override func deleteMessage(chatMessage:BCFirebaseChatMessage) {
		chatManager.delete(message: chatMessage)
	}
	
	public override func blockUser(chatMessage: BCFirebaseChatMessage) {
		chatManager.block(message: chatMessage)
	}
	
}
