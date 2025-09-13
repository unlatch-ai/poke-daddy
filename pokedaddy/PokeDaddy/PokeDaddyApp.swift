//
//  PokeDaddyApp.swift
//  PokeDaddy
//
//  Created by Oz Tamir on 19/08/2024.
//

import SwiftUI

@main
struct PokeDaddyApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var appBlocker = AppBlocker()
    @StateObject private var profileManager = ProfileManager()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    PokeDaddyView()
                        .environmentObject(appBlocker)
                        .environmentObject(profileManager)
                        .environmentObject(authManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        }
    }
}