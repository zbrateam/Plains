//
//  PLSource+Additions.swift
//  Plains
//
//  Created by Adam Demasi on 4/6/2022.
//

import Foundation

public extension Source {

    override var description: String {
        String(format: "<%@: %p; %@; %@ %@ %@ %@>",
               String(describing: Swift.type(of: self)),
               self,
               type,
               origin,
               uri.absoluteString,
               codename,
               components.joined(separator: " "))
    }

    override var hash: Int {
        uuid.hashValue ^ type.hashValue ^ components.hashValue ^ architectures.hashValue
    }

    // MARK: - Fields

    var origin: String { self["Origin"] ?? self["Label"] ?? uri.host ?? uri.path }

    /**
     URL of an image that can be used to represent this source.

     For iphoneos-arm repositories this will return `CydiaIcon.png`, otherwise this will return `RepoIcon.png`.
     */
    var iconURL: URL {
        let arch = architectures.first ?? PlainsConfig.shared.string(forKey: "APT::Architecture")
        let iconName = arch == "iphoneos-arm" ? "CydiaIcon.png" : "RepoIcon.png"
        return baseURI.appendingPathComponent(iconName)
    }

    // MARK: - Packages

    /**
     A count of all packages hosted by the source.
     */
    var count: UInt { sections.values.reduce(0, { $0 + UInt(truncating: $1) }) }

    // MARK: - State

    /**
     Whether or not this source can be removed by Plains.
     */
    var canRemove: Bool {
        entryFilePath == PlainsConfig.shared.string(forKey: "Plains::SourcesList")
            && uuid != "getzbra.com_repo_._"
    }

    // MARK: - Subscripting

    @objc subscript(key: String) -> String? {
        getField(key)
    }

}
