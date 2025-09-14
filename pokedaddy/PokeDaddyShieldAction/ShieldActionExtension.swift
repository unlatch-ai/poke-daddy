//
//  ShieldActionExtension.swift
//  PokeDaddyShieldAction
//
//  Created by Kevin Fang on 9/13/25.
//

import ManagedSettings
import Foundation

// Make sure this class name matches the extension principal class in the target's Info.plist.
class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Write a pending SMS request using the latest attempt logged by the configuration extension.
            if let attempt = AppGroupBridge.latestAttempt() {
                AppGroupBridge.setPendingMessageRequest(bundleID: attempt.bundleID, appName: attempt.appName)
            } else {
                AppGroupBridge.setPendingMessageRequest(bundleID: "unknown.bundle", appName: nil)
            }
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.defer)
        @unknown default:
            completionHandler(.none)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
}
