//
//  String+PlainsAdditions.swift
//  Plains
//
//  Created by Adam Demasi on 2/6/2022.
//

import Foundation

public extension String {
    internal var cString: UnsafeMutablePointer<CChar>? {
        strdup(self)
    }

    internal func replacingOccurrences(regex: String, with replacement: String, options: CompareOptions = []) -> Self {
        replacingOccurrences(of: regex,
                             with: replacement,
                             options: options.union(.regularExpression),
                             range: startIndex..<endIndex)
    }

    var cleanedSectionName: String {
        replacingOccurrences(of: "_", with: " ")
    }

    var baseSectionName: String? {
        cleanedSectionName.replacingOccurrences(regex: " \\(.*\\)$", with: "")
    }
}

public extension NSString {
    @objc(plains_cleanedSectionName)
    var cleanedSectionName: String {
        replacingOccurrences(of: "_", with: " ")
    }

    @objc(plains_baseSectionName)
    var baseSectionName: String? {
        cleanedSectionName.replacingOccurrences(regex: " \\(.*\\)$", with: "")
    }
}
