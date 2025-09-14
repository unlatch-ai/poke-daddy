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
    @State private var showCompleteProfileSheet = false
    @State private var emailInput: String = ""
    @State private var nameInput: String = ""
    
    private var isBlocking : Bool {
        get {
            return appBlocker.isBlocking
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                blockOrUnblockSection
                serverStatusBar

                if !isBlocking {
                    Divider()
                    ProfilesPicker(profileManager: profileManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.move(edge: .bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Use global gradient background from PokeDaddyApp
            .background(Color.clear)
            .navigationBarItems(leading: signOutButton, trailing: HStack { refreshButton; syncButton })
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
            maybePromptForProfile()
        }
        .onChange(of: profileManager.currentServerProfileId) { _, newId in
            if isBlocking, let id = newId {
                appBlocker.startServerBlocking(profileId: id)
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, newVal in
            if newVal {
                profileManager.loadServerProfiles()
                maybePromptForProfile()
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
        .sheet(isPresented: $showCompleteProfileSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Complete Your Profile")) {
                        TextField("Email", text: $emailInput)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                        TextField("Name (optional)", text: $nameInput)
                    }
                    Section {
                        Button("Save") {
                            authManager.completeProfile(email: emailInput.isEmpty ? nil : emailInput, name: nameInput.isEmpty ? nil : nameInput)
                            showCompleteProfileSheet = false
                        }.disabled(emailInput.isEmpty)
                    }
                }
                .navigationTitle("Complete Profile")
                .navigationBarItems(leading: Button("Cancel") { showCompleteProfileSheet = false })
            }
        }
        .ignoresSafeArea(.keyboard) // avoid layout shrink/cutoff when keyboard shows
    }
    
    @ViewBuilder
    private var blockOrUnblockSection: some View {
        VStack(spacing: 12) {
            Text(isBlocking ? "Blocking Active" : "Tap to Start Blocking")
                .font(.callout)
                .foregroundStyle(.secondary)
                .transition(.scale)

            Button(action: { withAnimation(.spring()) { toggleBlocking() } }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.5))
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: isBlocking ? [Color("BlockingBackground"), Design.brandEnd] : [Design.brandStart, Design.brandEnd],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ), lineWidth: 2
                        )
                    Image(isBlocking ? "RedIcon" : "GreenIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(24)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .shadow(color: Design.brandEnd.opacity(0.25), radius: 18, x: 0, y: 10)
            }
            .buttonStyle(.plain)
            .transition(.scale)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .frame(maxHeight: isBlocking ? .infinity : nil, alignment: .center)
        .animation(.spring(), value: isBlocking)
    }
    
    private func toggleBlocking() {
        // Only allow starting blocking, not stopping
        if !isBlocking {
            NSLog("Starting block")
            // MVP: always use local blocking (server integration handled later)
            appBlocker.startBlocking(for: profileManager.currentProfile)
            profileManager.ensureServerProfileIdReady { serverId in
                if let serverId = serverId {
                    appBlocker.startServerBlocking(profileId: serverId)
                } else {
                    NSLog("[Server] No server profile id available; skipping start call")
                }
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

    private var syncButton: some View {
        Group {
            if isBlocking {
                Button(action: {
                    profileManager.syncObservedBundlesToServer { ok in
                        NSLog(ok ? "[Server] Synced observed bundles to server" : "[Server] Sync failed")
                    }
                }) {
                    Image(systemName: "icloud.and.arrow.up")
                }
                .accessibilityLabel(Text("Sync Profile to Server"))
            } else {
                EmptyView()
            }
        }
    }

    private var serverStatusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(appBlocker.serverIsBlocking ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(appBlocker.serverIsBlocking ? "Server: Active" : "Server: Inactive")
                .font(.caption)
                .foregroundColor(.secondary)
            if let pid = appBlocker.serverProfileId {
                Text("Profile: \(pid.prefix(6))…")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
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

    private func maybePromptForProfile() {
        if let user = authManager.currentUser, (user.email == nil || user.email?.isEmpty == true) {
            emailInput = ""
            nameInput = user.name ?? ""
            showCompleteProfileSheet = true
        }
    }
    
}
