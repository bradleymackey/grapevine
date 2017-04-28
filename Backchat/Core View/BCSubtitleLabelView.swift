//
//  BCSubtitleLabelView.swift
//  Backchat
//
//  Created by Bradley Mackey on 10/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import UIKit

/// # BCSubtitleLabelView
/// We use this for attaching 2 labels to this `UIView` to easily reference them. For example, we use this class for the title view of the `ChatController` so we can easily update the labels once it is set.
public final class BCSubtitleLabelView: UIView {
    public var topLabel:UILabel!
    public var bottomLabel:UILabel!
	
	init(frame: CGRect, viewWidth:CGFloat) {
		super.init(frame: frame)
		let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: viewWidth-70, height: 20))
		titleLabel.backgroundColor = UIColor.clear
		titleLabel.textColor = .black
		titleLabel.textAlignment = .center
		titleLabel.adjustsFontSizeToFitWidth = true
		titleLabel.minimumScaleFactor = 0.7
		titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
		
		self.topLabel = titleLabel
		
		let viewsLabel = UILabel(frame: .zero)
		viewsLabel.backgroundColor = UIColor.clear
		viewsLabel.textColor = .black
		viewsLabel.font = UIFont.systemFont(ofSize: 11)
		viewsLabel.text = "Loading..."
		viewsLabel.textAlignment = .center
		viewsLabel.sizeToFit()
		self.bottomLabel = viewsLabel
		
		titleLabel.center = CGPoint(x: 0, y: -9)
		viewsLabel.center = CGPoint(x: 0, y:9)
		self.addSubview(titleLabel)
		self.addSubview(viewsLabel)
	}
	
	// this can only be created and called from code now we've added our own init, so crash if we try to storybaord load this.
	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
