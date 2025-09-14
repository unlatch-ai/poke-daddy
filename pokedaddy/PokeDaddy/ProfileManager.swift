//
//  ProfileManager.swift
//  PokeDaddy
//
//  Created by Oz Tamir on 22/08/2024.
//

import Foundation
import FamilyControls
import ManagedSettings
import SwiftUI
 

class ProfileManager: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var currentProfileId: UUID?
    @Published var serverProfiles: [ServerProfile] = []
    @Published var currentServerProfileId: String?
    
    private let apiService = APIService.shared
    
    init() {
        loadProfiles()
        ensureDefaultProfile()
        loadServerProfiles()
    }
    
    var currentProfile: Profile {
        (profiles.first(where: { $0.id == currentProfileId }) ?? profiles.first(where: { $0.name == "Default" }))!
    }
    
    var currentServerProfile: ServerProfile? {
        serverProfiles.first(where: { $0.id == currentServerProfileId })
    }
    
    func loadProfiles() {
        if let savedProfiles = UserDefaults.standard.data(forKey: "savedProfiles"),
           let decodedProfiles = try? JSONDecoder().decode([Profile].self, from: savedProfiles) {
            profiles = decodedProfiles
        } else {
            // Create a default profile if no profiles are saved
            let defaultProfile = Profile(name: "Default", appTokens: [], categoryTokens: [], icon: "bell.slash")
            profiles = [defaultProfile]
            currentProfileId = defaultProfile.id
        }
        
        if let savedProfileId = UserDefaults.standard.string(forKey: "currentProfileId"),
           let uuid = UUID(uuidString: savedProfileId) {
            currentProfileId = uuid
            NSLog("Found currentProfile: \(uuid)")
        } else {
            currentProfileId = profiles.first?.id
            NSLog("No stored ID, using \(currentProfileId?.uuidString ?? "NONE")")
        }
    }
    
    func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: "savedProfiles")
        }
        UserDefaults.standard.set(currentProfileId?.uuidString, forKey: "currentProfileId")
    }
    
    func addProfile(name: String, icon: String = "bell.slash") {
        let newProfile = Profile(name: name, appTokens: [], categoryTokens: [], icon: icon)
        profiles.append(newProfile)
        currentProfileId = newProfile.id
        saveProfiles()
    }
    
    func addProfile(newProfile: Profile) {
        profiles.append(newProfile)
        currentProfileId = newProfile.id
        saveProfiles()
    }
    
    // MARK: - Server Profile Management
    
    func loadServerProfiles() {
        // Load stored server profile ID
        if let storedId = UserDefaults.standard.string(forKey: "currentServerProfileId") {
            currentServerProfileId = storedId
        }
        
        // Fetch profiles from server
        Task {
            do {
                let profiles = try await apiService.getProfiles()
                DispatchQueue.main.async {
                    self.serverProfiles = profiles
                    if self.currentServerProfileId == nil, let defaultProfile = profiles.first(where: { $0.is_default }) {
                        self.currentServerProfileId = defaultProfile.id
                        self.saveServerProfileId()
                    }
                }
            } catch {
                print("Failed to load server profiles: \(error)")
            }
        }
    }

    // Ensure we have a server profile id; if missing, fetch profiles and pick default, then return it.
    func ensureServerProfileIdReady(completion: @escaping (String?) -> Void) {
        if let id = currentServerProfileId { completion(id); return }
        Task {
            do {
                let profiles = try await apiService.getProfiles()
                DispatchQueue.main.async {
                    self.serverProfiles = profiles
                    if self.currentServerProfileId == nil, let defaultProfile = profiles.first(where: { $0.is_default }) ?? profiles.first {
                        self.currentServerProfileId = defaultProfile.id
                        self.saveServerProfileId()
                    }
                    completion(self.currentServerProfileId)
                }
            } catch {
                print("Failed to load server profiles: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    // Merge observed bundle IDs (from shield attempts) into the current server profile's restricted_apps
    func syncObservedBundlesToServer(onComplete: @escaping (Bool) -> Void) {
        guard let currentId = currentServerProfileId else {
            onComplete(false); return
        }
        let attempts = AppGroupBridge.fetchAttempts(max: 500)
        var observed = Set(attempts.map { $0.bundleID })
        observed.remove("")
        observed.remove("unknown.bundle")
        observed.remove("uknown.bundle")
        
        Task {
            do {
                let profiles = try await apiService.getProfiles()
                guard let serverProfile = profiles.first(where: { $0.id == currentId }) else { onComplete(false); return }
                let existing = Set(serverProfile.restricted_apps)
                let merged = Array(existing.union(observed))
                _ = try await apiService.updateProfile(
                    profileId: serverProfile.id,
                    name: nil,
                    icon: nil,
                    restrictedApps: merged,
                    restrictedCategories: nil
                )
                DispatchQueue.main.async { onComplete(true) }
            } catch {
                print("Failed to sync observed bundles: \(error)")
                DispatchQueue.main.async { onComplete(false) }
            }
        }
    }
    
    func createServerProfile(name: String, icon: String, restrictedApps: [String], restrictedCategories: [String]) {
        Task {
            do {
                let newProfile = try await apiService.createProfile(
                    name: name,
                    icon: icon,
                    restrictedApps: restrictedApps,
                    restrictedCategories: restrictedCategories
                )
                DispatchQueue.main.async {
                    self.serverProfiles.append(newProfile)
                    self.currentServerProfileId = newProfile.id
                    self.saveServerProfileId()
                }
            } catch {
                print("Failed to create server profile: \(error)")
            }
        }
    }
    
    func updateServerProfile(profileId: String, name: String?, icon: String?, restrictedApps: [String]?, restrictedCategories: [String]?) {
        Task {
            do {
                let updatedProfile = try await apiService.updateProfile(
                    profileId: profileId,
                    name: name,
                    icon: icon,
                    restrictedApps: restrictedApps,
                    restrictedCategories: restrictedCategories
                )
                DispatchQueue.main.async {
                    if let index = self.serverProfiles.firstIndex(where: { $0.id == profileId }) {
                        self.serverProfiles[index] = updatedProfile
                    }
                }
            } catch {
                print("Failed to update server profile: \(error)")
            }
        }
    }
    
    func deleteServerProfile(profileId: String) {
        Task {
            do {
                try await apiService.deleteProfile(profileId: profileId)
                DispatchQueue.main.async {
                    self.serverProfiles.removeAll { $0.id == profileId }
                    if self.currentServerProfileId == profileId {
                        self.currentServerProfileId = self.serverProfiles.first?.id
                        self.saveServerProfileId()
                    }
                }
            } catch {
                print("Failed to delete server profile: \(error)")
            }
        }
    }
    
    func setCurrentServerProfile(id: String) {
        if serverProfiles.contains(where: { $0.id == id }) {
            currentServerProfileId = id
            saveServerProfileId()
        }
    }
    
    private func saveServerProfileId() {
        UserDefaults.standard.set(currentServerProfileId, forKey: "currentServerProfileId")
    }
    
    func updateCurrentProfile(appTokens: Set<ApplicationToken>, categoryTokens: Set<ActivityCategoryToken>) {
        if let index = profiles.firstIndex(where: { $0.id == currentProfileId }) {
            profiles[index].appTokens = appTokens
            profiles[index].categoryTokens = categoryTokens
            saveProfiles()
        }
    }
    
    func setCurrentProfile(id: UUID) {
        if profiles.contains(where: { $0.id == id }) {
            currentProfileId = id
            NSLog("New Current Profile: \(id)")
            saveProfiles()
        }
    }
    
    func deleteProfile(withId id: UUID) {
//        guard !profiles.first(where: { $0.id == id })?.isDefault ?? false else {
//            // Don't delete the default profile
//            return
//        }
        
        profiles.removeAll { $0.id == id }
        
        if currentProfileId == id {
            currentProfileId = profiles.first?.id
        }
        
        saveProfiles()
    }

    func deleteAllNonDefaultProfiles() {
        profiles.removeAll { !$0.isDefault }
        
        if !profiles.contains(where: { $0.id == currentProfileId }) {
            currentProfileId = profiles.first?.id
        }
        
        saveProfiles()
    }
    
    func updateCurrentProfile(name: String, iconName: String) {
        if let index = profiles.firstIndex(where: { $0.id == currentProfileId }) {
            profiles[index].name = name
            profiles[index].icon = iconName
            saveProfiles()
        }
    }

    func deleteCurrentProfile() {
        profiles.removeAll { $0.id == currentProfileId }
        if let firstProfile = profiles.first {
            currentProfileId = firstProfile.id
        }
        saveProfiles()
    }
    
    func updateProfile(
        id: UUID,
        name: String? = nil,
        appTokens: Set<ApplicationToken>? = nil,
        categoryTokens: Set<ActivityCategoryToken>? = nil,
        icon: String? = nil
    ) {
        if let index = profiles.firstIndex(where: { $0.id == id }) {
            if let name = name {
                profiles[index].name = name
            }
            if let appTokens = appTokens {
                profiles[index].appTokens = appTokens
            }
            if let categoryTokens = categoryTokens {
                profiles[index].categoryTokens = categoryTokens
            }
            if let icon = icon {
                profiles[index].icon = icon
            }
            
            if currentProfileId == id {
                currentProfileId = profiles[index].id
            }
            
            saveProfiles()
        }
    }
    
    private func ensureDefaultProfile() {
        if profiles.isEmpty {
            let defaultProfile = Profile(name: "Default", appTokens: [], categoryTokens: [], icon: "bell.slash")
            profiles.append(defaultProfile)
            currentProfileId = defaultProfile.id
            saveProfiles()
        } else if currentProfileId == nil {
            if let defaultProfile = profiles.first(where: { $0.name == "Default" }) {
                currentProfileId = defaultProfile.id
            } else {
                currentProfileId = profiles.first?.id
            }
            saveProfiles()
        }
    }
}

struct Profile: Identifiable, Codable {
    let id: UUID
    var name: String
    var appTokens: Set<ApplicationToken>
    var categoryTokens: Set<ActivityCategoryToken>
    var icon: String // New property for icon

    var isDefault: Bool {
        name == "Default"
    }

    // New initializer to support default icon
    init(name: String, appTokens: Set<ApplicationToken>, categoryTokens: Set<ActivityCategoryToken>, icon: String = "bell.slash") {
        self.id = UUID()
        self.name = name
        self.appTokens = appTokens
        self.categoryTokens = categoryTokens
        self.icon = icon
    }
}
