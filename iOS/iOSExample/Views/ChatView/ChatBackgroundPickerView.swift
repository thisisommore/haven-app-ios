//
//  ChatBackgroundPickerView.swift
//  iOSExample
//

import SwiftUI
import PhotosUI

struct ChatBackgroundPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = ChatBackgroundSettings.shared
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var tempImageData: Data?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Preview
                    backgroundPreview
                        .padding(.top, 8)
                    
                    // Type selector
                    typeSelector
                    
                    // Options based on type
                    switch settings.backgroundType {
                    case .doodle:
                        doodleInfo
                    case .solidColor:
                        colorGrid
                    case .customImage:
                        imagePicker
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Chat Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(.haven)
                }
            }
        }
    }
    
    // MARK: - Preview
    private var backgroundPreview: some View {
        VStack(spacing: 12) {
            Text("Preview")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .overlay {
                        ChatBackgroundView()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .allowsHitTesting(false)
                    }
                
                // Mock messages
                VStack(spacing: 12) {
                    mockMessage("Hello! 👋", isOutgoing: false)
                    mockMessage("Hey, how are you?", isOutgoing: true)
                    mockMessage("Great! Love this background", isOutgoing: false)
                }
                .padding(20)
            }
            .frame(height: 200)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
    }
    
    private func mockMessage(_ text: String, isOutgoing: Bool) -> some View {
        HStack {
            if isOutgoing { Spacer() }
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isOutgoing ? Color.haven : Color(.systemGray5))
                .foregroundStyle(isOutgoing ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !isOutgoing { Spacer() }
        }
    }
    
    // MARK: - Type Selector
    private var typeSelector: some View {
        VStack(spacing: 12) {
            Text("Background Type")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                ForEach(ChatBackgroundType.allCases, id: \.self) { type in
                    typeButton(type)
                }
            }
        }
    }
    
    private func typeButton(_ type: ChatBackgroundType) -> some View {
        let isSelected = settings.backgroundType == type
        
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                settings.backgroundType = type
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.haven : Color(.systemGray5))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: isSelected ? Color.haven.opacity(0.3) : .clear, radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.haven : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Doodle Info
    private var doodleInfo: some View {
        VStack(spacing: 16) {
            Image("ChatDoodle")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.haven, lineWidth: 2)
                )
                .allowsHitTesting(false)
            
            Text("A playful doodle pattern that adds personality to your chats")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
    }
    
    // MARK: - Color Grid
    private var colorGrid: some View {
        VStack(spacing: 16) {
            Text("Choose a Color")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(SolidBackgroundColor.presets) { preset in
                    colorCell(preset)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
    }
    
    private func colorCell(_ preset: SolidBackgroundColor) -> some View {
        let isSelected = settings.selectedColorId == preset.id
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                settings.selectedColorId = preset.id
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if preset.isDynamic {
                        // Split circle for dynamic theme color
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(.systemBackground), Color(.systemGray6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemGray3), lineWidth: 1)
                            )
                        
                        // Sun/Moon icon
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 22))
                            .foregroundStyle(.primary)
                    } else {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 52, height: 52)
                            .shadow(color: preset.color.opacity(0.4), radius: isSelected ? 8 : 0, y: 2)
                    }
                    
                    if isSelected {
                        Circle()
                            .stroke(Color.haven, lineWidth: 3)
                            .frame(width: 52, height: 52)
                        
                        if !preset.isDynamic {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                Text(preset.name)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }
    
    // MARK: - Image Picker
    private var imagePicker: some View {
        VStack(spacing: 16) {
            if let data = settings.customImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.haven, lineWidth: 2)
                    )
            }
            
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: settings.customImageData == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 18))
                    Text(settings.customImageData == nil ? "Select from Library" : "Change Image")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.haven)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            withAnimation {
                                settings.customImageData = data
                            }
                        }
                    }
                }
            }
            
            if settings.customImageData != nil {
                Button(role: .destructive) {
                    withAnimation {
                        settings.customImageData = nil
                        selectedPhoto = nil
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text("Remove Image")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Background View (Used in ChatView)
struct ChatBackgroundView: View {
    @ObservedObject private var settings = ChatBackgroundSettings.shared
    
    var body: some View {
        Group {
            switch settings.backgroundType {
            case .doodle:
                Image("ChatDoodle")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.5)
                    
            case .solidColor:
                settings.selectedColor.color
                
            case .customImage:
                if let data = settings.customImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(0.7)
                } else {
                    Color.appBackground
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

#Preview {
    ChatBackgroundPickerView()
}

