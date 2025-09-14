//
//  MessageComposer.swift
//  PokeDaddy
//
//  Created by Assistant on 14/09/2025.
//

import SwiftUI
import MessageUI

struct MessageDraft: Identifiable, Equatable {
    let id = UUID()
    let recipients: [String]
    let body: String
}

struct MessageComposerView: UIViewControllerRepresentable {
    let draft: MessageDraft
    let onFinish: () -> Void

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) { self.onFinish() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        if MFMessageComposeViewController.canSendText() {
            let vc = MFMessageComposeViewController()
            vc.messageComposeDelegate = context.coordinator
            vc.recipients = draft.recipients
            vc.body = draft.body
            return vc
        } else {
            // Fallback: show an alert controller explaining SMS not available
            let alert = UIAlertController(title: "Messaging Not Available",
                                          message: "This device can't send SMS. Copy the message and send it manually.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in context.coordinator.onFinish() })
            return alert
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

enum MessageFactory {
    static let coachNumber = "+16504447507" // Poke's number

    static func draftForBlockedApp(bundleID: String, appName: String?) -> MessageDraft {
        // Normalize inputs
        let normalizedName = appName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isNameUsable = {
            guard let n = normalizedName, !n.isEmpty else { return false }
            // Guard against placeholders accidentally saved as a name
            let lowered = n.lowercased()
            return lowered != "unknown.bundle" && lowered != "uknown.bundle"
        }()
        let isBundleUseful = {
            let lowered = bundleID.lowercased()
            return !lowered.isEmpty && lowered != "unknown.bundle" && lowered != "uknown.bundle"
        }()

        let body: String
        if isNameUsable {
            body = "Hi Poke, please unblock \(normalizedName!) for me. I’d like to request access."
        } else if isBundleUseful {
            body = "Hi Poke, please unblock \(bundleID) for me. I’d like to request access."
        } else {
            body = "Hi Poke, I’d like to request access right now."
        }

        return MessageDraft(recipients: [coachNumber], body: body)
    }
}
