//
//  SortCommand.swift
//  Sort
//
//  Created by B. Kevin Hardman on 11/22/19.
//  Copyright © 2019 Hard Days, Inc. All rights reserved.
//

import Cocoa
import Foundation
import XcodeKit

enum SortError: Swift.Error {
	case invalidSelection
	case parseError
	case regexError
}

extension String {

	func groupedMatches(for regex: NSRegularExpression) -> [[String]] {
		let text = self
		let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
		return matches.map { match in
			return (1..<match.numberOfRanges).map {
				guard let range = Range(match.range(at: $0), in: text) else {
					return ""
				}
				return String(text[range])
			}
		}
	}

	func matches(for regex: NSRegularExpression) -> String {
		return reducedMatches(for: regex).joined(separator: "")
	}

	func reducedMatches(for regex: NSRegularExpression) -> [String] {
		return groupedMatches(for: regex).reduce([], +)
	}

}

class SortCommand: NSObject, XCSourceEditorCommand {

	func isLower(_ lhs: String, _ rhs: String) -> Bool {
		return lhs.compare(rhs) == .orderedAscending
	}

	func isLowerCaseInsensitive(_ lhs: String, _ rhs: String) -> Bool {
		return lhs.caseInsensitiveCompare(rhs) == .orderedAscending
	}

	func isLowerIgnoringLeadingWhitespacesAndTabs(_ lhs: String, _ rhs: String) -> Bool {
		return lhs.trimmingCharacters(in: .whitespaces) < rhs.trimmingCharacters(in: .whitespaces)
	}

    func sort(_ inputLines: NSMutableArray, in range: CountableClosedRange<NSInteger>, by comparator: (String, String) -> Bool) {
        guard range.upperBound < inputLines.count, range.lowerBound >= 0 else {
            return
        }

        let lines = inputLines.compactMap { $0 as? String }
		let unsorted = Array(lines[range])
        let sorted = unsorted.sorted(by: comparator)
		if sorted == unsorted {
			return
		}

        for lineIndex in range {
            inputLines[lineIndex] = sorted[lineIndex - range.lowerBound]
        }
    }

	func sort(_ inputLines: NSMutableArray, in range: CountableClosedRange<NSInteger>, regex: NSRegularExpression, by comparator: (String, String) -> Bool) {
		sort(inputLines, in: range) { (lhs: String, rhs: String) -> Bool in
			let l = lhs.matches(for: regex)
			let r = rhs.matches(for: regex)
			return comparator(l, r)
		}
	}

	func sortGroup(with invocation: XCSourceEditorCommandInvocation, by comparator: (String, String) -> Bool) -> SortError? {
		for index in 0..<invocation.buffer.selections.count {
			let range = sourceRange(range: invocation.buffer.selections[index] as! XCSourceTextRange)
			let subranges = range.split {
				(invocation.buffer.lines[$0] as! String).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
			}
			subranges.forEach {
				sort(invocation.buffer.lines, in: $0.first!...$0.last!, by: comparator)
			}
		}
		return nil
	}

	func sortRange(with invocation: XCSourceEditorCommandInvocation, by comparator: (String, String) -> Bool) -> SortError? {
		for index in 0..<invocation.buffer.selections.count {
			let range = sourceRange(range: invocation.buffer.selections[index] as! XCSourceTextRange)

			sort(invocation.buffer.lines, in: range, by: comparator)
		}
		return nil
	}

	func sortRegex(with invocation: XCSourceEditorCommandInvocation, by comparator: (String, String) -> Bool) -> SortError? {
		let pasteboard = NSPasteboard(name:.find)
		guard let string = pasteboard.string(forType: .string) else {
			return .regexError
		}
		guard let regex = try? NSRegularExpression(pattern: string, options: .caseInsensitive) else {
			return .regexError
		}
		for index in 0..<invocation.buffer.selections.count {
			let range = sourceRange(range: invocation.buffer.selections[index] as! XCSourceTextRange)

			sort(invocation.buffer.lines, in: range, regex: regex, by: comparator)
		}
		return nil
	}

	func sourceRange(range inRange: XCSourceTextRange) -> CountableClosedRange<NSInteger> {
		if inRange.end.column == 0 {
			return inRange.start.line...inRange.end.line - 1
		}
		return inRange.start.line...inRange.end.line
	}

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        // Implement your command here, invoking the completion handler when done. Pass it nil on success, and an NSError on failure.
		switch invocation.commandIdentifier {
		case "com.harddays.XcodeSort.Sort.folding":
			return completionHandler(sortRange(with: invocation, by:isLowerCaseInsensitive))
		case "com.harddays.XcodeSort.Sort.ignore":
			return completionHandler(sortRange(with: invocation, by:isLowerIgnoringLeadingWhitespacesAndTabs))
		case "com.harddays.XcodeSort.Sort.include":
			return completionHandler(sortGroup(with: invocation, by:isLowerCaseInsensitive))
		case "com.harddays.XcodeSort.Sort.normal":
			return completionHandler(sortRange(with: invocation, by:isLower))
		case "com.harddays.XcodeSort.Sort.regex":
			return completionHandler(sortRegex(with: invocation, by:isLower))
		default:
			completionHandler(nil)
		}
    }
    
}
