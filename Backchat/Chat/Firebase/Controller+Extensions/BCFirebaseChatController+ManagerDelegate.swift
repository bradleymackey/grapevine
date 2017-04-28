//
//  BCFirebaseChatController+ManagerDelegate.swift
//  Backchat
//
//  Created by Bradley Mackey on 23/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

extension BCFirebaseChatController: BCFirebaseChatManagerDelegate {
	
	// MARK: Messages
	
	/// A message has been added to the chat. Insert this at index 0 in the `dataSource` (because of inverted tableView)
	/// - parameter message: the message to be added.
	/// - note: may be called from a background thread
	public func childAdded(message: BCFirebaseChatMessage) {
		// append the new message at the front of the dataSource. (as our tableView is reversed)
		self.dataSource.insert(message, at: 0)
		let newCount = self.dataSource.count
		
		// update the table with the new cell, removing excess cells as required by memory
		self.tableView.beginUpdates()
		// if the number of messages if greater than a specified amount, remove the oldest messages, one-by-one
		if newCount > BCFirebaseChatController.maxMessagesInMemory {
			self.dataSource.remove(at: BCFirebaseChatController.maxMessagesInMemory-1)
			let ipDelete = IndexPath(row: BCFirebaseChatController.maxMessagesInMemory-1, section: 0)
			self.tableView.deleteRows(at: [ipDelete], with: .left)
		}
		let indexPathForInsertion = IndexPath(row: 0, section: 0)
		if self.tableView.numberOfSections == 0 {
			self.tableView.insertSections([0], with: .top)
			
		}
		self.tableView.insertRows(at: [indexPathForInsertion], with: .top)
		self.tableView.endUpdates()
	}
	
	/// User lost permission for chat. Let them know with an alert.
	public func lostPermissionForChat() {
		let alert = UIAlertController(title: "Blocked", message: "You have been blocked by this user.", preferredStyle: .alert)
		let dismiss = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(dismiss)
		self.present(alert, animated: true, completion: nil)
	}
	
	/// Called if we could not delete a message for some reason.
	public func couldNotDeleteMessage(reason:String) {
		let alert = UIAlertController(title: "Could not delete", message: reason, preferredStyle: .alert)
		let dismiss = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(dismiss)
		self.present(alert, animated: true, completion: nil)
	}
	
	public func removeMessageFromView(message: BCFirebaseChatMessage) {
		// dispatch this block on a background thread
		DispatchQueue.global(qos: .userInteractive).async {
			// remove this message from the data source
			self.dataSource = self.dataSource.filter { return $0 != message }
			// reload the table on the main thread
			DispatchQueue.main.async { self.tableView.reloadData() }
		}
	}
	
	
	// MARK: View Counter
	
	/// The number of views on this profile has changed. Update the label in the title to the new value.
	public func viewConuterChange(views: Int) {
		// initial loading completed
		initialLoadingCompleted = true
		// ensure there is a bottom label in the subtitle view
		guard let bottomLabel = subtitleView.bottomLabel else { return }
		switch views {
		case 1:
			bottomLabel.text = "1 view"
		default:
			bottomLabel.text = "\(views) views"
		}
		bottomLabel.sizeToFit()
		bottomLabel.center = CGPoint(x: 0, y:9)
		bottomLabel.bounce(1, completion: nil)
	}
	
	// MARK: Typing
	
	/// Called when the typing indicator should be shown or hidden.
	public func otherUsersAre(typing: Bool) {
		if typing {
			// notified of somebody typing, so add the indicator
			self.typingIndicatorView?.insertUsername("Someone")
		} else {
			// there is no more typing, so remove the indicator
			self.typingIndicatorView?.dismissIndicator()
			self.typingIndicatorView?.removeUsername("Someone")
		}
	}
	
	// MARK: Blocking
	
	public func userBlockFinished(success: Bool, reason:String) {
		let title = success ? "User blocked" : "Could not block user"
		let alert = UIAlertController(title: title, message: reason, preferredStyle: .alert)
		let dismiss = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(dismiss)
		DispatchQueue.main.async {
			self.present(alert, animated: true, completion: nil)
		}
	}
	
	public func messageFlagFinished(success: Bool, reason: String?) {
		let title = success ? "Message Flagged" : "Message Not Flagged"
		let alert = UIAlertController(title: title, message: reason, preferredStyle: .alert)
		let dismiss = UIAlertAction(title: "Dismiss", style: .cancel, handler: nil)
		alert.addAction(dismiss)
		DispatchQueue.main.async {
			self.present(alert, animated: true, completion: nil)
		}
	}
	
}
