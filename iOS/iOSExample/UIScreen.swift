//
//  UIScreen.swift
//  iOSExample
//
//  Created by Om More on 17/10/25.
//
import SwiftUI

extension UIScreen {
    static let screenWidth = UIScreen.main.bounds.size.width
    static let screenHeight = UIScreen.main.bounds.size.height

    // Width percentage function
    static func w(_ percentage: CGFloat) -> CGFloat {
        return screenWidth * (percentage / 100)
    }

    // Height percentage function
    static func h(_ percentage: CGFloat) -> CGFloat {
        return screenHeight * (percentage / 100)
    }
}

extension Color {
    init(hexNumber: Int) {
        let r = Double((hexNumber & 0xFF0000) >> 16) / 255.0
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255.0
        let b = Double(hexNumber & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    /// Returns a lighter version of the color for use on dark backgrounds
    /// If the color is already light (brightness > 0.7), returns the original color
    func forDark() -> Color {
        let components = rgbComponents()
        let brightness = components.brightness

        // If already light enough, return as is
        if brightness > 0.7 {
            return self
        }

        // Lighten the color
        let lightenFactor = 1.8
        let newR = min(components.r * lightenFactor, 1.0)
        let newG = min(components.g * lightenFactor, 1.0)
        let newB = min(components.b * lightenFactor, 1.0)

        return Color(red: newR, green: newG, blue: newB)
    }

    /// Returns a darker version of the color for use on light backgrounds
    /// If the color is already dark (brightness < 0.3), returns the original color
    func forLight() -> Color {
        let components = rgbComponents()
        let brightness = components.brightness

        // If already dark enough, return as is
        if brightness < 0.3 {
            return self
        }

        // Darken the color
        let darkenFactor = 0.5
        let newR = components.r * darkenFactor
        let newG = components.g * darkenFactor
        let newB = components.b * darkenFactor

        return Color(red: newR, green: newG, blue: newB)
    }

    /// Automatically adjusts color based on current color scheme
    /// Lightens for dark mode, darkens for light mode
    func adaptive(for colorScheme: ColorScheme) -> Color {
        return colorScheme == .dark ? forDark() : forLight()
    }

    /// Helper to extract RGB components and calculate brightness
    private func rgbComponents() -> (r: Double, g: Double, b: Double, brightness: Double) {
        #if os(iOS) || os(watchOS) || os(tvOS)
            let uiColor = UIColor(self)
        #elseif os(macOS)
            let uiColor = NSColor(self)
        #endif

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        let brightness = (0.299 * r + 0.587 * g + 0.114 * b)

        return (Double(r), Double(g), Double(b), Double(brightness))
    }
}

extension ToolbarItem {
    func hiddenSharedBackground() -> some ToolbarContent {
        if #available(iOS 26.0, macOS 26.0, *) {
            return sharedBackgroundVisibility(.hidden)
        } else {
            return self
        }
    }
}
