//
//  ShieldActionExtension.swift
//  PokeDaddyShieldExtension
//
//  Handles button taps on the shield. When the user taps "Text Poke",
//  we write a pending message request into the App Group. The container
//  app will present the SMS composer the next time it becomes active.
//

import ManagedSettings
import Foundation

final class PokeDaddyShieldAction: ShieldActionHandler {
    override func handle(action: ShieldAction,
                         for application: Application,
                         completionHandler: @escaping (ShieldActionResponse) -> Void
                         ) {
        switch action {
        case .primaryButtonPressed:
            // Mark a pending message request using the latest attempt recorded by the
            // configuration data source (includes bundle ID and possibly app name).
            if let attempt = AppGroupBridge.latestAttempt() {
                AppGroupBridge.setPendingMessageRequest(bundleID: attempt.bundleID, appName: attempt.appName)
            } else {
                AppGroupBridge.setPendingMessageRequest(bundleID: application.bundleIdentifier ?? "unknown.bundle", appName: nil)
            }
            completionHandler(.none)
        default:
            completionHandler(.none)
        }
    }
}
