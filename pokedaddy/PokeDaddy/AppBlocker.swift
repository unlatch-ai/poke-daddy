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
        applyBlockingSettings(for: profile)
    }
    
    func startServerBlocking(profileId: String) {
        Task {
            do {
                let response = try await apiService.toggleBlocking(profileId: profileId, action: "start")
                
                DispatchQueue.main.async {
                    self.isBlocking = response.is_blocking
                    self.saveBlockingState()
                    
                    if response.is_blocking {
                        self.applyServerBlockingSettings(profileId: profileId)
                    }
                }
            } catch {
                print("Failed to start server blocking: \(error)")
            }
        }
    }
    
    private func checkServerBlockingStatus() async {
        do {
            let status = try await apiService.getBlockingStatus()
            DispatchQueue.main.async {
                self.isBlocking = status.is_blocking
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
    
    private func applyServerBlockingSettings(profileId: String) {
        Task {
            do {
                let restrictedApps = try await apiService.getRestrictedApps(profileId: profileId)
                DispatchQueue.main.async {
                    #if targetEnvironment(simulator)
                    NSLog("[SIMULATOR] Mock blocking \(restrictedApps.count) apps from server")
                    #else
                    // For now, we'll block all apps since we need to convert bundle IDs to ApplicationTokens
                    // In a real implementation, you'd need to map bundle IDs to ApplicationTokens
                    NSLog("Blocking \(restrictedApps.count) apps from server")
                    // TODO: Implement proper conversion from bundle IDs to ApplicationTokens
                    self.store.shield.applications = nil // Placeholder - needs proper implementation
                    self.store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.none
                    #endif
                }
            } catch {
                print("Failed to get restricted apps: \(error)")
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