//
//  String+Hash.swift
//  Backchat
//
//  Created by Bradley Mackey on 05/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

/*
 *	THIS CODE SHOULD NOT EVER BE VIEWED BY ANYONE - DOING SO IS A VIOLATION OF FEDERAL LAW
 *	IT CONTAINS THE SECRET KEY USED FOR HASHING, PROVIDING SECURITY THROUGH OBSCURITY.
 */

import Foundation

extension String {
	
	/// Hashes the given string with a predictable, unchanging salt (so we always get the same hash) a number of times for extra security.
	public var saltedMD5: String {
		var currentString = self
		for _ in 0..<2 {
			var string = "uyW%*dhET7k^" + currentString + "J2b22#uSHJKNqK!81&3Pw01^4" // add some predicatable salt
			currentString = string.MD5
			string = "$ZjH3H4eCt%%4dhiUY" + self + "£juQASr^pplOOuJjnLkQbd$2" // zero-out the string for security
		}
		return currentString
	} 
	
	/// Perform an MD5 hash on the String
	/// - note: will fatal error if we cannot hash
	public var MD5:String {
		guard let messageData = self.data(using:String.Encoding.utf8) else { fatalError("invalid string format, cannot hash") }
		var digestData = Data(count: Int(CC_MD5_DIGEST_LENGTH))
		
		_ = digestData.withUnsafeMutableBytes {digestBytes in
			messageData.withUnsafeBytes {messageBytes in
				CC_MD5(messageBytes, CC_LONG(messageData.count), digestBytes)
			}
		}
		return digestData.map { String(format: "%02hhx", $0) }.joined()
	}
}
