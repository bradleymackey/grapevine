//
//  BCMediaUploadStatus.swift
//  Backchat
//
//  Created by Bradley Mackey on 08/02/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation

/// # BCMediaUploadStatus
/// The possible states an image upload can finish with, so we know what to report to the user when an upload ends.
public enum BCMediaUploadStatus {
	/// The image was succesfully saved to Firebase Storage.
	case success
	/// Just a generic upload error, user likely does not have permission to save to this area in Firebase Storage.
	case genericError
	/// We could not get the download URL for the image from Firebase Storage
	case noDownloadURL
	/// The user did not have their real Facebook name within their auth token, so we can't post.
	/// - note: this should only happen if a user is posting to thier own chat.
	case noAuthTokenName
	/// Upload failed likely due to consistant bad data connection.
	case uploadFailure
	/// Image upload failed at the last minute because we couldn't post to the database, we should delete that image from Firebase Storage.
	case databasePostFailure
	/// If the user shakes to cancel the upload
	case userCancelled
}
