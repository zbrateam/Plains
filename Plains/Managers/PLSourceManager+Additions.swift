//
//  PLSourceManager+Additions.swift
//  Plains
//
//  Created by Adam Demasi on 27/5/2022.
//

import Foundation

public enum ArchiveType: String {
    case deb = "deb"
    case debSrc = "deb-src"
}

public extension SourceManager {

    @objc static let sourceListDidUpdateNotification = Notification.Name(rawValue: "SourceManagerSourceListDidUpdateNotification")

    // MARK: - Get Source

    /**
     Get a the instance of a source from a corresponding UUID.

     - parameter uuid: The UUID of the source you want to search for.
     - returns: The source instance with a matching UUID or `NULL` if no such source exists.
     */
    @objc func source(forUUID uuid: String) -> Source? {
        sources.first { $0.uuid == uuid }
    }

    // MARK: - Sources List

    @objc func generateSourcesFile() throws {
        let listURL = PlainsConfig.shared.fileURL(forKey: "Plains::SourcesList")!
        if (try? listURL.checkResourceIsReachable()) == true {
            return
        }
        try addSource(url: "https://getzbra.com/repo/")

        /*
         TODO:

         NSString *etcDir = [config stringForKey:@"Dir::Etc"];
         NSString *sourcePartsDir = [config stringForKey:@"Dir::Etc::sourceparts"];
         NSString *filename = sourcesFilePath.lastPathComponent;
         NSString *sourcesLinkPath = [NSString stringWithFormat:@"/%@/%@/%@", etcDir, sourcePartsDir, filename];
         if (![defaultManager fileExistsAtPath:sourcesLinkPath]) {
             const char *const argv[] = {
                 [config stringForKey:@"Plains::Slingshot"].UTF8String,
                 "/bin/ln",
                 "-s",
                 sourcesFilePath.UTF8String,
                 sourcesLinkPath.UTF8String,
                 NULL
             };

             pid_t pid;
             posix_spawn(&pid, argv[0], NULL, NULL, (char * const *)argv, environ);
             waitpid(pid, NULL, 0);
         }
         */
    }

    /**
     Adds a source to the file designated by `Plains::SourcesList`.

     - parameter url: The URL of the repository.
     - parameter archiveType: The archive type of the source.
     - parameter distribution: The repository's distribution.
     - parameter components: The repository's components, if applicable.
     */
    @nonobjc func addSource(url: String, archiveType: ArchiveType = .deb, suites: String = "./", components: [String]? = nil) throws {
        let repoEntry = """
        Types: \(archiveType.rawValue)
        URIs: \(url)
        Suites: \(suites)
        Components: \((components ?? []).joined(separator: " "))
        """

        let listURL = PlainsConfig.shared.fileURL(forKey: "Plains::SourcesList")!
        let fileHandle = try FileHandle(forReadingFrom: listURL)
        try fileHandle.seekToEnd()
        fileHandle.write((repoEntry + "\n").data(using: .utf8)!)
        try fileHandle.close()

        readSources()
        PackageManager.shared.import()
    }

    @objc(addSourceWithURL:archiveType:suites:components:error:)
    func addSourceObjC(url: String, archiveType: ArchiveType.RawValue, suites: String, components: [String]?) throws {
        try addSource(url: url, archiveType: ArchiveType(rawValue: archiveType)!, suites: suites, components: components)
    }

//    func removeSource(_ source: Source) throws {
//        // TODO: This
//    }

}
