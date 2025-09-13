//
//  BrockerView.swift
//  PokeDaddy
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import CoreNFC
import SFSymbolsPicker
import FamilyControls
import ManagedSettings

struct PokeDaddyView: View {
    @EnvironmentObject private var appBlocker: AppBlocker
    @EnvironmentObject private var profileManager: ProfileManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var nfcReader = NFCReader()
    private let tagPhrase = "POKEDADDY-IS-GREAT"
    
    @State private var showWrongTagAlert = false
    @State private var showCreateTagAlert = false
    @State private var nfcWriteSuccess = false
    
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
                leading: signOutButton,
                trailing: createTagButton
            )
            .alert(isPresented: $showWrongTagAlert) {
                Alert(
                    title: Text("Not a Poke Daddy Tag"),
                    message: Text("You can create a new Poke Daddy tag using the + button"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("Create Poke Daddy Tag", isPresented: $showCreateTagAlert) {
                Button("Create") { createBrokerTag() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Do you want to create a new Poke Daddy tag?")
            }
            .alert("Tag Creation", isPresented: $nfcWriteSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(nfcWriteSuccess ? "Poke Daddy tag created successfully!" : "Failed to create Poke Daddy tag. Please try again.")
            }
        }
        .animation(.spring(), value: isBlocking)
    }
    
    @ViewBuilder
    private func blockOrUnblockButton(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            Text(isBlocking ? "Tap to unblock" : "Tap to block")
                .font(.caption)
                .opacity(0.75)
                .transition(.scale)
            
            Button(action: {
                withAnimation(.spring()) {
                    scanTag()
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
    
    private func scanTag() {
        nfcReader.scan { payload in
            if payload == tagPhrase {
                NSLog("Toggling block")
                // Use server-based blocking if we have a server profile, otherwise use local
                if let serverProfileId = profileManager.currentServerProfileId {
                    appBlocker.toggleServerBlocking(profileId: serverProfileId)
                } else {
                    appBlocker.toggleBlocking(for: profileManager.currentProfile)
                }
            } else {
                showWrongTagAlert = true
                NSLog("Wrong Tag!\nPayload: \(payload)")
            }
        }
    }
    
    private var createTagButton: some View {
        Button(action: {
            showCreateTagAlert = true
        }) {
            Image(systemName: "plus")
        }
        .disabled(!NFCNDEFReaderSession.readingAvailable)
    }
    
    private var signOutButton: some View {
        Button("Sign Out") {
            authManager.signOut()
        }
        .foregroundColor(.red)
    }
    
    private func createBrokerTag() {
        nfcReader.write(tagPhrase) { success in
            nfcWriteSuccess = !success
            showCreateTagAlert = false
        }
    }
}