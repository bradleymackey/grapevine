//
//  BCFirebaseChatController+PickMedia.swift
//  Backchat
//
//  Created by Bradley Mackey on 23/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import AVFoundation
import Firebase
import MBProgressHUD


extension BCFirebaseChatController: BCFirebaseChatMediaUploadStatusDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	
	
	// MARK: - IMAGE UPLOAD DELEGATE
	
	public func currentUpload(completedStatus: BCMediaUploadStatus) {
		handleImageUploadStatus(completedStatus)
	}
	
	public func currentUpload(progress: Progress) {
		guard let hud = self.hud else { return }
		hud.progressObject = progress
	}
	
	
	/// Creates a `UIImagePickerController` with the default settings used by both the camera and the photo library.
	public func presentImagePickerWithSettings(for source:UIImagePickerControllerSourceType, title:String) {
		if UIImagePickerController.isSourceTypeAvailable(source) == false {
			self.mediaNotAvalibleAlert(title: title.lowercased()); return
		}
		let imagePicker = UIImagePickerController()
		if let types = UIImagePickerController.availableMediaTypes(for: source) {
			imagePicker.mediaTypes = types
		}
		imagePicker.allowsEditing = true
		imagePicker.sourceType = source
		imagePicker.videoMaximumDuration = 15 // maximum 15 second video (save data)
		imagePicker.delegate = self
		self.present(imagePicker, animated: true, completion: nil)
	}
	
	/// Checks if we have permission for the use of the camera before we go ahead and try to use it, displaying an error alert if we cannot launch the camera.
	/// - returns: whether we are authorised or not.
	@discardableResult
	public func cameraAuthorised() -> Bool {
		let cameraAuthStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
		if cameraAuthStatus == .denied || cameraAuthStatus == .restricted {
			cameraNotAuthorised(thingNotAuthorised:"Camera")
			return false
		}
		let microphoneAuthStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
		if microphoneAuthStatus == .denied || microphoneAuthStatus == .restricted  {
			cameraNotAuthorised(thingNotAuthorised:"Microphone")
			return false
		}
		// otherwise we are authorised (or have not yet asked the user)
		return true
	}
	
	
	/// An image was selected by the user to be uploaded. Here we process the said image and package it up for uploading.
	public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		defer { picker.dismiss(animated: true, completion: nil) }
		// process the selected media on a background thread.
		DispatchQueue.global(qos: .userInitiated).async {
			if let croppedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
				// selected an image
				self.beginUploadOf(image: croppedImage)
			} else if let videoURL = info[UIImagePickerControllerMediaURL] as? URL {
				// selected a video
				self.beginUploadOf(video: videoURL)
			} else {
				// display error alert on the main queue
				DispatchQueue.main.async {
					self.mediaErrorAlert("🐹", resolve: "The media you selected is invalid.")
				}
			}
		}
	}
	
	/// Handles the uploading of an image and all the associated metadata (also showing the progress indicator).
	public func beginUploadOf(image:UIImage) {
		FIRAnalytics.logEvent(withName: "begin_image_upload", parameters: nil)
		// get the notification tokens of other users in the chat who should be notified
		let tokens = BCFirebaseChatController.last10(tokensFor: self.dataSource)
		let notificationMetadata = BCPushNotificationMetadata(otherTokens: tokens, ownerFacebookID: self.facebookPersonId, nameOfChat: self.title, chatCategory: self.chatCategory)
		// create the chat image object ready for upload
		let image = BCFirebaseChatImage(image: image, facebookID: self.facebookPersonId, notificationMetadata: notificationMetadata)
		// set the delegate and begin the upload
		image.delegate = self
		image.compressAndUpload { errorWith in
			DispatchQueue.main.async {
				self.mediaErrorAlert("🐼", resolve: "There was an error with \(errorWith).")
			}
		}
		self.mediaUploadInProgress = image
		// show progress HUD on the main thread
		DispatchQueue.main.async {
			self.showProgressHUD()
		}
	}
	
	/// Gets the selected video ready for upload.
	private func beginUploadOf(video:URL) {
		FIRAnalytics.logEvent(withName: "begin_video_upload", parameters: nil)
		// get the notification tokens of other users in the chat who should be notified
		let tokens = BCFirebaseChatController.last10(tokensFor: self.dataSource)
		let notificationMetadata = BCPushNotificationMetadata(otherTokens: tokens, ownerFacebookID: self.facebookPersonId, nameOfChat: self.title, chatCategory: self.chatCategory)
		// create the chat video object ready for upload
		let video = BCFirebaseChatVideo(videoURL: video, facebookID: self.facebookPersonId, notificationMetadata: notificationMetadata)
		video.delegate = self
		video.compressAndUpload { errorWith in
			DispatchQueue.main.async {
				self.mediaErrorAlert("🐟", resolve: "There was an error with \(errorWith).")
			}
		}
		self.mediaUploadInProgress = video
		// show progress HUD on the main thread
		DispatchQueue.main.async {
			self.showProgressHUD()
		}
	}
	
	/// Shows the upload progress indicator.
	public func showProgressHUD() {
		self.hud = MBProgressHUD.showAdded(to: self.view, animated: true)
		self.hud.mode = .annularDeterminate
		self.hud.label.text = "Uploading..."
		self.hud.detailsLabel.text = "Shake to Cancel"
	}
	
	
	// MARK: POSTING ERROR ALERTS
	
	/// Called when we recieve a response from the image upload task, so we know how to present an error to the user - or no error if the upload succeeded or was manually cancelled.
	/// - parameter status: the status of the completed/failed upload
	public func handleImageUploadStatus(_ status:BCMediaUploadStatus) {
		print("media upload responce: \(status)")
		FIRCrashMessage("media upload responce: \(status)")
		// we have dealt with the responce whilst inside the chat, so remove it, as to not deal with it again.
		BCFirebaseChatImage.completionResponseForChat.removeValue(forKey: facebookPersonId)
		// we can also remove the fact there is an upload ongoing from this view controller (this should remove the final reference to it)
		mediaUploadInProgress = nil
		switch status {
		case .success, .userCancelled:
			break
		case .genericError, .uploadFailure, .databasePostFailure:
			mediaErrorAlert("🐶", resolve: "Make sure you have an internet connection.")
		case .noDownloadURL:
			mediaErrorAlert("🐸")
		case .noAuthTokenName:
			mediaErrorAlert("☔️")
		}
		MBProgressHUD.hide(for: self.view, animated: true)
	}


	
}
