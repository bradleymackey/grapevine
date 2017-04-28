//
//  AppDelegate.swift
//  Backchat
//
//  Created by Bradley Mackey on 30/11/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

// A lot of imports!
import UIKit
import Firebase
import FacebookLogin
import FBSDKCoreKit
import RealmSwift
import OneSignal
import JDStatusBarNotification
import AVFoundation
import SDWebImage

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	
	// MARK: - PROPERTIES

	public var window: UIWindow?
	
    /// Used for playing notification sound
    private var player:AVAudioPlayer?
	
	// MARK: - APPLICATION DELEGATE

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		
		// get the latest advert value
		let _ = BCAdvertManager.shared
		
		// setup the audio session
		setupAudioSession()
		// setup all the Firebase components
		initalizeFirebase()
		// setup Facebook
		FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
		// configure our realm (schema version etc)
		configureRealm()
		
		// change the default style of the JDStatusBarNotification, so that the text is more readable
		JDStatusBarNotification.setDefaultStyle { (style) -> JDStatusBarStyle? in
			// main properties
            style?.font = UIFont.boldSystemFont(ofSize: 12)
			style?.textColor = .white
			style?.barColor = UIColor(colorLiteralRed: 0, green: 0.5, blue: 1, alpha: 1)
			return style
		}
		// setup our OneSignal notifications component
		initalizeNotifications(launchOptions: launchOptions)
		// setup SBWebImage
		setupSDWebImage()
		
		// clean temp directory
		DispatchQueue.global(qos: .background).async {
			self.cleanTempDirectory()
		}
		
		// setup our analytics user property
		// TODO: Change when in production
		FIRAnalytics.setUserPropertyString("production", forName: "environment")
		
		return true
	}
	
	// Required by Facebook so that the app can reopen once authenticated
	func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
		
		let handled = FBSDKApplicationDelegate.sharedInstance().application(app, open: url, sourceApplication: options[UIApplicationOpenURLOptionsKey.sourceApplication] as! String!, annotation: options[UIApplicationOpenURLOptionsKey.annotation])
		
		return handled
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
		
		// This calls viewWillDisappear on the active ViewController when the home button is pressed
		window?.rootViewController?.beginAppearanceTransition(false, animated: false)
		window?.rootViewController?.endAppearanceTransition()
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
		
		// This calls viewWillAppear on the active ViewController when the home button is pressed
		window?.rootViewController?.beginAppearanceTransition(true, animated: false)
		window?.rootViewController?.endAppearanceTransition()
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}
	
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		// here we set the badge on each user's name to let them know how many notifications they have missed from each user - only works if background app refresh is on
		guard let info = userInfo as? [String:Any] else {
			completionHandler(.failed); return
		}
		guard let custom = info["custom"] as? [String : Any] else {
			completionHandler(.failed); return
		}
		guard let payload = custom["a"] as? [String:Any] else {
			completionHandler(.noData); return
		}
		guard let id = payload["id"] as? String else {
			completionHandler(.noData); return
		}
		// if we are currently viewing the user for which the notification came in, don't increment the counter.
		if let viewing = BCFirebaseChatController.currentlyViewing {
			if viewing == id { completionHandler(.noData); return }
		}
		if let userID = FIRAuth.auth()?.currentUser?.providerData.first?.uid, userID == id {
			BCCurrentUser.currentNotifications += 1
			// post notification for this update, since the current user is not in realm and we can't auto update this
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: "currentUserNeedsUpdate"), object: nil)
		} else {
			let realm = try! Realm()
			guard let user = realm.object(ofType: BCUser.self, forPrimaryKey: id) else {
				completionHandler(.failed); return
			}
			try! realm.write {
				user.notifications += 1
				realm.add(user, update: true)
			}
		}
		completionHandler(.newData)
	}
	
	// MARK: - CUSTOM INITALIZATION
	
	/// Sets up the audio session so that the correct sound plays.
	private func setupAudioSession() {
		// Set so app can play audio in silent mode and also mixes with audio from other sources (playing music)
		do {
			try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
		} catch {
			// This is not too bad, it'll just affect the user's audio experience slightly.
			FIRCrashMessage("Couldn't set AVAudioSessionCategoryAmbient")
		}
	}
	
	private func initalizeFirebase() {
		// configure Firebase for the app
		FIRApp.configure()
		// begin to monitor info about the realtime database (connection status)
		let _ = BCFirebaseDatabase.shared
	}
	
	private func configureRealm() {
		let config = Realm.Configuration(schemaVersion: 13, migrationBlock: { migration, oldSchemaVersion in
			if (oldSchemaVersion < 13) {
				// Nothing to do!
				// Realm will automatically detect new properties and removed properties
				// And will update the schema on disk automatically
			}
		})
		
		// Tell Realm to use this new configuration object for the default Realm
		Realm.Configuration.defaultConfiguration = config
		
		// Now that we've told Realm how to handle the schema change, opening the file
		// will automatically perform the migration
		let _ = try! Realm()
	}
	
	private func initalizeNotifications(launchOptions: [UIApplicationLaunchOptionsKey: Any]?) {
		// init the push notification module
		OneSignal.initWithLaunchOptions(launchOptions, appId: "retracted", handleNotificationReceived: { (notification) in
			// display a JDStatusBarNotification if notification recieved whilst inside the app
			guard let not = notification else { return }
			guard let title = not.payload.title else { return }
			guard let idPayload = not.payload.additionalData["id"] as? String else { return }
			// if the user is currently viewing that user, don't show a notification
			if let viewing = BCFirebaseChatController.currentlyViewing {
				if viewing == idPayload { return }
			}
			JDStatusBarNotification.show(withStatus: title,
			                             dismissAfter: 3,
			                             styleName: JDStatusBarStyleDefault)
			self.playNotificationSound() // play the alert sound for notifications
		}, handleNotificationAction: { (notificationOpenedResult) in
			// Handle the opening of a notification
			guard let data = notificationOpenedResult?.notification.payload?.additionalData else { return }
			// post notification so that we can open the chat for which the notification is about.
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: "pushNotification"), object: nil, userInfo: data)
		}, settings: [kOSSettingsKeyAutoPrompt:false, // we handle this ourself with the notification prompt
			kOSSettingsKeyInAppAlerts:false, // we handle this ourself via JDStatusBarNotification
			kOSSettingsKeyInFocusDisplayOption: OSNotificationDisplayType.none.rawValue])
	}
	
	private func playNotificationSound() {
		guard let url = Bundle.main.url(forResource: "pop", withExtension: "caf") else { return }
		do {
			player = try AVAudioPlayer(contentsOf: url)
			guard let player = player else { return }
			
			player.prepareToPlay()
			player.play()
		} catch let error {
			FIRCrashMessage("could not play notification sound")
			print(error.localizedDescription)
		}
	}
	
	
	private func setupSDWebImage() {
		// The image disk cache cannot exceed 40MB.
		SDImageCache.shared().config.maxCacheSize = 40_000_000
		SDImageCache.shared().maxMemoryCost = 200_000
		// keep images compressed to save memory
		SDImageCache.shared().config.shouldDecompressImages = false
		SDWebImageDownloader.shared().shouldDecompressImages = false
		// clean expired images from the image cache
		SDImageCache.shared().deleteOldFiles {
			print("SDImageCache: old files cleaned")
		}
	}
	
	/// Cleans up any straggling videos (or other crap in the temporary directory) that may not have been deleted for whatever reason during upload.
	private func cleanTempDirectory() {
		let fileManager = FileManager.default
		let tempFolderPath = NSTemporaryDirectory()
		
		do {
			let filePaths = try fileManager.contentsOfDirectory(atPath: tempFolderPath)
			for filePath in filePaths {
				try fileManager.removeItem(atPath: NSTemporaryDirectory() + filePath)
				print("purged from temp directory: \(filePath)")
			}
		} catch let error as NSError {
			print("Could not clear temp folder: \(error.debugDescription)")
		}
	}

}

