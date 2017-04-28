//
//  BCSearchController.swift
//  Backchat
//
//  Created by Bradley Mackey on 30/11/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import UIKit
import SDWebImage
import JDStatusBarNotification
import FacebookLogin
import FacebookCore
import Firebase
import RealmSwift

public final class BCSearchController: UITableViewController, UISearchResultsUpdating, UINavigationControllerDelegate, BCSearchDataManagerDelegate {
	
	// MARK: Statics
	
	/// The number of friends that a user requires to start showing the friends in the 'Recently Viewed' section.
	private static let numberOfFriendsRequiredForRecents = 10
	
	// MARK: - Enumerations
	/// Possible segues from `BCSearchController`.
	private enum SegueFromSearch: String {
		case toChat = "moveToChat"
		case toDemoChat = "moveToDemoChat"
		case toUsername = "showUsernameFromSearch"
		case toAbout = "showAbout"
		case toLogin = "presentLoginFlow"
		case toNotification = "moveToNotification"
	}
	
	// MARK: - Properties
	
	/// The searchController (don't get confused with the current class!) used for searching the list of local friends.
	private var searchController = UISearchController(searchResultsController: nil)
	

	/// A temporary storage location while we process the opening of a notification. The `pushRecieved(_:)` passes the data into this dictionary which is then read by `performSegue`.
    private var userInfoForNotification = [AnyHashable:Any]()
	
	/// Where we store the title and the subtitle for the view
	private var subtitleView:BCSubtitleLabelView!
	
	private var countdownUpdateTimer:Timer!
	
	// MARK: - View controller life-cycle
	
    override public func viewDidLoad() {
        super.viewDidLoad()
		
		// observe push notifications here because this controller is always active
        NotificationCenter.default.addObserver(self, selector: #selector(BCSearchController.pushRecieved(_:)), name: NSNotification.Name(rawValue: "pushNotification"), object: nil)

		// Set delegate for FacebookRequest
		BCFacebookRequest.shared.delegate = self
		
		// Set our delegate for the BCSearchDataManagerDelegate, used to manage all the data in this view.
		BCSearchDataManager.shared.delegate = self
		
		// setup some of the visual elements of this ViewController
		setupView()
		
		// setup the search controller for local searches of friends via Realm
		setupSearchController()
		
		// Hides search bar initially under the navigation bar
		let offsetPoint = CGPoint(x: 0, y: self.searchController.searchBar.frame.height)
		self.tableView.setContentOffset(offsetPoint, animated: false)
		
		// if the app isn't authorised already and user not logged in, direct the user to the flow where can authorise with facebook and so we can grab out access token.
		if AccessToken.current == nil || FIRAuth.auth()?.currentUser == nil {
			self.performSegue(withIdentifier: SegueFromSearch.toLogin.rawValue, sender: self)
		} else {
			// begin the database monitoring sign in process. this will be set during login if we already logged in.
			let _ = BCFirebaseDatabase.shared
		}
		
        // Uncomment the following line to preserve selection between presentations
		self.clearsSelectionOnViewWillAppear = true
		
		// start the timer for updating the countdown label
		countdownUpdateTimer?.invalidate()
		countdownUpdateTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(BCSearchController.updateCountdownLabel), userInfo: nil, repeats: true)
    }

	override public func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		if JDStatusBarNotification.isVisible() { JDStatusBarNotification.dismiss() }
		
		// show the notification screen if we have not yet asked - AND the user is logged in
		if BCPushNotification.askedNotifications == false && AccessToken.current != nil {
			BCPushNotification.askedNotifications = true
			self.performSegue(withIdentifier: "moveToNotification", sender: self)
		}
		
		// MARK: Checks for data integreity
		
		// load the list of friends from Facebook if we havent already automatically fetched this (probably a better place for this than viewDidAppear)
		BCFacebookRequest.shared.loadFriendsFromFacebookIfNeeded()
		// set our notification token in firebase if we havent already done so (probably a better place for this than viewDidAppear)
		if let currentUser = BCSearchDataManager.shared.currentUser?.facebookID {
			BCPushNotification.setNotificationTokenInFirebaseForCurrentUserIfPossible(facebookID: currentUser)
		}

	}
	
	override public func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		updateCountdownLabel() // reload the countdown timer
		self.tableView.reloadData() // reload all data in the table
	}
    
    deinit {
		// remove notification center observers
        NotificationCenter.default.removeObserver(self)
		// stop the update timer if we deinit
		countdownUpdateTimer?.invalidate()
		countdownUpdateTimer = nil
    }


	// MARK: - View controller configuration
	
	private func setupView() {
		// Set the navigation bar title and subtitle
		self.title = "Grapevine"
		subtitleView = BCSubtitleLabelView(frame: .zero, viewWidth: self.view.frame.size.width)
		subtitleView.topLabel.text = "Grapevine"
		updateCountdownLabel()
		self.navigationItem.titleView = subtitleView
		
		
		// setup cells
		self.tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
		self.tableView.separatorColor = UIColor(colorLiteralRed: 0.9, green: 0.9, blue: 0.9, alpha: 1)
		self.tableView.tableFooterView = UIView() // hides separator lines for non-existent cells
		
		// add refresh control
		refreshControl?.addTarget(self, action: #selector(BCSearchController.handleRefresh(_:)), for: .valueChanged)
		
	}
	
	/// Updates the time remaining until the next delete of all messages from the app.
	@objc private func updateCountdownLabel() {
		// dispatch on a background thread
		DispatchQueue.global(qos: .userInitiated).async {
			let epochOfNextDelete = TimeInterval((ceil(((Double(Date().timeIntervalSince1970)/60)/60)/24))*24*60*60)
			let dateOfNextDelete = Date(timeIntervalSince1970: epochOfNextDelete)
			let offset = Date().offsetFrom(dateOfNextDelete)
			DispatchQueue.main.async {
				self.subtitleView.bottomLabel.text = "resets " + offset
				self.subtitleView.bottomLabel.sizeToFit()
				self.subtitleView.bottomLabel.center = CGPoint(x: 0, y:9)
			}
		}
	}
    
    fileprivate func setupSearchController() {
        // IMPORTANT for dismissing search bar when going to view chat.
        self.definesPresentationContext = true
        self.extendedLayoutIncludesOpaqueBars = true
        
        // setup the SeachController for searching people in real.
        searchController.searchResultsUpdater = self
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.dimsBackgroundDuringPresentation = false
        self.tableView.tableHeaderView = searchController.searchBar
        searchController.searchBar.sizeToFit()
        searchController.searchBar.placeholder = "Search Friends"
    }

    // MARK: - Table view data source

    override public func numberOfSections(in tableView: UITableView) -> Int {
		if searchController.isActive { return 1 } else { return 4 }
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		
		if searchController.isActive {
			return BCSearchDataManager.shared.filteredPeople?.count ?? 0
		}
		
		// get a TableSection from the section int
		guard let sectionName = BCSearchTableSection(rawValue: section) else { return 0 }
		switch sectionName {
		case .demo:
			if BCCurrentUser.kevinHidden { return 0 } else { return 1 }
		case .me:
            // if a current user exists display 2, otherwise there should be 0
			if let _ = BCSearchDataManager.shared.currentUser { return 2 } else { return 0 }
		case .recents:
			// only display the 5 most recently searched people
			if BCSearchDataManager.shared.allUsers.count < BCSearchController.numberOfFriendsRequiredForRecents { return 0 }
			let recentCount = BCSearchDataManager.shared.recentUsers.count
			if recentCount > 5 { return 5 } else { return recentCount }
		case .all:
			return BCSearchDataManager.shared.allUsers.count + 1
		}
    }
	
	override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		let indexPathForInvite = IndexPath(row: 0, section: BCSearchTableSection.all.rawValue)
		let indexPathForProfile = IndexPath(row: 0, section: BCSearchTableSection.me.rawValue)
		switch indexPath {
		case indexPathForInvite:
			// deselect this row here because it won't deselect automatically on viewWillAppear
			self.tableView.deselectRow(at: indexPath, animated: true)
			inviteFriendsPopup()
			return
		case indexPathForProfile:
			// open the 'My Profile' screen
			self.performSegue(withIdentifier: "showUsernameFromSearch", sender: self)
			return
		default: break
		}
		
		guard let sectionName = BCSearchTableSection(rawValue: indexPath.section) else { fatalError("invaild section") }
		// view kevin only if we're not currently searching (because everything is section 0 if we're searching, the same section number as the demo section) 
		if (sectionName == .demo) && (searchController.isActive == false) {
			self.performSegue(withIdentifier: SegueFromSearch.toDemoChat.rawValue, sender: self)
		} else {
			self.performSegue(withIdentifier: SegueFromSearch.toChat.rawValue, sender: self)
		}
	}

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		// Cell for if we are currently searching
		if searchController.isActive { return cellForSearch(indexPath) }
		// Cell for other sections
		guard let sectionName = BCSearchTableSection(rawValue: indexPath.section) else { fatalError("invaild section") }
		switch sectionName {
		case .demo:
			return cellForDemo(indexPath)
		case .me:
			// the 'Me' cell is only the first cell
			if indexPath.row == 0 {
				return cellForMyInfo(indexPath)
			} else {
				return cellForMe(indexPath)
			}
		case .recents:
			return cellForRecents(indexPath)
		case .all:
			if indexPath.row == 0 {
				return cellForMyInfo(indexPath)
			}
			return cellForAll(indexPath)
			
		}
    }
	
	override public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		// make the 'My info' cells slightly smaller than the people cells.
		if indexPath.section == BCSearchTableSection.me.rawValue && indexPath.row == 0 { return 50 }
		if indexPath.section == BCSearchTableSection.all.rawValue && indexPath.row == 0 { return 50 }
		// People cell height
		return 70
	}
    
    override public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if searchController.isActive { return nil }
        guard let sectionName = BCSearchTableSection(rawValue: section) else { return nil }
        switch sectionName {
        case .demo:
			if BCCurrentUser.kevinHidden {
				return nil
			} else {
				return headerWithTitle("Tap Kevin For Help")
			}
        case .me:
			if let _ = BCSearchDataManager.shared.currentUser {
				return headerWithTitle("Me")
			} else {
				return nil
			}
        case .recents:
			if BCSearchDataManager.shared.allUsers.count < BCSearchController.numberOfFriendsRequiredForRecents { return nil }
			if BCSearchDataManager.shared.recentUsers.count > 0 {
				return headerWithTitle("Recently Viewed")
			} else {
				return nil
			}
        case .all:
			let allFriendsCount = BCSearchDataManager.shared.allUsers.count
			if allFriendsCount == 1 {
				return headerWithTitle("1 Friend")
			} else {
				return headerWithTitle("\(allFriendsCount) Friends")
			}
        }
    }
	
	/// - returns: `UIView` to be used for the header view for the table sections.
    private func headerWithTitle(_ text: String) -> UIView {
        let view = UIVisualEffectView(frame: CGRect(x: 0,
                                        y: 0,
                                        width: self.tableView.frame.width,
                                        height: 22))
        let title = UILabel(frame: view.frame)
        title.text = text
        title.textAlignment = .center
        title.textColor = .black
        title.font = UIFont.boldSystemFont(ofSize: UIFont.smallSystemFontSize)
        title.backgroundColor = .clear
        view.backgroundColor = UIColor(colorLiteralRed: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        view.effect = UIBlurEffect(style: .light)
        view.addSubview(title)
        return view
    }
    
    override public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if searchController.isActive { return 0 } // no header section for the search view
        let height:CGFloat = 22
        guard let sectionName = BCSearchTableSection(rawValue: section) else { return 0 }
        switch sectionName {
        case .demo:
			if BCCurrentUser.kevinHidden { return 0 } else { return height }
        case .me:
			if let _ = BCSearchDataManager.shared.currentUser { return height } else { return 0 }
        case .recents:
			if BCSearchDataManager.shared.allUsers.count < BCSearchController.numberOfFriendsRequiredForRecents { return 0 }
			if BCSearchDataManager.shared.recentUsers.count > 0 { return height } else { return 0 }
        case .all: // this section always has a title
            return height
        }
    }
	
	// MARK: - CELLS 
	
	/// - returns: cell to be used for the demo 'Kevin'
	private func cellForDemo(_ indexPath: IndexPath) -> BCPersonCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: BCPersonCell.id, for: indexPath) as! BCPersonCell
		let demoUser = BCDemoUser()
		cell.personImage.image = demoUser.profilePicture
		cell.nameLabel.text = demoUser.name
		cell.lastViewedLabel.isHidden = true
		cell.notificationLabel.isHidden = true
		return cell
	}
	
	/// - returns: cell to be used for the current user.
	private func cellForMe(_ indexPath: IndexPath) -> BCPersonCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: BCPersonCell.id, for: indexPath) as! BCPersonCell
		if let currentUser = BCSearchDataManager.shared.currentUser {
			cell.personImage.sd_setImage(with: BCUser.getProfilePictureURL(facebookID: currentUser.facebookID),
			                             placeholderImage: UIImage(named: "default"))
			cell.nameLabel.text = currentUser.name
			let nots = BCCurrentUser.currentNotifications
			switch nots {
			case 0:
				cell.notificationLabel.isHidden = true
			default:
				cell.notificationLabel.isHidden = false
				if nots >= 10 {
					cell.notificationLabel.text = "10+ new"
				} else {
					cell.notificationLabel.text = String(nots) + " new"
				}
			}
			if BCCurrentUser.isRecent {
				cell.lastViewedLabel.isHidden = false
				cell.lastViewedLabel.text = "Last viewed \(Date().offsetFrom(BCCurrentUser.searchDate))"
			} else {
				cell.lastViewedLabel.isHidden = true
			}
			return cell
		} else {
			// should never be displayed becuase if there is no currentUser, then we just display 0 cells in the 'me' section.
			FIRCrashMessage("displayed currentUser cell, even though there is no current user :/")
			cell.nameLabel.text = "?"
			cell.personImage.image = UIImage(named: "default")
			cell.lastViewedLabel.isHidden = true
			cell.notificationLabel.isHidden = true
			return cell
		}
	}
	
	/// - returns: cell to be used for users featured in the 'recents' section
	private func cellForRecents(_ indexPath: IndexPath) -> BCPersonCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: BCPersonCell.id, for: indexPath) as! BCPersonCell
		let userForRow = BCSearchDataManager.shared.recentUsers[indexPath.row]
		cell.nameLabel.text = userForRow.name
		cell.personImage.sd_setImage(with: BCUser.getProfilePictureURL(facebookID: userForRow.facebookID),
		                             placeholderImage: UIImage(named: "default"))
		switch userForRow.notifications {
		case 0:
			cell.notificationLabel.isHidden = true
		default:
			cell.notificationLabel.isHidden = false
			if userForRow.notifications >= 10 {
				cell.notificationLabel.text = "10+ new"
			} else {
				cell.notificationLabel.text = String(userForRow.notifications) + " new"
			}
		}
		if userForRow.isRecent {
			cell.lastViewedLabel.isHidden = false
			cell.lastViewedLabel.text = "Last viewed \(Date().offsetFrom(userForRow.searchDate))"
		} else {
			cell.lastViewedLabel.isHidden = true
		}
		return cell
	}
	
	private func cellForAll(_ indexPath: IndexPath) -> BCPersonCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: BCPersonCell.id, for: indexPath) as! BCPersonCell
		let userForRow = BCSearchDataManager.shared.allUsers[indexPath.row-1] //-1 because of permenant invite cell
		cell.nameLabel.text = userForRow.name
		cell.personImage.sd_setImage(with: BCUser.getProfilePictureURL(facebookID: userForRow.facebookID),
		                             placeholderImage: UIImage(named: "default"))
		switch userForRow.notifications {
		case 0:
			cell.notificationLabel.isHidden = true
		default:
			cell.notificationLabel.isHidden = false
			if userForRow.notifications >= 10 {
				cell.notificationLabel.text = "10+ new"
			} else {
				cell.notificationLabel.text = String(userForRow.notifications) + " new"
			}
		}
		if userForRow.isRecent {
			cell.lastViewedLabel.isHidden = false
			cell.lastViewedLabel.text = "Last viewed \(Date().offsetFrom(userForRow.searchDate))"
		} else {
			cell.lastViewedLabel.isHidden = true
		}
		return cell
	}
	
	private func cellForMyInfo(_ indexPath: IndexPath) -> BCMyInfoCell {
		guard let section = BCSearchTableSection(rawValue: indexPath.section) else { fatalError("invalid Section") }
		let cell = tableView.dequeueReusableCell(withIdentifier: BCMyInfoCell.id, for: indexPath) as! BCMyInfoCell
		if section == .me { // the index path for the profile cell (row 1 (in me section))
            let emojiAttributed = NSMutableAttributedString(string: BCCurrentUser.emoji + "  ")
            emojiAttributed.addAttribute(NSForegroundColorAttributeName, value: UIColor.black, range: NSMakeRange(0, emojiAttributed.length))
            let usernameAttributed = NSMutableAttributedString(string: BCCurrentUser.username)
            let userColour = BCColourLetter.colourFromCurrentUserLetter()
            usernameAttributed.addAttribute(NSForegroundColorAttributeName, value: userColour, range: NSMakeRange(0, usernameAttributed.length))
            
            let combined = NSMutableAttributedString()
            combined.append(emojiAttributed)
            combined.append(usernameAttributed)
            cell.titleLabel.attributedText = combined
            cell.titleLabel.adjustsFontSizeToFitWidth = true
            cell.titleLabel.minimumScaleFactor = 0.7
		} else { // the index path for the invite friends (row 0 (in all section))
			cell.titleLabel.text = "✉️  Invite Friends" // 2 spaces inbetween emoji
			cell.titleLabel.textColor = UIColor(red: 0, green: 122/255, blue: 1, alpha: 1)
		}
		return cell
	}
	
	private func cellForSearch(_ indexPath: IndexPath) -> BCPersonCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: BCPersonCell.id, for: indexPath) as! BCPersonCell
		if let searchedUser = BCSearchDataManager.shared.filteredPeople?[indexPath.row] {
			cell.nameLabel.text = searchedUser.name
			cell.personImage.sd_setImage(with: BCUser.getProfilePictureURL(facebookID: searchedUser.facebookID),
			                             placeholderImage: UIImage(named: "default"))
			switch searchedUser.notifications {
			case 0:
				cell.notificationLabel.isHidden = true
			default:
				cell.notificationLabel.isHidden = false
				if searchedUser.notifications > 10 {
					cell.notificationLabel.text = "10+ new"
				} else {
					cell.notificationLabel.text = String(searchedUser.notifications) + " new"
				}
			}
			if searchedUser.isRecent {
				cell.lastViewedLabel.isHidden = false
				cell.lastViewedLabel.text = "Last viewed \(Date().offsetFrom(searchedUser.searchDate))"
			} else {
				cell.lastViewedLabel.isHidden = true
			}
			return cell
		} else {
			// should never be displayed becuase if there is no search, then we will not be displaying this cell anyway.
			FIRCrashMessage("displayed searchCell cell, even though there is no search happening right now :/")
			cell.nameLabel.text = "😕 nobody"
			cell.personImage.image = UIImage(named: "default")
			return cell
		}
	}
	
	// MARK: - SEARCH
	public func updateSearchResults(for searchController: UISearchController) {
		guard let searchBarText = searchController.searchBar.text else { return }
		BCSearchDataManager.shared.searchFor(searchText: searchBarText)
	}

	// MARK: - FACEBOOK QUERY
	@objc private func handleRefresh(_ refreshControl:UIRefreshControl) {
        // Reload the Friend list from the Facebook Graph API
        BCFacebookRequest.shared.reloadFriendsFromFacebook()
	}

    // MARK: - IBActions

	@IBAction func moreButtonPressed(_ sender: UIBarButtonItem) {
		FIRAnalytics.logEvent(withName: "view_about", parameters: nil)
		self.performSegue(withIdentifier: "showAbout", sender: self)
	}
	
	/// Popup that display to invite friends to the app.
	private func inviteFriendsPopup() {
		// dispatch creation on the invite friends popup on a background thread
		DispatchQueue.global(qos: .userInteractive).async {
			let textToShare = "Grapevine - anonymously chat with friends."
			guard let appLink = URL(string: "https://itunes.apple.com/app/id993218034") else { return }
			let objectsToShare = [textToShare, appLink] as [Any]
			let activityVc = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
			activityVc.popoverPresentationController?.sourceView = self.view
			// UI on the main thread
			DispatchQueue.main.async {
				self.present(activityVc, animated: true, completion: nil)
			}
		}
	}
	
	// MARK: - BCSearchDataManagerDelegate
	
	public func tableViewShouldReload() {
		DispatchQueue.main.async {
			self.tableView.reloadData()
		}
	}
	
	/// Only updates rows in the all section when we recieve a notification.
	/// - parameter rows: the rows to update
	public func updateRows(for section:BCSearchTableSection, rows: [Int]) {
		let mapOffset = section == .all ? 1 : 0 // offsets the map if in the 'all' section because of the invite friends cell
		let update = rows.map { IndexPath(row: $0 + mapOffset, section: section.rawValue) }
		self.tableView.beginUpdates()
		self.tableView.reloadRows(at: update, with: .fade)
		self.tableView.endUpdates()
	}
	
//	public func tableViewShouldReloadRecentsSection() {
//		DispatchQueue.main.async {
//			let recentsSection = TableSection.recents.rawValue
//			self.tableView.reloadSections([recentsSection], with: .fade)
//		}
//	}
//	
//	// insert, delete and update the appropraite cells
//	public func tableViewShouldUpdateAll(insertions: [Int], deletions: [Int], updates: [Int]) {
//		// does not apply if we are searching
//		if searchController.isActive { return }
//		
//		let section = TableSection.all.rawValue
//		// Add 1 to all the values, as we have the persistant 'Invite Friends' cell in the search controller, meaning all the indexes should be 1 greater
//		let insertIndecies = insertions.map { IndexPath(row: $0 + 1, section: section) }
//		let deleteIndecies = deletions.map { IndexPath(row: $0 + 1, section: section) }
//		let updateIndecies = updates.map { IndexPath(row: $0 + 1, section: section) }
//		// update the rows in the tableview
//		self.changeRowsFor(insert: insertIndecies, delete: deleteIndecies, update: updateIndecies)
//	}
//
//	
//	/// Performs the physical updates on the rows in the Table.
//	private func changeRowsFor(insert:[IndexPath], delete:[IndexPath], update:[IndexPath]) {
//		self.tableView.beginUpdates()
//		self.tableView.insertRows(at: insert, with: .right)
//		self.tableView.deleteRows(at: delete, with: .left)
//		self.tableView.reloadRows(at: update, with: .none)
//		self.tableView.endUpdates()
//	}
	
    // MARK: - Navigation
	
	// Check if we can perform the segue - only check that if opening a notification that the notification has a payload that we can set the user's facebook ID to.
	public override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
		guard let identifierName = SegueFromSearch(rawValue: identifier) else { return false }
		switch identifierName {
		case .toDemoChat, .toLogin, .toUsername, .toAbout, .toNotification:
			return true
		case .toChat:
			if self.tableView.indexPathForSelectedRow == nil {
				// if this is a notification trying to perform the segue, make sure we have valid info
				if BCSearchDataManager.shared.currentUser == nil { return false }
				if self.userInfoForNotification["name"] as? String == nil { return false }
				if self.userInfoForNotification["id"] as? String == nil { return false }
				return true
			} else {
				return true
			}
		}
	}

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
		
		// set no back button text
		let backItem = UIBarButtonItem()
		backItem.title = ""
		navigationItem.backBarButtonItem = backItem
		
		guard let identifierName = SegueFromSearch(rawValue: segue.identifier!) else { fatalError("invalid segue id") }
		
		switch identifierName {
		case .toDemoChat, .toLogin, .toUsername, .toNotification:
			// no need to prepareForSegue for any of these
			break
        case .toAbout:
            let destination = segue.destination as! BCAboutController
            if let id = BCSearchDataManager.shared.currentUser?.facebookID {
                destination.facebookID = id
            }
		case .toChat:
			// get the destination controller
			let destination = segue.destination as! BCFirebaseChatController
			guard let selectedIndexPath = self.tableView.indexPathForSelectedRow else {
                // this is from a notification (no selected indexPath)
				// use `userInfoForNotification` to get the info we need to segue
                guard let currentUser = BCSearchDataManager.shared.currentUser else { return }
                guard let title = self.userInfoForNotification["name"] as? String else { return }
                guard let id = self.userInfoForNotification["id"] as? String else { return }
                destination.title = title
                destination.facebookPersonId = id
                if id == currentUser.facebookID {
                    destination.chatCategory = .currentUser
                    BCCurrentUser.isRecent = true
                    BCCurrentUser.searchDate = Date()
					BCCurrentUser.currentNotifications = 0
                } else {
                    destination.chatCategory = .user
					BCSearchDataManager.shared.makeUserRecentAndRemoveNotifications(facebookID: id)
                }
                return
            }
			
			if searchController.isActive {
				guard let selectedPerson = BCSearchDataManager.shared.filteredPeople?[selectedIndexPath.row] else { return }
				destination.facebookPersonId = selectedPerson.facebookID
				destination.title = selectedPerson.name
				destination.chatCategory = .user
				BCSearchDataManager.shared.makeUserRecentAndRemoveNotifications(facebookID: selectedPerson.facebookID)
				FIRAnalytics.logEvent(withName: "searched_user", parameters: nil)
				return
			}
			
			guard let sectionName = BCSearchTableSection(rawValue: selectedIndexPath.section) else { fatalError("invaild section") }
			switch sectionName {
			case .demo:
				fatalError("this is not the segue you're looking for - should be performing 'moveToDemoChat'")
			case .me:
				guard let currentUser = BCSearchDataManager.shared.currentUser else { return }
				destination.title = currentUser.name
				destination.facebookPersonId = currentUser.facebookID
				destination.chatCategory = .currentUser // makes sure the user cannot comment on their own profile.
				BCCurrentUser.isRecent = true
				BCCurrentUser.searchDate = Date()
				BCCurrentUser.currentNotifications = 0
			case .recents:
				let selectedUser = BCSearchDataManager.shared.recentUsers[selectedIndexPath.row]
				destination.facebookPersonId = selectedUser.facebookID
				destination.title = selectedUser.name
				destination.chatCategory = .user
				BCSearchDataManager.shared.makeUserRecentAndRemoveNotifications(facebookID: selectedUser.facebookID)
			case .all:
				let selectedUser = BCSearchDataManager.shared.allUsers[selectedIndexPath.row-1] // -1 because of permenant invite cell
				destination.facebookPersonId = selectedUser.facebookID
				destination.title = selectedUser.name
				destination.chatCategory = .user
				BCSearchDataManager.shared.makeUserRecentAndRemoveNotifications(facebookID: selectedUser.facebookID)
			}
		}
    }
	
	@IBAction func unwindToSearchVC(segue: UIStoryboardSegue) { }
    
    // MARK: - Push Notification
	/// Called when the user clicks on a notification, we need to navigate to that view by popping back to the root (this controller) and then segue to the appropriate `ChatController`.
    @objc private func pushRecieved(_ notification:Notification) {
        guard let info = notification.userInfo else { return }
        self.userInfoForNotification = info
        if let indexPath = self.tableView.indexPathForSelectedRow {
            // make sure nothing is selected, so our notification logic will work
             self.tableView.deselectRow(at: indexPath, animated: false)
        }
        guard let navController = self.navigationController else { return }
		// return to the search controller
        navController.popToRootViewController(animated: false)
        // enter the chat
        self.performSegue(withIdentifier: SegueFromSearch.toChat.rawValue, sender: self)
    }
	
}

extension BCSearchController: BCFacebookRequestDelegate {
    func facebookFriendRequestDidFinish() {
		DispatchQueue.main.async {
			self.refreshControl?.endRefreshing()
		}
    }
}
