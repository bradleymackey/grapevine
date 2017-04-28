//
//  BCContentCell.swift
//  Backchat
//
//  Created by Bradley Mackey on 30/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit

/// # BCContentCell
/// The used to display a question and answer FAQ cell in the `BCAboutController`.
final class BCContentCell: UITableViewCell {
	static let id = "BCContentCell"
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var bodyLabel: UILabel!
}
