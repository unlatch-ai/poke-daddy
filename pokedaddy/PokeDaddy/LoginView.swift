//
//  LoginView.swift
//  PokeDaddy
//
//  Created by Cascade on 13/09/2024.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color("NonBlockingBackground"),
                        Color("BlockingBackground").opacity(0.3)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // App logo and title
                    VStack(spacing: 20) {
                        Image("GreenIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                        
                        VStack(spacing: 8) {
                            Text("Poke Daddy")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Smart App Management")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Spacer()
                    
                    // Sign in section
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            Text("Welcome to Poke Daddy")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Sign in to sync your app restrictions across all your devices")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // Sign in with Apple button or simulator mock button
                        #if targetEnvironment(simulator)
                        Button(action: {
                            authManager.signInWithApple()
                        }) {
                            HStack {
                                Image(systemName: "applelogo")
                                    .foregroundColor(.white)
                                Text("Continue with Apple")
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 40)
                        #else
                        SignInWithAppleButton(
                            onRequest: { request in
                                // This is handled by AuthenticationManager
                            },
                            onCompletion: { _ in
                                // This is handled by AuthenticationManager
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .padding(.horizontal, 40)
                        .onTapGesture {
                            authManager.signInWithApple()
                        }
                        #endif
                        
                        // Loading indicator
                        if authManager.isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Signing in...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 8)
                        }
                        
                        // Error message
                        if let errorMessage = authManager.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer()
                    
                    // Privacy note
                    VStack(spacing: 8) {
                        Text("Your privacy is protected")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("We only store your app preferences. Your personal information stays with Apple.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}
