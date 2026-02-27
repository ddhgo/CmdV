import AppKit
import SwiftUI

enum CmdVTheme {
    enum Colors {
        static var controlSurfaceNSColor: NSColor {
            adaptiveNSColor(
                dark: NSColor(srgbRed: 0.20, green: 0.21, blue: 0.24, alpha: 0.8),
                light: NSColor(srgbRed: 0.97, green: 0.98, blue: 0.99, alpha: 0.92)
            )
        }

        static var surfaceStrokeNSColor: NSColor {
            adaptiveNSColor(
                dark: NSColor.white.withAlphaComponent(0.20),
                light: NSColor.black.withAlphaComponent(0.08)
            )
        }

        static var rowSurfaceNSColor: NSColor {
            adaptiveNSColor(
                dark: NSColor(srgbRed: 0.21, green: 0.22, blue: 0.25, alpha: 0.86),
                light: NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 1)
            )
        }

        static var rowSelectedSurfaceNSColor: NSColor {
            adaptiveNSColor(
                dark: NSColor(srgbRed: 0.31, green: 0.35, blue: 0.42, alpha: 0.54),
                light: NSColor(srgbRed: 0.42, green: 0.50, blue: 0.62, alpha: 0.24)
            )
        }

        static var rowSelectedStrokeNSColor: NSColor {
            adaptiveNSColor(
                dark: NSColor(srgbRed: 0.48, green: 0.56, blue: 0.68, alpha: 0.9),
                light: NSColor(srgbRed: 0.34, green: 0.45, blue: 0.60, alpha: 0.86)
            )
        }

        static var statusBarSwitchOffTrackColor: NSColor {
            adaptiveNSColor(
                dark: NSColor(srgbRed: 0.26, green: 0.27, blue: 0.31, alpha: 1),
                light: NSColor(srgbRed: 0.74, green: 0.75, blue: 0.78, alpha: 1)
            )
        }

        static var statusBarSwitchKnobColor: NSColor {
            adaptiveNSColor(
                dark: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                light: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1)
            )
        }

        static var statusBarSwitchKnobBorderColor: NSColor {
            adaptiveNSColor(
                dark: NSColor.clear,
                light: NSColor.clear
            )
        }

        static var windowSurface: Color {
            adaptiveColor(
                dark: NSColor(srgbRed: 0.18, green: 0.18, blue: 0.20, alpha: 1),
                light: NSColor(srgbRed: 0.98, green: 0.99, blue: 1.0, alpha: 0.94)
            )
        }

        static var cardSurface: Color {
            adaptiveColor(
                dark: NSColor(srgbRed: 0.23, green: 0.24, blue: 0.26, alpha: 1),
                light: NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 0.98)
            )
        }

        static var controlSurface: Color {
            adaptiveColor(
                dark: NSColor(srgbRed: 0.20, green: 0.21, blue: 0.24, alpha: 0.8),
                light: NSColor(srgbRed: 0.97, green: 0.98, blue: 0.99, alpha: 0.92)
            )
        }

        static var surfaceStroke: Color {
            adaptiveColor(
                dark: NSColor.white.withAlphaComponent(0.20),
                light: NSColor.black.withAlphaComponent(0.08)
            )
        }

        static var subtleStroke: Color {
            adaptiveColor(
                dark: NSColor.white.withAlphaComponent(0.10),
                light: NSColor.black.withAlphaComponent(0.10)
            )
        }

        static var rowSurface: Color {
            adaptiveColor(
                dark: NSColor(srgbRed: 0.21, green: 0.22, blue: 0.25, alpha: 0.86),
                light: NSColor(srgbRed: 0.98, green: 0.98, blue: 0.99, alpha: 1)
            )
        }

        static var rowSelectedSurface: Color {
            adaptiveColor(
                dark: NSColor(srgbRed: 0.31, green: 0.35, blue: 0.42, alpha: 0.54),
                light: NSColor(srgbRed: 0.42, green: 0.50, blue: 0.62, alpha: 0.24)
            )
        }

        static var rowSelectedStroke: Color {
            adaptiveColor(
                dark: NSColor(srgbRed: 0.48, green: 0.56, blue: 0.68, alpha: 0.9),
                light: NSColor(srgbRed: 0.34, green: 0.45, blue: 0.60, alpha: 0.86)
            )
        }
    }

    private static func adaptiveColor(dark: NSColor, light: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return dark
                }

                return light
            }
        )
    }

    private static func adaptiveNSColor(dark: NSColor, light: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return dark
            }

            return light
        }
    }
}
