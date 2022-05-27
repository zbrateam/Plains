//
//  Email.swift
//  Plains
//
//  Created by Adam Demasi on 27/5/2022.
//

import Foundation

@objc(PLEmail)
public class Email: NSObject {
    @objc public let name: String
    @objc public let email: String?

    @objc var rfc822Value: String {
        if let email = email {
            return "\(name) <\(email)>"
        }
        return name
    }

    @objc public init(name: String, email: String?) {
        self.name = name
        self.email = email
        super.init()
    }

    @objc(initWithRFC822Value:)
    public convenience init?(rfc822Value: String) {
        if rfc822Value.isEmpty {
            return nil
        }

        if let emailStart = rfc822Value.range(of: " <"),
           let emailEnd = rfc822Value.range(of: ">"),
           emailEnd.upperBound == rfc822Value.endIndex {
            self.init(name: String(rfc822Value[..<emailStart.lowerBound]),
                      email: String(rfc822Value[emailStart.upperBound..<emailEnd.lowerBound]))
        } else {
            self.init(name: rfc822Value, email: nil)
        }
    }

    public override var description: String { rfc822Value }

}
