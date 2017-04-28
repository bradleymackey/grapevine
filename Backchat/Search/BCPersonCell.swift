//
//  BCPersonCell.swift
//  Backchat
//
//  Created by Bradley Mackey on 01/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit

/// # BCPersonCell
/// A cell which displays information about users on the `BCSearchController`
public final class BCPersonCell: UITableViewCell {
	
	// MARK: - Properties
	/// The image of the user in the cell.
	@IBOutlet weak public var personImage: UIImageView!
	/// The title label for the user's name.
	@IBOutlet weak public var nameLabel: UILabel!
	/// The info label displaying the last time the user was viewed.
	@IBOutlet weak public var lastViewedLabel: UILabel!
	/// Label for the number of pending notifications for the user.
	@IBOutlet weak public var notificationLabel:UILabel!
	
	/// The cell reuse identifier.
	static public let id = "BCPersonCell"
	
	// MARK: - Methods
	
	/// Setup properties for the `personImage`.
    override public func awakeFromNib() {
        super.awakeFromNib()
		// 70pt height - (2x8pt) margin (top and bottom) = 54, 54/2 = 27
		// settting dynamically causes many issues
		personImage.layer.cornerRadius = 27
		personImage.layer.masksToBounds = true
		personImage.clipsToBounds = true
	}

}
