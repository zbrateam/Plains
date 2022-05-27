//
//  PLConfig+Additions.swift
//  Plains
//
//  Created by Adam Demasi on 27/5/2022.
//

import Foundation

public extension PlainsConfig {

    func fileURL(forKey key: String) -> URL? {
        if let string = string(forKey: key) {
            return URL(fileURLWithPath: string)
        }
        return nil
    }

    @objc subscript(key: String) -> String? {
        get { string(forKey: key) }
        set {
            if let newValue = newValue {
                set(string: newValue, forKey: key)
            } else {
                removeObject(forKey: key)
            }
        }
    }

}
