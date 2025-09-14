//
//  AppGroupBridge.swift
//  PokeDaddy
//
//  Created by Assistant on 14/09/2025.
//

import Foundation

enum AppGroupBridge {
    // TODO: Set to your real App Group identifier and enable it for the app and extensions.
    static let appGroupID = "group.com.pokedaddy"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    private enum Keys {
        static let pendingMessage = "pending_message_request"
        static let pendingMessageBundleID = "pending_message_bundle_id"
        static let pendingMessageAppName = "pending_message_app_name"
        static let lastAttempts = "shield_attempts"
    }

    struct BlockAttempt: Codable {
        let bundleID: String
        let appName: String?
        let date: Date
    }

    // MARK: - Attempts Log
    static func appendAttempt(bundleID: String, appName: String?) {
        var attempts = fetchAttempts(max: 100)
        attempts.append(BlockAttempt(bundleID: bundleID, appName: appName, date: Date()))
        saveAttempts(attempts.suffix(100))
    }

    static func fetchAttempts(max: Int = 100) -> [BlockAttempt] {
        guard let data = defaults?.data(forKey: Keys.lastAttempts) else { return [] }
        return (try? JSONDecoder().decode([BlockAttempt].self, from: data))?.suffix(max) ?? []
    }

    private static func saveAttempts<S: Sequence>(_ attempts: S) where S.Element == BlockAttempt {
        guard let data = try? JSONEncoder().encode(Array(attempts)) else { return }
        defaults?.set(data, forKey: Keys.lastAttempts)
    }

    static func latestAttempt() -> BlockAttempt? {
        fetchAttempts().last
    }

    // MARK: - Pending Message Request
    static func setPendingMessageRequest(bundleID: String, appName: String?) {
        defaults?.set(true, forKey: Keys.pendingMessage)
        defaults?.set(bundleID, forKey: Keys.pendingMessageBundleID)
        defaults?.set(appName, forKey: Keys.pendingMessageAppName)
        defaults?.synchronize()
    }

    static func consumePendingMessageRequest() -> (bundleID: String, appName: String?)? {
        guard defaults?.bool(forKey: Keys.pendingMessage) == true else { return nil }
        let bundleID = defaults?.string(forKey: Keys.pendingMessageBundleID) ?? ""
        let appName = defaults?.string(forKey: Keys.pendingMessageAppName)
        // clear
        defaults?.removeObject(forKey: Keys.pendingMessage)
        defaults?.removeObject(forKey: Keys.pendingMessageBundleID)
        defaults?.removeObject(forKey: Keys.pendingMessageAppName)
        defaults?.synchronize()
        return bundleID.isEmpty ? nil : (bundleID, appName)
    }
}
