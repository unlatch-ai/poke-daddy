//
//  ShieldConfigurationExtension.swift
//  PokeDaddyShieldConfiguration
//
//  Created by Kevin Fang on 9/13/25.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

// Override the functions below to customize the shields used in various situations.
// The system provides a default appearance for any methods that your subclass doesn't override.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let bundleID = application.bundleIdentifier ?? "unknown.bundle"
        let appName = application.localizedDisplayName
        // Log attempt for the action extension to read later
        AppGroupBridge.appendAttempt(bundleID: bundleID, appName: appName)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "hand.raised.fill"),
            title: ShieldConfiguration.Label(text: "Blocked by PokeDaddy", color: .label),
            subtitle: ShieldConfiguration.Label(text: "\(appName ?? bundleID) — tap ‘Debate Poke’, then open PokeDaddy", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Debate Poke", color: .white),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Cancel", color: .secondaryLabel)
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "hand.raised.fill"),
            title: ShieldConfiguration.Label(text: "Blocked by PokeDaddy", color: .label),
            subtitle: ShieldConfiguration.Label(text: "Category restricted — open PokeDaddy to request", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Debate Poke", color: .white),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Cancel", color: .secondaryLabel)
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "hand.raised.fill"),
            title: ShieldConfiguration.Label(text: "Blocked by PokeDaddy", color: .label),
            subtitle: ShieldConfiguration.Label(text: "This site is restricted", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Debate Poke", color: .white),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Cancel", color: .secondaryLabel)
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: webDomain)
    }
}
