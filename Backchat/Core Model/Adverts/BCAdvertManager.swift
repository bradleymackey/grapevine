//
//  BCAdvertManager.swift
//  Backchat
//
//  Created by Bradley Mackey on 20/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase

final public class BCAdvertManager {
	
	let remoteConfig:FIRRemoteConfig
	var adsEnabled:Bool {
		return remoteConfig.configValue(forKey: "enable_ads").boolValue
	}
	
	static let shared = BCAdvertManager()
	private init() {
		remoteConfig = FIRRemoteConfig.remoteConfig()
		//remoteConfig.configSettings = FIRRemoteConfigSettings(developerModeEnabled: true)!
		remoteConfig.setDefaults(["enable_ads":false as NSObject])
		updateAdsEnabled()
	}
	
	func updateAdsEnabled() {
		remoteConfig.fetch(withExpirationDuration: 43200) { (status, error) in
			if let err = error {
				FIRCrashMessage("error getting remote config values: \(err.localizedDescription)")
			} else {
				print("got config values with status: \(status)")
				self.remoteConfig.activateFetched()
			}
		}
	}

}
