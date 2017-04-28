//
//  BCSingleCell.swift
//  Backchat
//
//  Created by Bradley Mackey on 24/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit

/// # BCSingleCell
/// The cell used to display a single label cell in the `BCAboutController`
final class BCSingleCell: UITableViewCell {
	static let id = "BCSingleCell"
	@IBOutlet weak var titleLabel: UILabel!
}
