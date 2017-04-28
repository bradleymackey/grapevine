//
//  BCFirebaseChatImage.swift
//  Backchat
//
//  Created by Bradley Mackey on 08/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase

public final class BCFirebaseChatImage: BCFirebaseChatMedia {
	
	// MARK: - Properties
	
	/// The image data for which we are going to upload.
	public let image:UIImage
	
	// MARK: - Lifecycle
	
	public init(image:UIImage, facebookID:String, notificationMetadata:BCPushNotificationMetadata) {
		self.image = image
		super.init(facebookID: facebookID, notificationMetadata: notificationMetadata)
	}
	
	// MARK: - Methods
	
	/// Compresses the given image then starts the upload to Firebase Storage
	/// - parameter error: reports on whether there was a compression error or authentication error with upload ONLY
	/// - important: listen for events in `BCFirebaseChatMediaUploadStatusDelegate` for upload progress/status
	public func compressAndUpload(error: (_ with:String)-> Void) {
		var imageToPost = image
		// adjust the size to be no larger than 1024*1024
		if imageToPost.size.width > 1024 {
			let size = CGSize(width: 1024, height: 1024)
			imageToPost = imageToPost.adjustImageSize(newSize: size)
		}
		// jpeg compress the image to further reduce the filesize
		if let imageData = UIImageJPEGRepresentation(imageToPost, 0.25) {
			self.upload(imageData: imageData) {
				error("authentication")
			}
		} else {
			error("compression")
		}
	}
	
	/// Upload the image to the correct location in Firebase Storage.
	private func upload(imageData:Data, error: () -> Void) {
		// if we cannot get the ref it means we can't get the user's uid (i.e. we are not properly authenticated)
		guard let storageRef = firebaseStorageReference else { error(); return }
		let fileRef = storageRef.child("images").child(UUID().uuidString + ".jpg")
		let firebaseMetadata = FIRStorageMetadata()
		firebaseMetadata.contentType = "image/jpeg"
		// set the upload task and start the upload
		uploadTask = fileRef.put(imageData, metadata: firebaseMetadata) { [weak self] (metadata, error) in
			guard let strongSelf = self else { return }
			// handle the completed upload (method in superclass)
			strongSelf.handleUploadCompletion(metadata: metadata, error: error, thumbnailURL: nil, imageOnlyPost: true)
		}
		// monitor the upload status of this upload task
		self.observeUploadStatusForCurrentUploadTask()
		// set `self` as the upload in progress for this `facebookID`
		BCFirebaseChatMedia.uploadsInProgress[facebookID] = self
		// log that the upload has began
		FIRCrashMessage("began image upload")
	}

	
}
