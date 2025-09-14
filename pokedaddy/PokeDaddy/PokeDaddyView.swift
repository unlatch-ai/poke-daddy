//
//  BrockerView.swift
//  PokeDaddy
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import FamilyControls
import ManagedSettings

struct PokeDaddyView: View {
    @EnvironmentObject private var appBlocker: AppBlocker
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var pendingDraft: MessageDraft?
    @State private var lastRequestedBundleID: String?
    
    private var isBlocking : Bool {
        get {
            return appBlocker.isBlocking
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                blockOrUnblockSection

                if !isBlocking {
                    Divider()
                    ProfilesPicker(profileManager: profileManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.move(edge: .bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isBlocking ? Color("BlockingBackground") : Color("NonBlockingBackground"))
            .navigationBarItems(leading: signOutButton, trailing: refreshButton)
        }
        .animation(.spring(), value: isBlocking)
        .onAppear(perform: checkForPendingMessage)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkForPendingMessage()
            // Also refresh blocking status when app returns to foreground
            appBlocker.refreshBlockingStatus()
            if let serverId = profileManager.currentServerProfileId {
                appBlocker.refreshServerRestrictions(profileId: serverId)
            }
        }
        .sheet(item: $pendingDraft) { draft in
            MessageComposerView(draft: draft) {
                // After SMS sheet, refresh restrictions from server (if active)
                appBlocker.refreshServerRestrictions(profileId: profileManager.currentServerProfileId)
                if let bundle = lastRequestedBundleID, let profileId = profileManager.currentServerProfileId {
                    appBlocker.markAllowedIfServerUnblocked(candidateBundle: bundle, profileId: profileId)
                }
            }
        }
        .ignoresSafeArea(.keyboard) // avoid layout shrink/cutoff when keyboard shows
    }
    
    @ViewBuilder
    private var blockOrUnblockSection: some View {
        VStack(spacing: 8) {
            Text(isBlocking ? "Apps are blocked - Server must unblock" : "Tap to start blocking")
                .font(.caption)
                .opacity(0.75)
                .transition(.scale)

            Button(action: {
                withAnimation(.spring()) { toggleBlocking() }
            }) {
                Image(isBlocking ? "RedIcon" : "GreenIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 280)
                    .frame(maxWidth: .infinity)
            }
            .transition(.scale)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .frame(maxHeight: isBlocking ? .infinity : nil, alignment: .center)
        .animation(.spring(), value: isBlocking)
    }
    
    private func toggleBlocking() {
        // Only allow starting blocking, not stopping
        if !isBlocking {
            NSLog("Starting block")
            // MVP: always use local blocking (server integration handled later)
            appBlocker.startBlocking(for: profileManager.currentProfile)
            if let serverId = profileManager.currentServerProfileId {
                appBlocker.startServerBlocking(profileId: serverId)
            }
        }
    }

    private var signOutButton: some View {
        Button("Sign Out") {
            if !isBlocking {
                authManager.signOut()
            }
        }
        .foregroundColor(isBlocking ? .gray : .red)
        .disabled(isBlocking)
    }

    private var refreshButton: some View {
        Group {
            if isBlocking {
                Button(action: {
                    NSLog("Manual refresh tapped")
                    appBlocker.refreshBlockingStatus()
                    if let serverId = profileManager.currentServerProfileId {
                        appBlocker.refreshServerRestrictions(profileId: serverId)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private func checkForPendingMessage() {
        if let pending = AppGroupBridge.consumePendingMessageRequest() {
            var bundleID = pending.bundleID
            var name = pending.appName

            let lowered = bundleID.lowercased()
            if lowered == "unknown.bundle" || lowered == "uknown.bundle" || lowered.isEmpty {
                if let latest = AppGroupBridge.latestAttempt() {
                    bundleID = latest.bundleID
                    if let n = latest.appName, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        name = n
                    }
                }
            }

            NSLog("[PokeDaddyApp] presenting SMS for bundleID=%@ name=%@", bundleID, name ?? "nil")
            pendingDraft = MessageFactory.draftForBlockedApp(bundleID: bundleID, appName: name)
            lastRequestedBundleID = bundleID
        }
    }
    
}
