//
//  SFSafariViewController+Check.swift
//  Backchat
//
//  Created by Bradley Mackey on 20/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation
import SafariServices

extension SFSafariViewController {
	/// ## EXTENSION
	/// Determines whether or not a specifed url can be opened within `SFSafariViewController`.
	/// - parameter url: the url to check
	/// - returns: `true` if the url can be opened
	open class func canOpen(_ url:URL) -> Bool {
		guard let scheme = url.scheme?.lowercased() else { return false }
		return url.host != nil && (scheme == "http" || scheme == "https")
	}
}
