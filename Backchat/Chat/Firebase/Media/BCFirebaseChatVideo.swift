//
//  BCFirebaseChatVideo.swift
//  Backchat
//
//  Created by Bradley Mackey on 08/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation
import Firebase
import AVFoundation

public final class BCFirebaseChatVideo: BCFirebaseChatMedia {
	
	// MARK: - Properties
	
	/// The local URL of the video for which we are going to upload.
	public let videoURL:URL
	
	// MARK: - Lifecycle
	
	public init(videoURL:URL, facebookID:String, notificationMetadata:BCPushNotificationMetadata) {
		self.videoURL = videoURL
		super.init(facebookID: facebookID, notificationMetadata: notificationMetadata)
	}
	
	// MARK: - Methods
	
	/// Compresses the video at `videoURL`, then uploads the compressed video.
	/// - parameter error: block to be called if there is an error (_ with:String) provides a reason why
	/// - note: deeper error propgate back up to here
	public func compressAndUpload(error: @escaping (_ with:String) -> Void) {
		
		let asset = AVAsset(url: videoURL)
		guard let clipVideoTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first else {
			FIRCrashMessage("no video track for selected video")
			error("the video"); return
		}
		
		// get the preferred transform of the video clip
		let pt = clipVideoTrack.preferredTransform
		// get the natural size of the clip
		var sizeOfViewer = clipVideoTrack.naturalSize
		// if the clip needs realigning in any way, it means the width and hieght of the renderer should be inverted.
		if (pt.a == -1 || pt.b == -1 || pt.c == -1 || pt.d == -1) && !(pt.a == -1 && pt.d == -1) {
			sizeOfViewer = CGSize(width: clipVideoTrack.naturalSize.height, height: clipVideoTrack.naturalSize.width)
		}
		
		let videoComposition: AVMutableVideoComposition = AVMutableVideoComposition()
		videoComposition.frameDuration = CMTimeMake(1, 30)
		videoComposition.renderSize = sizeOfViewer

	
		let instruction: AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
		instruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMakeWithSeconds(60, 30))
		
		let transformer: AVMutableVideoCompositionLayerInstruction =
			AVMutableVideoCompositionLayerInstruction(assetTrack: clipVideoTrack)
		

		let preffered: CGAffineTransform = clipVideoTrack.preferredTransform // rotates to correct orientation
		transformer.setTransform(preffered, at: kCMTimeZero)
		
		instruction.layerInstructions = [transformer]
		videoComposition.instructions = [instruction]
		
		// save to it's own temp folder with a temp name
		let exportPath: String = NSTemporaryDirectory().appending(UUID().uuidString + ".mp4")
		let exportUrl: URL = URL(fileURLWithPath: exportPath)
		
		guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
			FIRCrashMessage("no video exporter")
			error("video compression"); return
		}
		exporter.videoComposition = videoComposition
		exporter.outputFileType = AVFileTypeQuickTimeMovie
		exporter.outputURL = exportUrl
		exporter.shouldOptimizeForNetworkUse = true
		exporter.exportAsynchronously {
			// upload the compressed video
			if let outputURL = exporter.outputURL {
				print(outputURL)
				self.uploadThumbnailThenVideo(for: outputURL) {
					FIRCrashMessage("no uid to save video to")
					error("authentication")
				}
			} else {
				FIRCrashMessage("no url for compressed video")
				error("video compression. Try a different video")
			}
		}
	}
	

	/// Perform an upload of the video, first generating and uploading a thumbnail.
	/// - parameter url: the local url of the file to upload (compressed video)
	/// - parameter thumbnailError: block called if we are not authenticated (can't get user's uid)
	private func uploadThumbnailThenVideo(for url:URL, thumbnailError: @escaping () -> Void) {
		guard let thumbnail = thumbnailImageForURL(url: url) else {
			uploadVideo(compressedURL: url, thumbnailURL:nil) { thumbnailError() }
			return
		}
		guard let storageRef = firebaseStorageReference else { thumbnailError(); return }
		let fileRef = storageRef.child("thumb").child(UUID().uuidString + ".jpg")
		let thumbnailMetadata = FIRStorageMetadata()
		thumbnailMetadata.contentType = "image/jpeg"
		// assign this to be the upload task, so that it's cancelable, but don't observe how this finishes or progress on this (because it's not the 'real' upload, it's only a thumbnail)
		uploadTask = fileRef.put(thumbnail, metadata: thumbnailMetadata) { [weak self] (metadata, error) in
			guard let strongSelf = self else { return }
			strongSelf.uploadVideo(compressedURL: url, thumbnailURL: metadata?.downloadURL()) {
				thumbnailError()
			}
		}
		// set `self` as the upload in progress for this `facebookID`
		BCFirebaseChatMedia.uploadsInProgress[facebookID] = self
	}

	/// Uploads the video file to Firebase Storage.
	/// - parameter compressedURL: the LOCAL URL of what we want to upload
	/// - parameter thumbnailURL: the EXTERNAL URL of any thumbnail we have already generated and uploaded
	/// - parameter error: block called if we are not authenticated (can't get user's uid)
	private func uploadVideo(compressedURL:URL, thumbnailURL:URL?, error: () -> Void) {
		guard let storageRef = firebaseStorageReference else { error(); return }
		let fileRef = storageRef.child("videos").child(UUID().uuidString + ".mp4")
		let firebaseMetadata = FIRStorageMetadata()
		firebaseMetadata.contentType = "video/mp4"
		// set the upload task so that we can monitor this upload
		uploadTask = fileRef.putFile(compressedURL, metadata: firebaseMetadata) { [weak self] (metadata, error) in
			guard let strongSelf = self else { return }
			// handle the completed upload (method in superclass)
			strongSelf.handleUploadCompletion(metadata: metadata, error: error, thumbnailURL:thumbnailURL, imageOnlyPost:false)
			
			// remove this video from user's filesystem
			strongSelf.deleteVideo(at: compressedURL)
		}
		// monitor the upload status of this upload task
		self.observeUploadStatusForCurrentUploadTask()
		// set `self` as the upload in progress for this `facebookID`
		BCFirebaseChatMedia.uploadsInProgress[facebookID] = self
		// log that the upload has began
		FIRCrashMessage("began video upload")
	}
	
	
	/// - parameter url: the local url of a video file
	/// - returns: a thumbnail image for the given image url
	private func thumbnailImageForURL(url:URL) -> Data? {
		let asset = AVAsset(url: url)
		let imageGenerator = AVAssetImageGenerator(asset: asset)
		do {
			let thumbnailCGImage = try imageGenerator.copyCGImage(at: CMTimeMake(0, 1), actualTime: nil)
			var thumbImage = UIImage(cgImage: thumbnailCGImage)
			if thumbImage.size.width > 1024 {
				let size = CGSize(width: 1024, height: 1024)
				thumbImage = thumbImage.adjustImageSize(newSize: size)
			}
			// jpeg compress the image to further reduce the filesize
			return UIImageJPEGRepresentation(thumbImage, 0.30)
		} catch {
			print(error)
			FIRCrashMessage("thumbnail generation error")
			return nil
		}
	}
	
	/// Removes a video file from the temp directory - to save on file space
	/// - parameter url: the local video url to be deleted
	private func deleteVideo(at url:URL) {
		let fileManager = FileManager.default
		let videoDir = NSTemporaryDirectory().appending(url.lastPathComponent)
		do {
			try fileManager.removeItem(atPath: videoDir)
			print("deleted file at: \(videoDir)")
		} catch {
			print("Could not delete video: \(error)")
		}
	}
	
}
