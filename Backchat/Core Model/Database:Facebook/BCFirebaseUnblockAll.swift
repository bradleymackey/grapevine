//
//  BCFirebaseUnblockAll.swift
//  Backchat
//
//  Created by Bradley Mackey on 23/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase

public final class BCFirebaseUnblockAll {
	
	let facebookID:String
	
	public init(facebookID:String) {
		self.facebookID = facebookID
	}
	
	public func unblockAll(completion: @escaping (Bool)-> Void) {
		FIRAnalytics.logEvent(withName: "unblock_all", parameters: nil)
		let id = facebookID + "_" + facebookID.saltedMD5
		let ref = FIRDatabase.database().reference().child("block").child(id)
		ref.removeValue { (error, ref) in
			if let err = error {
				FIRCrashMessage("could not unblock all : \(err)")
				completion(false)
			} else {
				completion(true)
			}
		}
	}
}

