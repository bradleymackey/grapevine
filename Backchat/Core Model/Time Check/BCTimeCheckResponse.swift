//
//  BCTimeCheckResponse.swift
//  Backchat
//
//  Created by Bradley Mackey on 13/01/2017.
//  Copyright © 2017 Bradley Mackey. All rights reserved.
//

import Foundation

/// # BCTimeCheckResponse
/// An enumeration of all the possible responses from `BCTimeCheck` doing its thing.
public enum BCTimeCheckResponse {
	case accurate
	case inaccurate
	case error
}
