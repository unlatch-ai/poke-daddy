//
//  APIService.swift
//  PokeDaddy
//
//  Created by Cascade on 13/09/2024.
//

import Foundation
import FamilyControls
import ManagedSettings

class APIService: ObservableObject {
    static let shared = APIService()
    
    // Production server
    private let baseURL = "https://poke-daddy.vercel.app"
    private var authToken: String?
    
    private init() {}
    
    // MARK: - Authentication
    
    func authenticate(appleUserID: String, email: String?, name: String?) async throws -> String {
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("PokeDaddy-iOS", forHTTPHeaderField: "User-Agent")
        
        var body: [String: Any] = ["apple_user_id": appleUserID]
        if let email = email, !email.isEmpty { body["email"] = email }
        if let name = name, !name.isEmpty { body["name"] = name }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[API] auth/register: no HTTPURLResponse")
            throw APIError.authenticationFailed
        }
        if httpResponse.statusCode != 200 {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("[API] auth/register failed: status=\(httpResponse.statusCode) body=\(bodyStr)")
            throw APIError.authenticationFailed
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        self.authToken = tokenResponse.access_token
        UserDefaults.standard.set(tokenResponse.access_token, forKey: "api_token")
        print("[API] auth/register: token saved (len=\(tokenResponse.access_token.count))")
        return tokenResponse.access_token
    }

    // Fetch the current user profile (requires auth token)
    func getCurrentUser() async throws -> CurrentUserResponse {
        guard let token = authToken else { throw APIError.notAuthenticated }
        let url = URL(string: "\(baseURL)/users/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        return try JSONDecoder().decode(CurrentUserResponse.self, from: data)
    }
    
    func loadStoredToken() {
        self.authToken = UserDefaults.standard.string(forKey: "api_token")
    }
    
    func signOut() {
        self.authToken = nil
        UserDefaults.standard.removeObject(forKey: "api_token")
    }
    
    // MARK: - Profile Management
    
    func getProfiles() async throws -> [ServerProfile] {
        guard let token = authToken else { throw APIError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/profiles")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode([ServerProfile].self, from: data)
    }
    
    func createProfile(name: String, icon: String, restrictedApps: [String], restrictedCategories: [String]) async throws -> ServerProfile {
        guard let token = authToken else { throw APIError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/profiles")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "name": name,
            "icon": icon,
            "restricted_apps": restrictedApps,
            "restricted_categories": restrictedCategories,
            "is_default": false
        ] as [String : Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode(ServerProfile.self, from: data)
    }
    
    func updateProfile(profileId: String, name: String?, icon: String?, restrictedApps: [String]?, restrictedCategories: [String]?) async throws -> ServerProfile {
        guard let token = authToken else { throw APIError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/profiles/\(profileId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let icon = icon { body["icon"] = icon }
        if let restrictedApps = restrictedApps { body["restricted_apps"] = restrictedApps }
        if let restrictedCategories = restrictedCategories { body["restricted_categories"] = restrictedCategories }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode(ServerProfile.self, from: data)
    }
    
    func deleteProfile(profileId: String) async throws {
        guard let token = authToken else { throw APIError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/profiles/\(profileId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
    }
    
    // MARK: - Blocking Control
    
    func toggleBlocking(profileId: String, action: String) async throws -> BlockingStatusResponse {
        guard let token = authToken else { throw APIError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/blocking/toggle")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "profile_id": profileId,
            "action": action
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode(BlockingStatusResponse.self, from: data)
    }
    
    func getBlockingStatus() async throws -> BlockingStatusResponse {
        guard let token = authToken else { throw APIError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/blocking/status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode(BlockingStatusResponse.self, from: data)
    }
    
    struct RestrictedAppsPayload: Codable {
        let restricted_apps: [String]
        let restricted_categories: [String]
    }

    func getRestrictedApps(profileId: String) async throws -> RestrictedAppsPayload {
        guard let token = authToken else { throw APIError.notAuthenticated }
        
        let url = URL(string: "\(baseURL)/profiles/\(profileId)/restricted-apps")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        return try JSONDecoder().decode(RestrictedAppsPayload.self, from: data)
    }
}

// MARK: - Data Models

struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
}

struct CurrentUserResponse: Codable {
    let id: String
    let email: String?
    let name: String?
    let apple_user_id: String
    let is_active: Bool
}

struct ServerProfile: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let restricted_apps: [String]
    let restricted_categories: [String]
    let is_default: Bool
    let created_at: String
    let updated_at: String
    
    // Convert to local Profile for compatibility
    func toLocalProfile() -> Profile {
        // Convert app bundle IDs to ApplicationTokens (this would need proper implementation)
        let appTokens: Set<ApplicationToken> = Set() // TODO: Implement conversion
        let categoryTokens: Set<ActivityCategoryToken> = Set() // TODO: Implement conversion
        
        return Profile(name: name, appTokens: appTokens, categoryTokens: categoryTokens, icon: icon)
    }
}

struct BlockingStatusResponse: Codable {
    let is_blocking: Bool
    let profile_id: String?
    let session_id: String?
    let started_at: String?
}

enum APIError: Error {
    case notAuthenticated
    case authenticationFailed
    case requestFailed
    case invalidResponse
    
    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "Not authenticated"
        case .authenticationFailed:
            return "Authentication failed"
        case .requestFailed:
            return "Request failed"
        case .invalidResponse:
            return "Invalid response"
        }
    }
}
