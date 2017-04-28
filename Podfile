# Uncomment this line to define a global platform for your project
platform :ios, '9.0'

target 'Backchat' do
  # Comment this line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Backchat

  pod 'Firebase/Core' # core and analytics
  pod 'Firebase/Database' # database for messages
  pod 'Firebase/Auth' # login and authenticate with Firebase
  pod 'Firebase/Crash' # monitor crashes
  pod 'Firebase/Storage' # media upload
  pod 'Firebase/RemoteConfig'
  
  pod 'OneSignal' # for push notifications
  
  pod 'FacebookCore' # facebook graph api
  pod 'FacebookLogin' # facebook authentication
  pod 'FBAudienceNetwork' # facebook ads
  
  pod 'RealmSwift' # for saving the user's facebook friends
  
  pod 'JDStatusBarNotification' # for little bits of info
  pod 'SDWebImage' # for presenting and caching user profile images from Facebook
  pod 'SlackTextViewController' # for the ChatController
  pod 'Locksmith' # for access to the keychain
  pod 'TTTAttributedLabel' # for having links enabled in labels
  pod 'MBProgressHUD' # progress of image uploads
  
  pod 'CryptoSwift' # for the encryption of reports


#  target 'BackchatTests' do
#    inherit! :search_paths
#    # Pods for testing
#  end
#
#  target 'BackchatUITests' do
#    inherit! :search_paths
#    # Pods for testing
#  end

end

post_install do |installer|
	installer.pods_project.targets.each do |target|
		target.build_configurations.each do |config|
			config.build_settings['SWIFT_VERSION'] = '3.0'
		end
	end
end
