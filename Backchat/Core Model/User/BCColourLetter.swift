//
//  ColourLetters.swift
//  Backchat
//
//  Created by Bradley Mackey on 20/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation
import UIKit

/// # BCColourLetters
/// The colours that each colour letter should correspond to, this enumeration contains lots of methods for interacting with such colours.
public enum BCColourLetter:String {
	// note - "f" in a username indicates they are the chat OP, they should have a black name, but coloured cell
    case blue      = "b"
    case red       = "r"
    case green     = "g"
    case purple    = "p"
    case orange    = "o"
    case magenta   = "m"
    case yellow    = "y"
    case cyan      = "c"
	case pink	   = "u"
	case gold	   = "s"
	case gray	   = "q"
	case turquoise = "t"
    case black     = "x"
	
	
	/// - returns: the current user's colour, as to how it is set in the user's profile preferences.
    public static func colourFromCurrentUserLetter() -> UIColor {
        return BCColourLetter.colourFromLetter(letter: BCCurrentUser.colourLetter)
    }
	
	/// Returns a colour when provided a specific letter, which is contained in the person's username in the database, the person's username then goes that colour.
	/// - parameter letter: the letter of the colour
	/// - returns: the colour that the username should be
	public static func colourFromLetter(letter:String) -> UIColor {
        guard let colour = BCColourLetter(rawValue: letter) else { return .black }
		switch colour {
		case .blue: return UIColor(red: 0, green: 122/255, blue: 1, alpha: 1)
		case .red: return UIColor(red: 1, green: 59/255, blue: 48/255, alpha: 1)
		case .green: return UIColor(red: 76/255, green: 217/255, blue: 100/255, alpha: 1)
		case .purple: return UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1)
		case .orange: return UIColor(red: 1, green: 149/255, blue: 0/255, alpha: 1)
		case .magenta: return UIColor(red: 1, green: 45/255, blue: 85/255, alpha: 1)
		case .yellow: return UIColor(red: 1, green: 204/255, blue: 0, alpha: 1)
		case .cyan: return UIColor(red: 52/255, green: 170/255, blue: 220/255, alpha: 1)
		case .pink: return UIColor(red: 239/255, green: 58/255, blue: 221/255, alpha: 1)
		case .gold: return UIColor(red: 245/255, green: 220/255, blue: 3/255, alpha: 1)
		case .gray: return UIColor.gray
		case .turquoise: return UIColor(red: 0/255, green: 153/255, blue: 153/255, alpha: 1)
        case .black: return UIColor.black
		}
	}
    
    /// Advances to the next colour for a given colour, to be used within the `BCUsernameController` when we are changing the colour of the username.
    /// - parameter currentColour: the colour we are currently on
    /// - returns: the colour we should advance to
    public static func nextColour(currentColour: BCColourLetter) -> BCColourLetter {
        switch currentColour {
        case .black: return .blue
        case .blue: return .red
        case .red: return .green
        case .green: return .purple
        case .purple: return .orange
        case .orange: return .magenta
        case .magenta: return .yellow
        case .yellow: return .cyan
        case .cyan: return .pink
        case .pink: return .gold
        case .gold: return .gray
        case .gray: return .turquoise
        case .turquoise: return .black
        }
    }
}
