//
//  NoContentCell.swift
//  Backchat
//
//  Created by Bradley Mackey on 26/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import UIKit

/// # NoContentCell
/// The cell that gets displayed if (for some reason) a message has no content
final class BCNoContentCell: UITableViewCell {
	static let id = "BCNoContentCell"
	@IBOutlet weak var usernameLabel: UILabel!
	@IBOutlet weak var timestampLabel: UILabel!
	@IBOutlet weak var emojiLabel: UILabel!
}
