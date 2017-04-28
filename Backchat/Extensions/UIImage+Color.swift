//
//  UIImageView+Color.swift
//  Backchat
//
//  Created by Bradley Mackey on 06/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
	
	/// Creates a UIImage from a given colour.
	/// - parameter color: the color image that we want
	/// - returns: a 1x1 color image or `nil` if it cannot be created (for whatever reason)
	static func fromColor(color: UIColor) -> UIImage? {
		let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
		UIGraphicsBeginImageContext(rect.size)
		let context = UIGraphicsGetCurrentContext()
		guard let confirmedContext = context else { return nil }
		confirmedContext.setFillColor(color.cgColor)
		confirmedContext.fill(rect)
		let img = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		return img
	}
	
	/// Adjusts the size of an image.
	/// - parameter newSize: the new size image you want
	/// - returns: the adjusted image size
	func adjustImageSize(newSize:CGSize) -> UIImage {
		UIGraphicsBeginImageContext(newSize)
		self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
		let newImage = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		if let image = newImage {
			return image
		} else {
			print("image could not be resized, returning full size")
			return self
		}
	}
	
}
