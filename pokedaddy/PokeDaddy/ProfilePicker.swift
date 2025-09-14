//
//  ProfilePicker.swift
//  PokeDaddy
//
//  Created by Oz Tamir on 25/08/2024.
//

import SwiftUI
import FamilyControls

struct ProfilesPicker: View {
    @ObservedObject var profileManager: ProfileManager
    @State private var showAddProfileView = false
    @State private var editingProfile: Profile?
    
    var body: some View {
        VStack {
            Text("Profiles")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top)
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                    ForEach(profileManager.profiles) { profile in
                        ProfileCell(profile: profile, isSelected: profile.id == profileManager.currentProfileId)
                            .onTapGesture {
                                profileManager.setCurrentProfile(id: profile.id)
                            }
                            .onLongPressGesture {
                                editingProfile = profile
                            }
                    }
                    
                    ProfileCellBase(name: "New...", icon: "plus", appsBlocked: nil, categoriesBlocked: nil, isSelected: false, isDashed: true, hasDivider: false)
                        .onTapGesture {
                            showAddProfileView = true
                        }
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
            
            Text("Long press on a profile to edit...")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.bottom, 8)
        }
        .background(Color.clear)
        .sheet(item: $editingProfile) { profile in
            ProfileFormView(profile: profile, profileManager: profileManager) {
                editingProfile = nil
            }
        }
        .sheet(isPresented: $showAddProfileView) {
            ProfileFormView(profileManager: profileManager) {
                showAddProfileView = false
            }
        }
    }
}

struct ProfileCellBase: View {
    let name: String
    let icon: String
    let appsBlocked: Int?
    let categoriesBlocked: Int?
    let isSelected: Bool
    var isDashed: Bool = false
    var hasDivider: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .foregroundStyle(isSelected ? Design.brandAccent : .primary)
            if hasDivider { Divider().padding(.horizontal, 4) }
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            if let apps = appsBlocked, let categories = categoriesBlocked {
                Text("A: \(apps) | C: \(categories)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 96, height: 96)
        .padding(6)
        .glass(cornerRadius: 16)
        .modifier(isSelected ? Design.GradientStroke(cornerRadius: 16, lineWidth: 2) : Design.GradientStroke(cornerRadius: 16, lineWidth: isDashed ? 1 : 0))
    }
}

struct ProfileCell: View {
    let profile: Profile
    let isSelected: Bool

    var body: some View {
        ProfileCellBase(
            name: profile.name,
            icon: profile.icon,
            appsBlocked: profile.appTokens.count,
            categoriesBlocked: profile.categoryTokens.count,
            isSelected: isSelected
        )
    }
}
