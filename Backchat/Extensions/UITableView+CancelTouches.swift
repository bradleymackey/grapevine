//
//  UITableView+CancelTouches.swift
//  Backchat
//
//  Created by Bradley Mackey on 14/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import UIKit

extension UITableView {
	open override func touchesShouldCancel(in view: UIView) -> Bool {
		// ensures button touches get cancelled when we scroll so the app doesn't appear laggy or non-responsive
		return true
	}
}
