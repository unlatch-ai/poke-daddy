//
//  AuthenticationManager.swift
//  PokeDaddy
//
//  Created by Cascade on 13/09/2024.
//

import SwiftUI
import AuthenticationServices
import CryptoKit

#if targetEnvironment(simulator)
import Foundation
#endif

class AuthenticationManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    override init() {
        super.init()
        checkAuthenticationState()
    }
    
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        #if targetEnvironment(simulator)
        // Mock authentication for simulator
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let mockUser = User(
                id: "simulator_user_123",
                email: "simulator@example.com",
                name: "Simulator User",
                allowedApps: [],
                profiles: []
            )
            
            self.currentUser = mockUser
            self.isAuthenticated = true
            self.isLoading = false
            self.saveUser(mockUser)
            
            // Authenticate with server
            Task {
                do {
                    _ = try await self.apiService.authenticate(
                        appleUserID: "simulator_user_123",
                        email: "simulator@example.com",
                        name: "Simulator User"
                    )
                } catch {
                    print("Failed to authenticate with server: \(error)")
                }
            }
        }
        #else
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // Generate a nonce for security
        let nonce = randomNonceString()
        request.nonce = sha256(nonce)
        
        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = self
        authController.presentationContextProvider = self
        authController.performRequests()
        #endif
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        
        // Clear stored user data
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "userID")
        
        // Sign out from API service
        apiService.signOut()
    }
    
    private func checkAuthenticationState() {
        // Check if user is already signed in
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isAuthenticated = true
            
            // Load stored API token
            apiService.loadStoredToken()
        }
    }
    
    private func saveUser(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
            UserDefaults.standard.set(user.id, forKey: "userID")
        }
    }
    
    // MARK: - Security helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        isLoading = false
        
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userID = appleIDCredential.user
            let email = appleIDCredential.email
            let fullName = appleIDCredential.fullName
            
            let name = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            
            let user = User(
                id: userID,
                email: email,
                name: name.isEmpty ? nil : name,
                allowedApps: [],
                profiles: []
            )
            
            DispatchQueue.main.async {
                self.currentUser = user
                self.isAuthenticated = true
                self.saveUser(user)
                
                // Authenticate with server
                Task {
                    do {
                        _ = try await self.apiService.authenticate(
                            appleUserID: userID,
                            email: email,
                            name: name
                        )
                    } catch {
                        print("Failed to authenticate with server: \(error)")
                    }
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                errorMessage = "Sign in was canceled"
            case .failed:
                errorMessage = "Sign in failed"
            case .invalidResponse:
                errorMessage = "Invalid response from Apple"
            case .notHandled:
                errorMessage = "Sign in not handled"
            case .unknown:
                errorMessage = "Unknown error occurred"
            @unknown default:
                errorMessage = "Unknown error occurred"
            }
        } else {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - User Model
struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let name: String?
    var allowedApps: [String]
    var profiles: [Profile]
}
