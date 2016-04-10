//
//  MLMigrationManager.swift
//
//  Created by Maximilian Litteral on 1/25/16.
//  Copyright © 2016 Maximilian Litteral. All rights reserved.
//

import Foundation

enum MLMigrationManagerError: ErrorType {
    case InvalidVersionString(version: String)
    case MigrationVersion(version: String, isDefinedAfterVersion: String)
    case CannotRunMigrationBiggerThanCurrentVersion(version: String)
}

class MLMigrationManager {
    
    // Public
    static let sharedManager = MigrationManager()
    var currentVersion: String
    
    // Private
    private var lastVersionKey: String
    private var previousVersion: String?
    private var lastMigrationVersion: String? {
        get {
            return NSUserDefaults.standardUserDefaults().stringForKey(self.lastVersionKey)
        }
        set {
            NSUserDefaults.standardUserDefaults().setObject(newValue, forKey: self.lastVersionKey)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    private let MigrationManagerLastVersionKey = "MigrationManagerLastVersionKey"
    
    private let MigrationManagerVersionRegexString = "^([0-9]{1,2}\\.)+[0-9]{1,2}(-[0-9]{1,2})?$"
    
    // MARK: - Lifecycle
    
    convenience init() {
        self.init(name: nil)
    }
    
    convenience init(name: String?) {
        self.init(name: name, currentVersion: nil)
    }
    
    convenience init(currentVersion: String) {
        self.init(name: nil, currentVersion: currentVersion)
    }
    
    init(name: String?, currentVersion: String?) {
        self.currentVersion = currentVersion ?? NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
        self.lastVersionKey = name != nil ? MigrationManagerLastVersionKey.stringByAppendingFormat("-\(name!)") : MigrationManagerLastVersionKey
        
        self.storeInitialVersion()
    }
    
    // MARK: - Actions
    
    // MARK: Public Methods
    
    func whenMigratingToVersion(version: String, run: (() -> Void)) {
        do {
            try self.assertVersionMatchesRegex(version)
            try self.assertVersionSmallerThanCurrentVersion(version)
            try self.assertVersionOrderIsValid(version)
            
            guard self.shouldMigrateToVersion(version) == true else {
                return
            }
            
            run()
            self.lastMigrationVersion = version
        }
        catch {
            
        }
    }
    
    func reset() {
        self.lastMigrationVersion = nil
    }
    
    // MARK: Implementation
    
    private func storeInitialVersion() {
        if self.lastMigrationVersion == nil {
            self.lastMigrationVersion = self.currentVersion
        }
    }
    
    private func assertVersionOrderIsValid(version: String) throws {
        guard let prevVersion = self.previousVersion else {
            return
        }
        
        if self.isVersion(version, greaterThan: prevVersion) == false {
            #if DEBUG
                print("Migration version \(version) is defined after version \(prevVersion), which is not permitted!")
            #endif
            throw MigrationManagerError.MigrationVersion(version: version, isDefinedAfterVersion: prevVersion)
        }
        
        self.previousVersion = version
    }
    
    private func assertVersionMatchesRegex(version: String) throws {
        do {
            let regex = try NSRegularExpression(pattern: MigrationManagerVersionRegexString, options: NSRegularExpressionOptions(rawValue: 0))
            let versionIsValid = regex.numberOfMatchesInString(version, options: NSMatchingOptions(rawValue: 0), range: NSMakeRange(0, version.characters.count)) == 1
            
            if versionIsValid == false {
                #if DEBUG
                    print("Invalid version string \"\(version)\", see regex and spec for appropriate version format")
                #endif
                throw MigrationManagerError.InvalidVersionString(version: version)
            }
        }
        catch {
            
        }
    }
    
    private func assertVersionSmallerThanCurrentVersion(version: String) throws {
        if isVersionGreaterThanCurrentVersion(version) {
            #if DEBUG
                print("Cannot run migration for a version (\(version)) that is bigger than the current app version (\(self.currentVersion))")
            #endif
            throw MigrationManagerError.CannotRunMigrationBiggerThanCurrentVersion(version: version)
        }
    }
    
    private func shouldMigrateToVersion(version: String) -> Bool {
        guard let lmv = self.lastMigrationVersion else { return false }
        return self.isVersion(version, greaterThan: lmv)
    }
    
    private func isVersionGreaterThanCurrentVersion(version: String) -> Bool {
        guard let versionWithoutSubVersion = version.componentsSeparatedByString("-").first else {
            return false
        }
        return self.isVersion(versionWithoutSubVersion, greaterThan: self.currentVersion)
    }
    
    private func isVersion(version: String, greaterThan version2: String) -> Bool {
        #if DEBUG
            print("Comparing \(version) to \(version2)")
        #endif
        return version.compare(version2, options: .NumericSearch, range: nil, locale: nil) == .OrderedDescending
    }
}