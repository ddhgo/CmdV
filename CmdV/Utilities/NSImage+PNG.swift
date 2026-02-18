import AppKit

extension NSImage {
    func pngData() -> Data? {
        guard
            let tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiffRepresentation)
        else {
            return nil
        }

        return bitmapRep.representation(using: .png, properties: [:])
    }
}
