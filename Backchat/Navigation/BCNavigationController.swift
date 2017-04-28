//
//  NavigationController.swift
//  Backchat
//
//  Created by Bradley Mackey on 30/11/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit
import JDStatusBarNotification

final class BCNavigationController: UINavigationController {

    override func viewDidLoad() {
        super.viewDidLoad()
		configureNavigationBarAppearence()
    }
	
	private func configureNavigationBarAppearence() {
		self.navigationBar.tintColor = .black
		self.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName : UIColor.black]
	}

}
