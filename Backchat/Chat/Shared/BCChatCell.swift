//
//  BCChatCell.swift
//  Backchat
//
//  Created by Bradley Mackey on 06/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit
import TTTAttributedLabel
import JDStatusBarNotification


/// # BCChatCell
/// The cell that displays a text chat message inside a chat.
final public class BCChatCell: UITableViewCell {
	
	static let id = "BCChatCell"
	
	@IBOutlet weak var usernameLabel: UILabel!
	@IBOutlet weak var messageLabel: TTTAttributedLabel!
	@IBOutlet weak var timestampLabel: UILabel!
	@IBOutlet weak var emojiLabel: UILabel!
	var message:BCFirebaseChatMessage? // so we can access message data (WE USE THIS FOR BLOCKING/POST REMOVAL)
	var flagReportOnlyInfo:(key:String,uid:String,content:String)? // the key of the message, so that we can flag bad messages (seperate from the message property so we know if we have more privilages)

    override public func awakeFromNib() {
        super.awakeFromNib()
        setupLinkAttributesForMessageLabel()
    }
	
	/// Sets the attributes for identiofied links, emails etc found within `messageLabel.text`
	private func setupLinkAttributesForMessageLabel() {
		// set link attributes in here (it's view code after all) - they dont always appear if they are set in cellForRow
		messageLabel.linkAttributes = [kCTForegroundColorAttributeName as AnyHashable: UIColor(red: 0.203, green: 0.329, blue: 0.835, alpha: 1)]
		messageLabel.activeLinkAttributes = [kCTForegroundColorAttributeName as AnyHashable : UIColor.black ]
		messageLabel.enabledTextCheckingTypes = NSTextCheckingResult.CheckingType.link.rawValue
	}
}
