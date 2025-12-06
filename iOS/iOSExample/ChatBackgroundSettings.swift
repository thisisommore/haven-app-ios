//
//  ChatBackgroundSettings.swift
//  iOSExample
//

import SwiftUI

enum ChatBackgroundType: String, Codable, CaseIterable {
    case doodle = "doodle"
    case solidColor = "solid"
    case customImage = "custom"
    
    var displayName: String {
        switch self {
        case .doodle: return "Doodle Pattern"
        case .solidColor: return "Solid Color"
        case .customImage: return "Custom Image"
        }
    }
    
    var icon: String {
        switch self {
        case .doodle: return "scribble.variable"
        case .solidColor: return "paintpalette.fill"
        case .customImage: return "photo.fill"
        }
    }
}

struct SolidBackgroundColor: Codable, Identifiable, Equatable {
    let id: String
    let red: Double
    let green: Double
    let blue: Double
    let name: String
    let isDynamic: Bool
    
    init(id: String, red: Double, green: Double, blue: Double, name: String, isDynamic: Bool = false) {
        self.id = id
        self.red = red
        self.green = green
        self.blue = blue
        self.name = name
        self.isDynamic = isDynamic
    }
    
    var color: Color {
        if isDynamic {
            return Color.appBackground
        }
        return Color(red: red, green: green, blue: blue)
    }
    
    static let presets: [SolidBackgroundColor] = [
        SolidBackgroundColor(id: "auto", red: 0, green: 0, blue: 0, name: "Auto", isDynamic: true),
        SolidBackgroundColor(id: "midnight", red: 0.05, green: 0.05, blue: 0.12, name: "Midnight"),
        SolidBackgroundColor(id: "slate", red: 0.15, green: 0.18, blue: 0.22, name: "Slate"),
        SolidBackgroundColor(id: "charcoal", red: 0.12, green: 0.12, blue: 0.12, name: "Charcoal"),
        SolidBackgroundColor(id: "ocean", red: 0.08, green: 0.15, blue: 0.25, name: "Ocean"),
        SolidBackgroundColor(id: "forest", red: 0.06, green: 0.18, blue: 0.14, name: "Forest"),
        SolidBackgroundColor(id: "wine", red: 0.22, green: 0.08, blue: 0.12, name: "Wine"),
        SolidBackgroundColor(id: "lavender", red: 0.88, green: 0.85, blue: 0.95, name: "Lavender"),
        SolidBackgroundColor(id: "cream", red: 0.98, green: 0.96, blue: 0.90, name: "Cream"),
        SolidBackgroundColor(id: "mint", red: 0.88, green: 0.96, blue: 0.92, name: "Mint"),
        SolidBackgroundColor(id: "blush", red: 0.98, green: 0.90, blue: 0.92, name: "Blush"),
        SolidBackgroundColor(id: "sky", red: 0.90, green: 0.95, blue: 0.98, name: "Sky"),
        SolidBackgroundColor(id: "sand", red: 0.96, green: 0.93, blue: 0.86, name: "Sand"),
    ]
}

class ChatBackgroundSettings: ObservableObject {
    static let shared = ChatBackgroundSettings()
    
    private let typeKey = "chatBackgroundType"
    private let colorIdKey = "chatBackgroundColorId"
    private let customImageKey = "chatBackgroundCustomImage"
    
    @Published var backgroundType: ChatBackgroundType {
        didSet {
            UserDefaults.standard.set(backgroundType.rawValue, forKey: typeKey)
        }
    }
    
    @Published var selectedColorId: String {
        didSet {
            UserDefaults.standard.set(selectedColorId, forKey: colorIdKey)
        }
    }
    
    @Published var customImageData: Data? {
        didSet {
            UserDefaults.standard.set(customImageData, forKey: customImageKey)
        }
    }
    
    var selectedColor: SolidBackgroundColor {
        SolidBackgroundColor.presets.first { $0.id == selectedColorId } ?? SolidBackgroundColor.presets[0]
    }
    
    init() {
        if let typeRaw = UserDefaults.standard.string(forKey: typeKey),
           let type = ChatBackgroundType(rawValue: typeRaw) {
            self.backgroundType = type
        } else {
            self.backgroundType = .solidColor
        }
        
        self.selectedColorId = UserDefaults.standard.string(forKey: colorIdKey) ?? "auto"
        self.customImageData = UserDefaults.standard.data(forKey: customImageKey)
    }
}

