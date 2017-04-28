//
//  FacebookRequest.swift
//  Backchat
//
//  Created by Bradley Mackey on 26/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation
import FacebookCore
import Firebase
import JDStatusBarNotification
import RealmSwift

/// # BCFacebookRequestDelegate
/// Used to notify when the facebook request completed, so any visual stuff can be stopped.
protocol BCFacebookRequestDelegate: class {
    /// Called when a Facebook Graph Request finished for getting data about friends, stop spinners from spinning, for example.
    func facebookFriendRequestDidFinish()
}

/// # BCFacebookRequest
/// Used for loading `BCUser` data from the Facebook Graph API. 
/// - important: we don't use the Graph API for the current users info - we get that from the authentication token from Facebook.
final class BCFacebookRequest {
    
    // MARK: - Lifecycle
    /// The singleton instance used for all Graph API interactions.
    static let shared = BCFacebookRequest()
    private init() {} // because singleton
    
    // MARK: - Properties
    /// `BCFacebookRequestDelegate` instance for notifications
    public weak var delegate:BCFacebookRequestDelegate?
    
    /// Keep track of the date that the friends list was last refreshed, so we know no to make too many Graph API requests.
    private var dateLastRefreshed = Date(timeIntervalSince1970: 0) // init at Epoch 0, so we know the first request will be allowed.
    
    /// Keeps track of whether or not we have loaded new Facebook friend results from the Graph API for the current session
    private var loadedNewFriendsForSession = false
    
    // MARK: - Methods
	 /// Make a request to Facebook to get the current user's friend information IF WE HAVENT ALREADY AUTOMATICALLY FETCHED IT, and then in turn save the new data to disk.
	public func loadFriendsFromFacebookIfNeeded() {
		if (AccessToken.current != nil) && (loadedNewFriendsForSession == false) {
			// make graph request on a background thread
			DispatchQueue.global(qos: .userInitiated).async {
				self.makeGraphRequest(pageURL: nil)
			}
		}
	}
	
    /// Make a request to Facebook to get the current user's friend information, and then in turn save the new data to disk.
    public func reloadFriendsFromFacebook() {
        // Rate limit, 1 request every 2 minutes only
        if Date().timeIntervalSince(dateLastRefreshed) > 120 {
			// make graph request on a background thread
			DispatchQueue.global(qos: .userInitiated).async {
				self.makeGraphRequest(pageURL: nil)
			}
        } else {
            print("not refreshing (time limit not spent)")
            delegate?.facebookFriendRequestDidFinish()
        }
    }
	
	/// Reset all the data for the session - should be called if a user has just logged out.
	public func resetSessionData() {
		loadedNewFriendsForSession = false
		dateLastRefreshed = Date(timeIntervalSince1970: 0)
	}
    
    // MARK: Request
    /// Make a Facebook Graph API request.
    /// - parameter forFriends: whether or not this should get friend information or information about the current user.
    /// - parameter pageURL: the specific URL which the graph request should be run against (see 'IMPORTANT')
    /// - IMPORTANT: for a friend request, this will get 1250 of the user's friends who use Backchat. The `pageURL` parameter is there in case this becomes an issue in the future and need to page across multiple pages of users.
    private func makeGraphRequest(pageURL: String?) {
        // specify facebook graph responce (name, id and limit 1250) for 'me/friends'
        var graphPath = "me/friends?fields=id%2C+name&limit=1250"
        if let gpath = pageURL {
            graphPath = gpath
        }
        
        let connection = GraphRequestConnection()
        connection.add(GraphRequest(graphPath: graphPath,
                                    parameters: ["fields": "id, name"],
                                    accessToken: AccessToken.current,
                                    httpMethod: .GET,
                                    apiVersion: .defaultVersion)) { httpResponse, result in
                                        // Process the result on a background thread
										DispatchQueue.global(qos: .background).async {
											switch result {
											case .success(let response):
												self.graphResponseSuccess(with: response)
												// update the last refreshed time
												self.dateLastRefreshed = Date()
											case .failed(let error):
												self.graphResponseError(with: error)
											}
										}
        }
        connection.start()
    }
	
    /// Called in the event of a successful Graph API response.
    /// - parameter response: the successful response from the API
    /// - parameter forFriends: whether this was a response for the current user's friends or the current user.
    private func graphResponseSuccess(with response:GraphRequest.Response) {
        print(response)
        
        FIRAnalytics.logEvent(withName: "success_facebook_response", parameters: nil)

		// this is a request for Friends
		self.processFriendGraphResponse(response)
		self.loadedNewFriendsForSession = true // set friends as loaded for this session, so we don't make another request.
    }
    
    /// Called in the event of an unsuccessful Graph API response.
    /// - parameter error: the error returned by the unsuccessful response.
    private func graphResponseError(with error:Error) {
        print("Graph Request Failed: \(error)")
		
		// Notify delegate FRIEND response has completed
		self.delegate?.facebookFriendRequestDidFinish()
		
        FIRAnalytics.logEvent(withName: "error_facebook_response", parameters: nil)
        FIRCrashMessage("Couldn't load all friends from Facebook.")
		// display internet error alert on the main thread.
		DispatchQueue.main.async {
			JDStatusBarNotification.show(withStatus: "Friends not updated. Check your connection.", dismissAfter: 2, styleName: JDStatusBarStyleError)
		}
    }
    
    // MARK: Response Processing
    /// Extracts necessary data from the friend Graph response ready for saving to disk.
    /// - parameter response: a responce containing data about the current user's friends
    private func processFriendGraphResponse(_ response:GraphRequest.Response) {
		defer {
			// Notify delegate FRIEND response has completed
			self.delegate?.facebookFriendRequestDidFinish()
		}
        guard let dataDict = response.dictionaryValue else {
            FIRCrashMessage("cannot form dictionary from friend response")
            return
        }
        guard let users:NSArray = dataDict["data"] as? NSArray else {
            FIRCrashMessage("cannot extract friend data from graph response")
            return
        }
        
        // Save the users in this list to disk
        addNewUsersAndRemoveOldUsersFromRealm(users)
        
        // Code for paging.
        // PAGING NOT REQUIRED YET, ONLY IF THERES AN API PROBLEM WITH MASSIVE REQUESTS
        // I JUST GRAB 1250 OF THE USERS FRIENDS. ITS UNLIKLEY THERE WILL BE MUCH MORE THAN THAT.
        //		guard let pagingInfo = dataDict["paging"] as? NSDictionary else { return }
        //		guard let nextPage = pagingInfo["next"] as? String else { return }
        //		makeGraphRequest(forFriends: true, pageURL: pageURL)
        
    }
    
    /// Adds new users and removes old users saved on disk from a given set of users.
    /// - parameter users: the list of users to process
	/// - note: we create the realm instance in here as this is initiated and run on a background thread
    private func addNewUsersAndRemoveOldUsersFromRealm(_ users: NSArray) {
		let realm = try! Realm() // get realm instance
        let currentSession = UUID().uuidString
        realm.beginWrite()

        for user in users {
            guard let userDict = user as? [String:String] else { continue }
            guard let facebookID = userDict["id"] else { continue }
            guard let name = userDict["name"] else { continue }
            let existingUserForID = realm.object(ofType: BCUser.self, forPrimaryKey: facebookID)
			
            if let existing = existingUserForID {
				existing.name = name // as their name may have changed
                existing.sessionTag = currentSession
                realm.add(existing, update: true)
            } else {
                let newUser = BCUser()
                newUser.facebookID = facebookID
                newUser.name = name
                newUser.sessionTag = currentSession
                realm.add(newUser, update: false)
            }
        }

        // remove anyone who wasn't in the graph response (i.e. deleted account)
        let removedUsers = realm.objects(BCUser.self).filter("sessionTag != '\(currentSession)'")
		realm.delete(removedUsers)
		
        try! realm.commitWrite()
		self.delegate?.facebookFriendRequestDidFinish()
    }
}
