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
            .navigationBarItems(leading: signOutButton)
        }
        .animation(.spring(), value: isBlocking)
        .onAppear(perform: checkForPendingMessage)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkForPendingMessage()
        }
        .sheet(item: $pendingDraft) { draft in
            MessageComposerView(draft: draft) {
                // finished composing; nothing else to do
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
    
    private func checkForPendingMessage() {
        if let pending = AppGroupBridge.consumePendingMessageRequest() {
            NSLog("[PokeDaddyApp] presenting SMS for bundleID=%@ name=%@", pending.bundleID, pending.appName ?? "nil")
            pendingDraft = MessageFactory.draftForBlockedApp(bundleID: pending.bundleID, appName: pending.appName)
        }
    }
    
}
