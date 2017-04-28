//
//  BCDemoChatController.swift
//  Backchat
//
//  Created by Bradley Mackey on 30/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit
import SlackTextViewController
import TTTAttributedLabel
import JDStatusBarNotification

final class BCDemoChatController: BCChatController, BCDemoChatManagerDelegate {

	// MARK: - Properties
	
	/// The data manager that handles all message interactions via the delegate.
	/// This property is set upon initialisation to avoid a nasty crash and also due to the fact that it requires no parameters.
	public var chatManager = BCDemoChatManager()
	
	
	// MARK: - Lifecycle
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		// set the chat interface delegate so we know how the tableview should be presented
		chatManager.delegate = self
		
		// Set the title of the controller to be Kevin (and match the behaviour of the regular ChatController)
		setupTitles()
    }
	
	// MARK: View Controller Setup
	
	private func setupTitles() {
		self.title = "Kevin"
		subtitleView.topLabel.text = "Kevin"
		BCDemoChatManager.views += 1
		let currentViews = BCDemoChatManager.views
		switch currentViews {
		case 1:
			subtitleView.bottomLabel.text = "\(BCDemoChatManager.views) view"
		default:
			subtitleView.bottomLabel.text = "\(BCDemoChatManager.views) views"
		}
		subtitleView.bottomLabel.sizeToFit()
		subtitleView.bottomLabel.center = CGPoint(x: 0, y:9)
	}
	
	// MARK: - Data Source
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return chatManager.dataSource.count
	}
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let messageForRow = chatManager.dataSource[indexPath.row]
		// check if this is an image message
		if messageForRow.imageName == "" {
			// regular chat cell
			return chatCell(for: indexPath, messageForRow: messageForRow)
		} else {
			// image chat cell
			return imageCell(for: indexPath, messageForRow: messageForRow)
		}
	}
	
	private func chatCell(for indexPath:IndexPath, messageForRow:BCDemoChatMessage) -> BCChatCell {
		let cell = self.tableView.dequeueReusableCell(withIdentifier: BCChatCell.id) as! BCChatCell
		cell.messageLabel.delegate = self
		if messageForRow.username.characters.count > 1 {
			cell.usernameLabel.text = messageForRow.username
			cell.usernameLabel.textColor = BCColourLetter.colourFromLetter(letter: messageForRow.colourLetter)
			cell.timestampLabel.text = Date().offsetFrom(messageForRow.timestamp)
			cell.messageLabel.text = messageForRow.message
			cell.emojiLabel.text = messageForRow.emoji
		}
		cell.transform = self.tableView.transform
		return cell
	}
	
	private func imageCell(for indexPath:IndexPath, messageForRow:BCDemoChatMessage) -> BCMediaCell {
		let cell = self.tableView.dequeueReusableCell(withIdentifier: BCMediaCell.id) as! BCMediaCell
		if messageForRow.username.characters.count > 1 {
			cell.usernameLabel.text = messageForRow.username
			cell.usernameLabel.textColor = BCColourLetter.colourFromLetter(letter: messageForRow.colourLetter)
			cell.timestampLabel.text = Date().offsetFrom(messageForRow.timestamp)
			cell.messageImage.image = UIImage(named: messageForRow.imageName)
			cell.emojiLabel.text = messageForRow.emoji
		}
		cell.transform = self.tableView.transform
		return cell
	}
	
	// MARK: - Actions
	
	/// Deletes Kevin from the User's phone
	@IBAction func deleteButtonPressed(_ sender: UIBarButtonItem) {
		// see prepare for segue for more
		let alert = UIAlertController(title: "Delete Kevin?", message: "This will remove Kevin from the list of your friends.", preferredStyle: .alert)
		let delete = UIAlertAction(title: "Delete", style: .destructive) { alertAction in
			self.performSegue(withIdentifier: "unwindToSearchVC", sender: self)
		}
		let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
		alert.addAction(delete)
		alert.addAction(cancel)
		self.present(alert, animated: true, completion: nil)
	}
	
	/// Action called when the `Send` button was pressed.
	override func didPressRightButton(_ sender: Any!) {
		defer { super.didPressRightButton(sender) }
		guard let text = textView.text else { return }
		let trimmedMessage = text.trimmingCharacters(in: .whitespacesAndNewlines)
		chatManager.sendMessageToChat(trimmedMessage)
	}
	
	// MARK: - BCDemoChatManagerDelegate
	
	/// Indicates that the tableView should reload it's data (because of the initial fetch of the Realm results)
	internal func tableViewShouldReload() {
		tableView.reloadData()
	}
	
	/// Inserts, deletes, updates rows at the correct indices, in order to match that of the demo chat messages in the realm data source.
	internal func rowsToUpdate(insertions: [Int], deletions: [Int], modifications: [Int]) {
		tableView.beginUpdates()
		if tableView.numberOfSections == 0 {
			tableView.insertSections([0], with: .top)
		}
		tableView.insertRows(at: insertions.map { IndexPath(row: $0, section: 0) }, with: .top)
		tableView.deleteRows(at: deletions.map { IndexPath(row: $0, section: 0) }, with: .bottom)
		tableView.reloadRows(at: modifications.map { IndexPath(row: $0, section: 0) }, with: .fade)
		tableView.endUpdates()
	}
	
	/// Called once Kevin has spent all replies
	internal func kevinFinished() {
		let alert = UIAlertController(title: "Kevin's Done!", message: "That's all Kevin has to say. Would you like to delete him now?", preferredStyle: .alert)
		let delete = UIAlertAction(title: "Delete", style: .destructive) { alertAction in
			self.performSegue(withIdentifier: "unwindToSearchVC", sender: self)
		}
		let cancel = UIAlertAction(title: "Keep", style: .cancel) { alertAction in
			BCCurrentUser.wantToKeepKevin = true
			self.resignFirstResponder()
		}
		alert.addAction(delete)
		alert.addAction(cancel)
		self.present(alert, animated: true, completion: nil)
	}
	
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "unwindToSearchVC" {
			let dest = segue.destination as! BCSearchController
			BCCurrentUser.kevinHidden = true
			dest.tableView.reloadData()
		}
    }
	
}
