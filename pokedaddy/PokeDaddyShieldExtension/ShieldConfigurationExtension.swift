//
//  ShieldConfigurationExtension.swift
//  PokeDaddyShieldExtension
//
//  This file is part of a ManagedSettingsUI extension target that customizes
//  the shield page and records block attempts. Add this file to a new
//  "Managed Settings UI" extension target in Xcode, and enable the same
//  App Group used by the main app.
//

import ManagedSettingsUI

final class ShieldConfigDataSource: ShieldConfigurationDataSource {
    // App shield
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let bundleID = application.bundleIdentifier ?? "unknown.bundle"
        let displayName = application.localizedDisplayName

        // Log the attempt to the shared app group
        AppGroupBridge.appendAttempt(bundleID: bundleID, appName: displayName)

        let title = ShieldConfiguration.Label(text: "Blocked by PokeDaddy")
        let subtitle = ShieldConfiguration.Label(text: "\(displayName ?? bundleID) — tap ‘Debate Poke’, then open PokeDaddy")
        let primary = ShieldConfiguration.Button(label: .init(text: "Debate Poke"))
        let secondary = ShieldConfiguration.Button(label: .init(text: "Cancel"))
        return ShieldConfiguration(icon: .init(systemName: "hand.raised.fill"), title: title, subtitle: subtitle, primaryButtonLabel: primary.label, secondaryButtonLabel: secondary.label)
    }

    // Category shield fallback
    override func configuration(shielding applicationCategory: Application.Category) -> ShieldConfiguration {
        ShieldConfiguration(icon: .init(systemName: "hand.raised.fill"), title: .init(text: "Blocked by PokeDaddy"), subtitle: .init(text: "Category restricted — open PokeDaddy to request"), primaryButtonLabel: .init(text: "Debate Poke"), secondaryButtonLabel: .init(text: "Cancel"))
    }
}
