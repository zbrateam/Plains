//
//  PLPackage+Additions.swift
//  Plains
//
//  Created by Adam Demasi on 27/5/2022.
//

import Foundation

@objc(PLPackageRole)
public enum PackageRole: Int, CaseIterable {
    /// Packages for general end users.
    case user

    /// Alias of `.user`.
    case endUser

    /// Packages containing command line tools or similar, not directly useful to a novice user.
    case hacker

    /// Packages containing libraries and similar, only useful as a dependency of another package.
    case developer

    /// Packages essential to a Cydia-compatible package management environment.
    case cydia

    public var value: String {
        switch self {
        case .user:      return "user"
        case .endUser:   return "enduser"
        case .hacker:    return "hacker"
        case .developer: return "developer"
        case .cydia:     return "cydia"
        }
    }
}

public extension Package {

    override var description: String {
        String(format: "<%@: %p; %@:%@ %@; source = %@>",
               String(describing: type(of: self)),
               self,
               identifier,
               architecture,
               version,
               source?.origin ?? "nil")
    }

    // MARK: - Versions

    /**
     Versions of this package that are lesser than itself.

     - returns: An array of Package objects representing all available lesser versions of this package.
     */
    var lesserVersions: [Package] {
        allVersions.filter { (installedVersion ?? version).compareVersion($0.version) == .orderedDescending }
    }

    /**
     Versions of this package that are greater than itself.

     - returns: An array of Package objects representing all available greater versions of this package.
     */
    var greaterVersions: [Package] {
        allVersions.filter { (installedVersion ?? version).compareVersion($0.version) == .orderedAscending }
    }

    // MARK: - Fields

    /**
     The package's name.

     Specified by a package's `Name` field, or `Package` field if no `Name` field is present.
     */
    @objc var name: String     { self["Name"] ?? identifier }

    /**
     The package's section.

     Specified by a package's `Section` field.
     */
    @objc var section: String? { self["Section"] }

    /**
     The URL of an icon that can be displayed to represent the package.

     Specified by a package's `Icon` field.

     This URL can be local or remote.
     */
    var iconURL: URL?      { URL(string: self["Icon"] ?? "") }

    /**
     The URL of a web-based depiction to display to provide more information about the package

     Specified by a package's `Depiction` field.
     */
    var depictionURL: URL? { URL(string: self["Depiction"] ?? "") }

    /**
     The URL of a native depiction to be displayed with DepictionKit to provide more information about the package

     Specified by a package's `Native-Depiction` field.
     */
    var nativeDepictionURL: URL? { URL(string: self["Native-Depiction"] ?? "") }

    /**
     The URL of the package's homepage to provide more information about it.

     Specified by a package's `Homepage` field.
     */
    var homepageURL: URL?  { URL(string: self["Homepage"] ?? "") }

    /**
     The URL of a header banner for the package.

     Specified by a package's `Banner` field.
     */
    var headerURL: URL?    { URL(string: self["Header"] ?? "") }

    /**
     Whether or not the package has a tagline.
     */
    var hasTagline: Bool   { !(longDescription ?? "").isEmpty && !shortDescription.isEmpty }

    /**
     Whether or not the package requires payment.

     Specified by the presence of the `cydia::commercial` tag.
     */
    var isPaid: Bool       { tags.contains("cydia::commercial") }

    /**
     The role of a package.

     Specified by a package's `Tag` field.

     Acceptable roles (prefixed by role::) are:
     - `user` or `enduser`
     - `hacker`
     - `developer`
     - `cydia`

     If a package does not have a role, it is assigned a role of .user.
     */
    var role: PackageRole {
        for tag in tags {
            if let firstHalfRange = tag.range(of: "role::"),
               firstHalfRange.lowerBound == tag.startIndex {
                let lastHalf = tag[firstHalfRange.upperBound..<tag.endIndex]
                if let value = PackageRole.allCases.first(where: { $0.value == lastHalf }) {
                    return value
                }
            }
        }
        return .user
    }

    /**
     The package's download size in the form of a string.
     */
    var downloadSizeString: String { ByteCountFormatter.string(fromByteCount: Int64(downloadSize), countStyle: .file) }

    /**
     The package's installed size in the form of a string.
     */
    var installedSizeString: String { ByteCountFormatter.string(fromByteCount: Int64(installedSize), countStyle: .file) }

    // MARK: - Installation

    private var listFileURL: URL {
        return PlainsConfig.shared.fileURL(forKey: "Dir::State::status")!
            .deletingLastPathComponent()
            .appendingPathComponent("info")
            .appendingPathComponent("\(identifier).list")
    }

    var installedDate: Date? {
        if let values = try? listFileURL.resourceValues(forKeys: [.contentModificationDateKey]),
           let date = values.contentModificationDate {
            return date
        }
        return nil
    }

    /**
     Files that this package has installed to the user's device.

     - returns: An array of strings representing file paths that are installed by this package onto
       the user's device. If the package is not installed, `NULL` is returned.
     */
    var installedFiles: [String]? {
        if let listFile = try? String(contentsOf: listFileURL) {
            return listFile.components(separatedBy: "\n")
        }
        return nil
    }

    // MARK: - Subscripting

    @objc subscript(key: String) -> String? {
        getField(key)
    }

}
