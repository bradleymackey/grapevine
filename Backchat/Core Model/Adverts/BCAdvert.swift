//
//  BCAdvert.swift
//  Backchat
//
//  Created by Bradley Mackey on 20/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation

final class BCAdvert {
	
	/// Add this as a subview to see the ads
	public var adView:FBAdView
	
	static let shared = BCAdvert()
	private init() {
		self.adView = FBAdView(placementID: "1626049131032496_1626345504336192", adSize: kFBAdSize320x50, rootViewController: nil)
		self.adView.backgroundColor = .clear
		self.adView.loadAd()
	}

}
