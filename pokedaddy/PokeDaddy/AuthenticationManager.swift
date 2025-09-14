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
    @Published var needsProfileCompletion = false
    
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
        // Check if blocking is active before allowing sign out
        // This prevents users from bypassing restrictions by signing out
        let isBlocking = UserDefaults.standard.bool(forKey: "isBlocking")
        if isBlocking {
            print("Cannot sign out while blocking is active - server must end blocking session first")
            return
        }
        
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

            // Fallback: if no API token is stored yet, register with server using stored user info
            if UserDefaults.standard.string(forKey: "api_token") == nil {
                Task {
                    do {
                        _ = try await self.apiService.authenticate(
                            appleUserID: user.id,
                            email: user.email,
                            name: user.name
                        )
                        if let serverUser = try? await self.apiService.getCurrentUser() {
                            let updated = User(id: serverUser.id,
                                               email: serverUser.email,
                                               name: serverUser.name,
                                               allowedApps: user.allowedApps,
                                               profiles: user.profiles)
                            self.saveUser(updated)
                            DispatchQueue.main.async { self.currentUser = updated }
                        }
                        DispatchQueue.main.async {
                            self.needsProfileCompletion = (self.currentUser?.email == nil || self.currentUser?.email?.isEmpty == true)
                        }
                    } catch {
                        print("Failed to authenticate with server using stored user: \(error)")
                    }
                }
            }
        }
    }

    // Allow user to supply email/name after Apple returns nil; also backfill server via /auth/register
    func completeProfile(email: String?, name: String?) {
        guard var user = currentUser else { return }
        user.email = email
        user.name = name
        saveUser(user)
        DispatchQueue.main.async {
            self.currentUser = user
            self.needsProfileCompletion = (email == nil || email?.isEmpty == true)
        }

        Task {
            do {
                _ = try await apiService.authenticate(appleUserID: user.id, email: email, name: name)
                if let serverUser = try? await apiService.getCurrentUser() {
                    let updated = User(id: serverUser.id,
                                       email: serverUser.email,
                                       name: serverUser.name,
                                       allowedApps: user.allowedApps,
                                       profiles: user.profiles)
                    self.saveUser(updated)
                    DispatchQueue.main.async { self.currentUser = updated }
                }
            } catch {
                print("Failed to backfill profile to server: \(error)")
            }
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
            // Apple only provides email/name on the first authorization. Fallback to previously stored values if missing.
            let email = appleIDCredential.email ?? (UserDefaults.standard.data(forKey: "currentUser").flatMap { try? JSONDecoder().decode(User.self, from: $0) }?.email)
            let fullName = appleIDCredential.fullName
            // Compose name from Apple; if unavailable, fallback to stored name
            let composedName = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let storedName = UserDefaults.standard.data(forKey: "currentUser").flatMap { try? JSONDecoder().decode(User.self, from: $0) }?.name
            let name = composedName.isEmpty ? storedName : composedName
            
            let user = User(
                id: userID,
                email: email,
                name: (name?.isEmpty ?? true) ? nil : name,
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
                        if let serverUser = try? await self.apiService.getCurrentUser() {
                            let updated = User(id: serverUser.id,
                                               email: serverUser.email,
                                               name: serverUser.name,
                                               allowedApps: user.allowedApps,
                                               profiles: user.profiles)
                            self.saveUser(updated)
                            DispatchQueue.main.async { self.currentUser = updated }
                        }
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
    var email: String?
    var name: String?
    var allowedApps: [String]
    var profiles: [Profile]
}
