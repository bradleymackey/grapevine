//
//  BCFirebaseChatMedia.swift
//  Backchat
//
//  Created by Bradley Mackey on 24/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase

/// # BCFirebaseChatMediaUploadStatusDelegate
public protocol BCFirebaseChatMediaUploadStatusDelegate:class {
	/// Reports on the progress of the current upload.
	func currentUpload(progress:Progress)
	/// Reports on how the upload completed (did it fail or succeed?)
	func currentUpload(completedStatus:BCMediaUploadStatus)
}

/// # BCFirebaseChatImage
/// Represents a media file that we can upload to Firebase, which will then post once the upload has completed.
/// - note: used for upload only
public class BCFirebaseChatMedia {
	
	// MARK: - Uploads in Progress
	
	/// A dictionary that stores all uploads in progress, so we know whether or not to display the progress indicator when we come back into a chat
	/// - note: in the form [facebookID:BCFirebaseChatMedia]
	public static var uploadsInProgress = [String:BCFirebaseChatMedia]()
	
	/// A dictionary that stores any error messages for errors encountered during upload, so we can present these to the user when they come back into a chat, so they will know what failed.
	/// - note: in the form [facebookID:status]
	public static var completionResponseForChat = [String:BCMediaUploadStatus]()
	
	// MARK: - Properties

	/// The notification metadata associated with this image, which should be used once we post
	public let notificationMetadata:BCPushNotificationMetadata
	
	/// The facebook ID of the chat this image is to be posted in
	public let facebookID:String
	
	/// The reference where the media file should be saved
	public var firebaseStorageReference:FIRStorageReference? {
		if let uid = FIRAuth.auth()?.currentUser?.uid {
			return FIRStorage.storage().reference().child("media/\(uid)")
		} else {
			return nil
		}
	}
	
	/// The delegate to notify `BCFirebaseChatController` of upload events.
	public weak var delegate:BCFirebaseChatMediaUploadStatusDelegate?
	
	/// The image's upload task, so we know what to cancel from the `cancelUpload` function
	public var uploadTask:FIRStorageUploadTask?
	
	/// Flag that we set just after the upload is cancelled, so we know not to trigger the `.failed` snapshot event (because that's what happens when you cancel an upload).
	public var failedBecauseCancelled = false
	
	/// The current progress of this image upload
	public var currentUploadProgress:Progress? {
		didSet {
			guard let prog = currentUploadProgress else { return }
			// notify the delegate of the changed upload progress
			self.delegate?.currentUpload(progress: prog)
		}
	}
	
	// MARK: - Lifecycle
	
	public init(facebookID:String, notificationMetadata:BCPushNotificationMetadata) {
		self.facebookID = facebookID
		self.notificationMetadata = notificationMetadata
	}
	
	deinit {
		// remove any observers that may be left on the uploadTask
		uploadTask?.removeAllObservers()
		print("deinit chat media")
	}
	
	// MARK: - Methods

	/// Called in the upload's completion handler
	public func handleUploadCompletion(metadata:FIRStorageMetadata?,error:Error?,thumbnailURL:URL?,imageOnlyPost:Bool) {
		defer { BCFirebaseChatMedia.uploadsInProgress.removeValue(forKey: facebookID) }
		// if we have cancelled the upload, we don't care what happens in here
		if failedBecauseCancelled { return }
		if let err = error {
			// the upload was not successful, let the user know
			print(err)
			BCFirebaseChatMedia.completionResponseForChat[facebookID] = .genericError
			delegate?.currentUpload(completedStatus: .genericError)
			return
		}
		guard let downloadURL = metadata?.downloadURL() else {
			print("no download url")
			BCFirebaseChatMedia.completionResponseForChat[facebookID] = .noDownloadURL
			delegate?.currentUpload(completedStatus: .noDownloadURL)
			return
		}
		
		// assign the correct link to the correct variable, depending if this is an image or video upload
		let imageLink:URL? = imageOnlyPost ? downloadURL : thumbnailURL
		let videoLink:URL? = imageOnlyPost ? nil : downloadURL

		// once the message is offically uploaded, post the message to Firebase so it will appear in the chat.
		guard let message = BCFirebaseChatMessage(message: nil, imageLink: imageLink, videoLink:videoLink, chatCategory: notificationMetadata.chatCategory) else {
			// the message could not be created, due to the fact the user's auth token does not contain their real Facebook name. (see `BCFirebaseChatMessage.init`) (should only happen if a user is posting to their own chat)
			BCFirebaseChatMedia.completionResponseForChat[facebookID] = .noAuthTokenName
			delegate?.currentUpload(completedStatus: .noAuthTokenName)
			return
		}
		message.postMessage(facebookID: facebookID, notificationMetadata: notificationMetadata) { [weak self] in
			guard let strongSelf = self else { return }
			// error posting for some reason
			BCFirebaseChatMedia.completionResponseForChat[strongSelf.facebookID] = .databasePostFailure
			strongSelf.delegate?.currentUpload(completedStatus: .databasePostFailure)
			
		}
	}
	
	/// Observe the various states that the current upload task may be in so we can report this back to the user.
	public func observeUploadStatusForCurrentUploadTask() {
		guard let task = uploadTask else { fatalError("trying to observe a non-existant task") }
		task.observe(.success) { (snapshot) in
			BCFirebaseChatImage.completionResponseForChat[self.facebookID] = .success
			self.delegate?.currentUpload(completedStatus: .success)
		}
		task.observe(.progress) { (snapshot) in
			guard let prog = snapshot.progress else { return }
			self.currentUploadProgress = prog // update the current progress of the upload
		}
		task.observe(.failure) { (snapshot) in
			if self.failedBecauseCancelled { return }
			FIRCrashMessage("upload failed")
			BCFirebaseChatImage.completionResponseForChat[self.facebookID] = .uploadFailure
			self.delegate?.currentUpload(completedStatus: .uploadFailure)
		}
	}
	
	public func cancelUpload() {
		guard let task = uploadTask else {
			print("there is no upload task to cancel")
			FIRCrashMessage("trying to cancel upload that does not exist")
			return
		}
		failedBecauseCancelled = true // set the cancelled flag equal to true, we don't want to display an error message for this.
		task.cancel()
		self.delegate?.currentUpload(completedStatus: .userCancelled)
		BCFirebaseChatMedia.uploadsInProgress.removeValue(forKey: facebookID)
	}
}
