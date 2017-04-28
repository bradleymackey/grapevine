//
//  BCMyInfoCell.swift
//  Backchat
//
//  Created by Bradley Mackey on 03/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit

/// # BCMyInfoCell
/// A cell which displays additional information on the `BCSearchController`, such as the username cell and 'Invite Friends' cell.
public final class BCMyInfoCell: UITableViewCell {
	/// The cell reuse id
	static public let id = "BCMyInfoCell"
	/// The cell title label
	@IBOutlet weak public var titleLabel: UILabel!
}
