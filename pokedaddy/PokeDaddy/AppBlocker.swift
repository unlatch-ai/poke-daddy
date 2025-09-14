//
//  AppBlocker.swift
//  PokeDaddy
//
//  Created by Oz Tamir on 22/08/2024.
//
import SwiftUI
import ManagedSettings
import FamilyControls

class AppBlocker: ObservableObject {
    let store = ManagedSettingsStore()
    @Published var isBlocking = false
    @Published var isAuthorized = false
    // Server status indicator fields
    @Published var serverIsBlocking = false
    @Published var serverProfileId: String?
    @Published var serverSessionId: String?
    @Published var serverStartedAt: String?
    private var baseBlockedTokens: Set<ApplicationToken> = []
    
    private let apiService = APIService.shared
    
    init() {
        loadBlockingState()
        Task {
            await requestAuthorization()
            await checkServerBlockingStatus()
        }
    }
    
    func requestAuthorization() async {
        #if targetEnvironment(simulator)
        // Family Controls doesn't work in simulator, so we'll mock authorization
        print("Running in simulator - mocking Family Controls authorization")
        DispatchQueue.main.async {
            self.isAuthorized = true
        }
        #else
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
        } catch {
            print("Failed to request authorization: \(error)")
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
        }
        #endif
    }
    
    func startBlocking(for profile: Profile) {
        guard isAuthorized else {
            print("Not authorized to block apps")
            return
        }
        
        isBlocking = true
        saveBlockingState()
        baseBlockedTokens = profile.appTokens
        applyBlockingSettings(for: profile)
    }
    
    func startServerBlocking(profileId: String) {
        Task {
            do {
                let response = try await apiService.toggleBlocking(profileId: profileId, action: "start")
                
                DispatchQueue.main.async {
                    NSLog("[Server] toggle start response is_blocking=%@ profile_id=%@", String(response.is_blocking), response.profile_id ?? "nil")
                    self.isBlocking = response.is_blocking
                    self.saveBlockingState()
                    
                    if response.is_blocking {
                        self.applyServerBlockingSettings(profileId: profileId)
                    }
                }
            } catch {
                NSLog("[Server] Failed to start server blocking: %@", String(describing: error))
            }
        }
    }
    
    private func checkServerBlockingStatus() async {
        do {
            let status = try await apiService.getBlockingStatus()
            DispatchQueue.main.async {
                self.isBlocking = status.is_blocking
                self.serverIsBlocking = status.is_blocking
                self.serverProfileId = status.profile_id
                self.serverSessionId = status.session_id
                self.serverStartedAt = status.started_at
                self.saveBlockingState()
                
                if status.is_blocking, let profileId = status.profile_id {
                    self.applyServerBlockingSettings(profileId: profileId)
                } else {
                    self.clearBlockingSettings()
                }
            }
        } catch {
            print("Failed to check server blocking status: \(error)")
        }
    }

    // Public wrapper to allow UI to manually refresh blocking status
    func refreshBlockingStatus() {
        Task { await checkServerBlockingStatus() }
    }

    // Expose a simple refresh API for the UI to call after an unblock action completes
    func refreshServerRestrictions(profileId: String?) {
        guard isBlocking, let profileId = profileId else { return }
        applyServerBlockingSettings(profileId: profileId)
    }
    
    private func applyServerBlockingSettings(profileId: String) {
        Task {
            do {
                let payload = try await apiService.getRestrictedApps(profileId: profileId)
                let restrictedApps = Set(payload.restricted_apps)
                DispatchQueue.main.async {
                    #if targetEnvironment(simulator)
                    NSLog("[SIMULATOR] Server reports restricted apps: \(restrictedApps.count)")
                    #else
                    // If there are allowed bundles, do not overwrite the store state that the extension adjusted
                    if AppGroupBridge.allowedBundles().isEmpty {
                        self.store.shield.applications = self.baseBlockedTokens.isEmpty ? nil : self.baseBlockedTokens
                    } else {
                        NSLog("Skipping reset of blocked tokens due to allowed bundle exceptions present")
                    }
                    self.store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.none
                    #endif
                }
            } catch {
                print("Failed to get restricted apps: \(error)")
            }
        }
    }

    // Called after the SMS/LLM flow completes. If the candidate bundle is no longer in the server list,
    // record it as allowed so the next attempt can be excepted by the shield action extension.
    func markAllowedIfServerUnblocked(candidateBundle: String, profileId: String) {
        Task {
            do {
                let payload = try await apiService.getRestrictedApps(profileId: profileId)
                if !payload.restricted_apps.contains(candidateBundle) {
                    AppGroupBridge.addAllowedBundle(candidateBundle)
                }
                // Re-apply settings to ensure store is up to date
                DispatchQueue.main.async {
                    self.applyServerBlockingSettings(profileId: profileId)
                }
            } catch {
                print("Failed to refresh after unblock: \(error)")
            }
        }
    }
    
    private func clearBlockingSettings() {
        #if targetEnvironment(simulator)
        NSLog("[SIMULATOR] Mock clearing blocking settings")
        #else
        store.shield.applications = nil
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.none
        #endif
    }
    
    func applyBlockingSettings(for profile: Profile) {
        #if targetEnvironment(simulator)
        // Mock blocking behavior in simulator
        if isBlocking {
            NSLog("[SIMULATOR] Mock blocking \(profile.appTokens.count) apps")
        } else {
            NSLog("[SIMULATOR] Mock unblocking apps")
        }
        #else
        if isBlocking {
            NSLog("Blocking \(profile.appTokens.count) apps")
            store.shield.applications = profile.appTokens.isEmpty ? nil : profile.appTokens
            store.shield.applicationCategories = profile.categoryTokens.isEmpty ? ShieldSettings.ActivityCategoryPolicy.none : .specific(profile.categoryTokens)
        } else {
            store.shield.applications = nil
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.none
        }
        #endif
    }
    
    private func loadBlockingState() {
        isBlocking = UserDefaults.standard.bool(forKey: "isBlocking")
    }
    
    private func saveBlockingState() {
        UserDefaults.standard.set(isBlocking, forKey: "isBlocking")
    }
}
