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
            NSLog("[ShieldAction] primary tapped (application token)")
            // Read the current context (set by the configuration extension) to get bundle ID + name.
            let ctx = AppGroupBridge.currentShieldContext()
            if let b = ctx.bundleID, !b.isEmpty {
                // Prefer the name from context; if missing, try the latest stored name for this bundle.
                let name = (ctx.appName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? AppGroupBridge.latestName(forBundleID: b)
                // If server (via app) has marked this bundle as allowed, set an exception for this token now.
                if AppGroupBridge.isBundleAllowed(b) {
                    let store = ManagedSettingsStore()
                    var blocked = store.shield.applications ?? []
                    if blocked.contains(application) {
                        blocked.remove(application)
                        store.shield.applications = blocked.isEmpty ? nil : blocked
                        NSLog("[ShieldAction] removed token from blocked set for %@ (remaining: %d)", b, blocked.count)
                    } else {
                        NSLog("[ShieldAction] token for %@ not currently in blocked set", b)
                    }
                }
                AppGroupBridge.setPendingMessageRequest(bundleID: b, appName: name)
            } else if let attempt = AppGroupBridge.latestAttempt() {
                AppGroupBridge.setPendingMessageRequest(bundleID: attempt.bundleID, appName: attempt.appName)
            } else {
                // As a last resort, trigger a generic draft; the composer hides this placeholder.
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
        switch action {
        case .primaryButtonPressed:
            NSLog("[ShieldAction] primary tapped (webDomain token)")
            let ctx = AppGroupBridge.currentShieldContext()
            if let b = ctx.bundleID, !b.isEmpty {
                let name = (ctx.appName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                AppGroupBridge.setPendingMessageRequest(bundleID: b, appName: name)
            }
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.defer)
        @unknown default:
            completionHandler(.none)
        }
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            NSLog("[ShieldAction] primary tapped (category token)")
            let ctx = AppGroupBridge.currentShieldContext()
            if let b = ctx.bundleID, !b.isEmpty {
                let name = (ctx.appName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                AppGroupBridge.setPendingMessageRequest(bundleID: b, appName: name)
            }
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.defer)
        @unknown default:
            completionHandler(.none)
        }
    }

    // Note: Shield action extensions cannot programmatically foreground the container app
    // or present UI. The main app will present the SMS composer when it becomes active
    // by reading the pending request from the App Group.
}
