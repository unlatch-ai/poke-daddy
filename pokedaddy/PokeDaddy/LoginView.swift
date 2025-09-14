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
                // Background now provided by Design.Background at app root
                VStack(spacing: 36) {
                    Spacer()
                    
                    // App logo and title
                    VStack(spacing: 16) {
                        Image("GreenIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 112, height: 112)
                        
                        VStack(spacing: 8) {
                            Text("Poke Daddy")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            
                            Text("Smart App Management")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Sign in section
                    VStack(spacing: 18) {
                        VStack(spacing: 12) {
                            Text("Welcome to Poke Daddy")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Sign in to sync your app restrictions across all your devices")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // Sign in with Apple button or simulator mock button
                        #if targetEnvironment(simulator)
                        Button(action: { authManager.signInWithApple() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "applelogo").foregroundColor(.white)
                                Text("Continue with Apple")
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(.horizontal, 28)
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
                        .frame(height: 52)
                        .padding(.horizontal, 28)
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
                                    .foregroundStyle(.secondary)
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
                    .glass(cornerRadius: 24)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Privacy note
                    VStack(spacing: 8) {
                        Text("Your privacy is protected")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        Text("We only store your app preferences. Your personal information stays with Apple.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
