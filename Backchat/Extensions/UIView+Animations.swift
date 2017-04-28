//
//  UIView+Animations.swift
//  Backchat
//
//  Created by Bradley Mackey on 07/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
	func bounce(_ times:Int, completion: (()->Void)?) {
		CATransaction.begin()
		CATransaction.setCompletionBlock(completion)
		let animation = CABasicAnimation(keyPath: "transform.scale")
		animation.duration = 0.06 // how long the animation will take
		animation.repeatCount = Float(times)
		animation.autoreverses = true // so it auto returns to 0 offset
		animation.fromValue = 1
		animation.toValue = 1.05
		layer.add(animation, forKey: "transform.scale")
		CATransaction.commit()
	}
	
	func colourFlashAnimation(to colour:UIColor, duration:CFTimeInterval) {
		layer.removeAllAnimations()
		let animation = CABasicAnimation(keyPath: "backgroundColor")
		animation.duration = duration
		animation.autoreverses = true
		animation.fromValue = layer.backgroundColor
		animation.toValue = colour.cgColor
		layer.add(animation, forKey: "backgroundColor")
	}
}

