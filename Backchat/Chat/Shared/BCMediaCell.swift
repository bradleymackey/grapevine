//
//  BCMediaCell.swift
//  Backchat
//
//  Created by Bradley Mackey on 14/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import UIKit
import AVFoundation
import Firebase // analytics/crash

/// # BCMediaCell
/// The cell that displays a photo message inside a chat.
final public class BCMediaCell: UITableViewCell {
	
	// MARK: - Statics
	
	static let id = "BCMediaCell"
	
	/// the current cell that is playing audio
	static weak var currentAudioCell:BCMediaCell?
	
	// MARK: - Properties
	
	@IBOutlet weak var usernameLabel: UILabel!
	@IBOutlet weak var messageImage: UIImageView!
	
	@IBOutlet weak var timestampLabel: UILabel!
	@IBOutlet weak var emojiLabel: UILabel!
	
	@IBOutlet weak var muteIndicator: UIImageView!
	var message:BCFirebaseChatMessage? // so we can access message data (WE USE THIS FOR BLOCKING/POST REMOVAL)
	var flagReportOnlyInfo:(key:String,uid:String,content:String)? // the key of the message, so that we can flag bad messages (seperate from the message property so we know if we have more privilages)
	
	
	/// The play button, used for starting a video playing AND for muting and unmuting a video
	@IBOutlet weak var playButton: UIButton! {
		didSet {
			// hide play button if there is no video URL
			playButton.isHidden = videoURL == nil
		}
	}
	
	/// The videoURL for the current MediaCell (if there is one for the media cell)
	public var videoURL:URL? {
		didSet {
			// hide play button if there is no video URL
			playButton.isHidden = videoURL == nil
		}
	}
	
	/// The activity indicator view
	@IBOutlet weak var activityIndicatorView: UIActivityIndicatorView! {
		didSet {
			activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
			activityIndicatorView.hidesWhenStopped = true
		}
	}
	
	/// The layer used to show video on
	private var playerLayer: AVPlayerLayer? {
		didSet {
			playerLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
			playerLayer?.frame = messageImage.bounds
		}
	}
	/// The player used for streaming video
	private var player:AVPlayer? {
		didSet {
			player?.play()
		}
	}
	/// Flag so we know if the the video is currently muted or not
	private var muted = false
	/// token used for monitoring when video playback begins
	private var startPlayingToken:Any?
	
	// MARK: - Lifecycle
	
	override public func awakeFromNib() {
		super.awakeFromNib()
		self.playButton.tintColor = .white
		self.muteIndicator.alpha = 0
	}
	
	deinit {
		// remove any observers on the cell
		NotificationCenter.default.removeObserver(self)
		// pause the AVPlayer as well, just to be sure the audio stops (deinit should end it anyway, but this will expedite the process)
		player?.pause()
		if let token = startPlayingToken {
			player?.removeTimeObserver(token)
		}
	}
	
	override public func prepareForReuse() {
		super.prepareForReuse()
		cleanup()
	}
	
	
	// MARK: - Methods
	
	@IBAction func playButtonPressed(_ sender: UIButton) {
		// handle if we already have a player loaded up to use
		if let p = player {
			// muting a currently playing video
			if !muted && p.rate != 0 { self.set(muted: true); FIRAnalytics.logEvent(withName: "mute_on", parameters: nil) }
			// unmuting a video
			else if muted { self.set(muted: false); FIRAnalytics.logEvent(withName: "mute_off", parameters: nil) }
			// return because we don't want to create the player and player layer again.
			return
		}
		guard let url = videoURL else {
			print("can't play video")
			FIRCrashMessage("can't play video - no video URL")
			return
		}
		print("play button pressed")
		FIRAnalytics.logEvent(withName: "video_play", parameters: nil)
		createNewPlayer(for: url)
	}
	
	private func createNewPlayer(for url:URL) {
		player = AVPlayer(url: url)
		playerLayer = AVPlayerLayer(player: player)
		messageImage.layer.addSublayer(playerLayer!)
		// begin the activity animating, so that it becomes visible
		activityIndicatorView.startAnimating()
		// set this cell as not muted
		self.set(muted: false)
		// set the play button to `clear` so it is invisible, but still clickable
		playButton.tintColor = .clear
		NotificationCenter.default.addObserver(self, selector: #selector(BCMediaCell.videoEnded(_:)), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: player!.currentItem)
		startPlayingToken = player?.addBoundaryTimeObserver(forTimes: [NSValue(time: CMTimeMake(1, 60))], queue: nil) {
			[weak self] in
			guard let strongSelf = self else { return }
			strongSelf.activityIndicatorView.stopAnimating()
		}
		FIRAnalytics.logEvent(withName: "load_vid_from_remote", parameters: nil)
	}
	
	/// Sets this cell to be muted or not
	/// - note: this function also handles the muting of any other currently playing cells
	public func set(muted:Bool) {
		setMuteIndicator(muted: muted)
		if !muted && BCMediaCell.currentAudioCell !== self {
			// mute any current cell with audio
			BCMediaCell.currentAudioCell?.set(muted: true)
			// set this as the current audio cell
			BCMediaCell.currentAudioCell = self
		}
		self.muted = muted
		if let p = player {
			p.isMuted = muted
		}
	}
	
	/// Used for displaying the mute indicator when a video is muted/unmuted
	public func setMuteIndicator(muted:Bool) {
		print("setting mute indicator: \(muted)")
		self.muteIndicator.layer.removeAllAnimations()
		let image:UIImage = muted ? UIImage(named: "mute")! : UIImage(named: "sound")!
		self.muteIndicator.image = image
		self.muteIndicator.alpha = 1
		UIView.animate(withDuration: 2.5) {
			self.muteIndicator.alpha = 0
		}
		
	}
	
	/// Called when the video has ended, so we can start playing from the begining
	@objc private func videoEnded(_ notification:Notification) {
		FIRAnalytics.logEvent(withName: "video_loop", parameters: nil)
		guard let p = player else { return }
		p.seek(to: kCMTimeZero)
		p.play()
	}
	
	/// Gets the cell ready for the next use by another cell
	private func cleanup() {
		muted = false
		muteIndicator.image = nil
		self.muteIndicator.alpha = 0
		playButton.tintColor = .white
		activityIndicatorView.stopAnimating()
		player?.pause()
		playerLayer?.removeFromSuperlayer()
		if let token = startPlayingToken {
			player?.removeTimeObserver(token)
		}
		player = nil
		playerLayer = nil
	}
	
}
