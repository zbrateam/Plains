//
//  PLError.swift
//  Plains
//
//  Created by Adam Demasi on 27/5/2022.
//

import Foundation

@objc(PLError)
public class PlainsError: NSObject {
    @objc public let level: ErrorLevel
    @objc public let text: String
    
    @objc public init(level: ErrorLevel, text: String) {
        self.level = level
        self.text = text
        super.init()
    }

    public override var description: String {
        "PlainsError: \(level): \(text)"
    }

    public override var hash: Int {
        level.hashValue ^ text.hashValue
    }

    static func == (lhs: PlainsError, rhs: PlainsError) -> Bool {
        lhs.level == rhs.level && lhs.text == rhs.text
    }
}
