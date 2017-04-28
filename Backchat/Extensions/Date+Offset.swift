//
//  Date+Offset.swift
//  Backchat
//
//  Created by Bradley Mackey on 01/12/2016.
//  Copyright © 2016 Bradley Mackey. All rights reserved.
//

import Foundation

extension Date {
	private func yearsFrom(_ date:Date) -> Int {
		return (Calendar.current as NSCalendar).components(.year, from: date, to: self, options: []).year!
	}
	private func monthsFrom(_ date:Date) -> Int {
		return (Calendar.current as NSCalendar).components(.month, from: date, to: self, options: []).month!
	}
	private func weeksFrom(_ date:Date) -> Int {
		return (Calendar.current as NSCalendar).components(.weekOfYear, from: date, to: self, options: []).weekOfYear!
	}
	private func daysFrom(_ date:Date) -> Int {
		return (Calendar.current as NSCalendar).components(.day, from: date, to: self, options: []).day!
	}
	private func hoursFrom(_ date:Date) -> Int {
		return (Calendar.current as NSCalendar).components(.hour, from: date, to: self, options: []).hour!
	}
	private func minutesFrom(_ date:Date) -> Int {
		return (Calendar.current as NSCalendar).components(.minute, from: date, to: self, options: []).minute!
	}
	private func secondsFrom(_ date:Date) -> Int {
		return (Calendar.current as NSCalendar).components(.second, from: date, to: self, options: []).second!
	}
	/// Gives a '(time) ago' string for a given date with an intelligently selected timescale.
	/// - Note: <5 seconds = "Just now"
	public func offsetFrom(_ date:Date) -> String {
		if yearsFrom(date)   > 0 { return "\(yearsFrom(date))y ago"   }
		if monthsFrom(date)  > 0 { return "\(monthsFrom(date))M ago"  }
		if weeksFrom(date)   > 0 { return "\(weeksFrom(date))w ago"   }
		if daysFrom(date)    > 0 { return "\(daysFrom(date))d ago"    }
		if hoursFrom(date)   > 0 { return "\(hoursFrom(date))h ago"   }
		if minutesFrom(date) > 0 { return "\(minutesFrom(date))m ago" }
		if secondsFrom(date) < 0 { return inversedOffsetFrom(date) }
		if secondsFrom(date) < 30 { return "now" }
		if secondsFrom(date) > 0 { return "1m ago" } // sacrifice precision for accuracy
		return "now"
	}
	
	private func inversedOffsetFrom(_ date:Date) -> String {
		if yearsFrom(date)   < 0 { return "in \(-yearsFrom(date))y"   }
		if monthsFrom(date)  < 0 { return "in \(-monthsFrom(date))M"  }
		if weeksFrom(date)   < 0 { return "in \(-weeksFrom(date))w"   }
		if daysFrom(date)    < 0 { return "in \(-daysFrom(date))d"    }
		// add 1 to hours so it makes more sense
		if hoursFrom(date)   < 0 { return "in \((-hoursFrom(date))+1)h"   }
		if minutesFrom(date) < 0 { return "in \(-minutesFrom(date))m" }
		return "now"
	}
}

