//
//  String+Encrypt.swift
//  Backchat
//
//  Created by Bradley Mackey on 23/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import CryptoSwift

extension String {
	
	func aesEncrypt(key: String, iv: String) throws -> String {
		let data = self.data(using: .utf8)!
		let encrypted = try! AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).encrypt([UInt8](data))
		let encryptedData = Data(encrypted)
		return encryptedData.base64EncodedString()
	}
	
	func aesDecrypt(key: String, iv: String) throws -> String {
		let data = Data(base64Encoded: self)!
		let decrypted = try! AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).decrypt([UInt8](data))
		let decryptedData = Data(decrypted)
		return String(bytes: decryptedData.bytes, encoding: .utf8) ?? "Could not decrypt"
	}
	
}
