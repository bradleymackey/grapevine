//
//  BCTimeCheck.swift
//  Backchat
//
//  Created by Bradley Mackey on 13/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation

/// # BCTimeCheck
/// A utility class that is used to check whether a user's device time is accurate.
final class BCTimeCheck {
	
	public static let url:URL = URL(string: "https://currentmillis.com/time/minutes-since-unix-epoch.php")!
	
	public static func checkTimeAccuracy(_ completion: @escaping (BCTimeCheckResponse) -> Void) {
		let config = URLSessionConfiguration.default // Session Configuration
		// do not cache responces - we want a fresh value every time
		config.requestCachePolicy = .reloadIgnoringLocalCacheData
		config.urlCache = nil
		let session = URLSession(configuration: config) // Load configuration into Session
		session.dataTask(with: BCTimeCheck.url, completionHandler: {
			(data, response, error) in
			if error != nil { completion(.error); return }
			guard let dat = data else { completion(.error); return }
			guard let dataString = String(data: dat, encoding: .utf8) else { completion(.error); return }
			guard let minutes = TimeInterval(dataString) else  { completion(.error); return }
			let seconds = minutes*60
			print("returned epoch from currentmillis.com -> \(seconds)")
			let currentEpoch = Date().timeIntervalSince1970
			// 20 minute skew from the epoch allowed (in case currentmillis.com is really slow)
			if currentEpoch > (seconds+1200) || currentEpoch < (seconds-1200) {
				completion(.inaccurate)
			} else {
				completion(.accurate)
			}
		}).resume()
	}
	
}
