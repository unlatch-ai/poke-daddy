//
//  BrockerView.swift
//  PokeDaddy
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import SFSymbolsPicker
import FamilyControls
import ManagedSettings

struct PokeDaddyView: View {
    @EnvironmentObject private var appBlocker: AppBlocker
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var authManager: AuthenticationManager
    
    private var isBlocking : Bool {
        get {
            return appBlocker.isBlocking
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    VStack(spacing: 0) {
                        blockOrUnblockButton(geometry: geometry)
                        
                        if !isBlocking {
                            Divider()
                            
                            ProfilesPicker(profileManager: profileManager)
                                .frame(height: geometry.size.height / 2)
                                .transition(.move(edge: .bottom))
                        }
                    }
                    .background(isBlocking ? Color("BlockingBackground") : Color("NonBlockingBackground"))
                }
            }
            .navigationBarItems(
                leading: signOutButton
            )
        }
        .animation(.spring(), value: isBlocking)
    }
    
    @ViewBuilder
    private func blockOrUnblockButton(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Text(isBlocking ? "Apps are blocked - Server must unblock" : "Tap to start blocking")
                .font(.caption)
                .opacity(0.75)
                .transition(.scale)
            
            Button(action: {
                withAnimation(.spring()) {
                    toggleBlocking()
                }
            }) {
                Image(isBlocking ? "RedIcon" : "GreenIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: geometry.size.height / 3)
            }
            .transition(.scale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: isBlocking ? geometry.size.height : geometry.size.height / 2)
        .animation(.spring(), value: isBlocking)
    }
    
    private func toggleBlocking() {
        // Only allow starting blocking, not stopping
        if !isBlocking {
            NSLog("Starting block")
            // Use server-based blocking if we have a server profile, otherwise use local
            if let serverProfileId = profileManager.currentServerProfileId {
                appBlocker.startServerBlocking(profileId: serverProfileId)
            } else {
                appBlocker.startBlocking(for: profileManager.currentProfile)
            }
        }
    }
    
    private var signOutButton: some View {
        Button("Sign Out") {
            authManager.signOut()
        }
        .foregroundColor(.red)
    }
    
}