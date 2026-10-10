import AppKit
import Foundation

func generateAppIcon() {
    let sizes = [16, 32, 64, 128, 256, 512, 1024]
    let iconsetDir = "Resources/AppIcon.iconset"
    
    try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
    
    for size in sizes {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        
        // Background rounded squircle gradient
        let cornerRadius = Double(size) * 0.22
        let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: Double(size) * 0.05, dy: Double(size) * 0.05),
                                  xRadius: cornerRadius,
                                  yRadius: cornerRadius)
        
        let gradient = NSGradient(startingColor: NSColor(red: 0.10, green: 0.55, blue: 0.95, alpha: 1.0),
                                  endingColor: NSColor(red: 0.35, green: 0.15, blue: 0.85, alpha: 1.0))
        gradient?.draw(in: bgPath, angle: -45)
        
        // Inner subtle border
        NSColor(white: 1.0, alpha: 0.25).setStroke()
        bgPath.lineWidth = max(1.0, Double(size) * 0.02)
        bgPath.stroke()
        
        // Draw Cursor / Lightning click icon
        let center = NSPoint(x: Double(size) * 0.5, y: Double(size) * 0.5)
        let iconScale = Double(size) / 100.0
        
        // Concentric radar click rings
        for ring in 1...2 {
            let ringRadius = Double(ring) * 16.0 * iconScale
            let ringPath = NSBezierPath(arcCenter: center, radius: ringRadius, startAngle: 0, endAngle: 360)
            NSColor(white: 1.0, alpha: 0.3 / Double(ring)).setStroke()
            ringPath.lineWidth = 3.0 * iconScale
            ringPath.stroke()
        }
        
        // Sleek Mouse Pointer Path
        let cursorPath = NSBezierPath()
        cursorPath.move(to: NSPoint(x: center.x - 18 * iconScale, y: center.y + 26 * iconScale))
        cursorPath.line(to: NSPoint(x: center.x + 18 * iconScale, y: center.y - 4 * iconScale))
        cursorPath.line(to: NSPoint(x: center.x + 4 * iconScale, y: center.y - 4 * iconScale))
        cursorPath.line(to: NSPoint(x: center.x + 12 * iconScale, y: center.y - 24 * iconScale))
        cursorPath.line(to: NSPoint(x: center.x + 3 * iconScale, y: center.y - 27 * iconScale))
        cursorPath.line(to: NSPoint(x: center.x - 5 * iconScale, y: center.y - 7 * iconScale))
        cursorPath.line(to: NSPoint(x: center.x - 18 * iconScale, y: center.y - 7 * iconScale))
        cursorPath.close()
        
        // Shadow for pointer
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowOffset = NSSize(width: 0, height: -2.0 * iconScale)
        shadow.shadowBlurRadius = 4.0 * iconScale
        shadow.set()
        
        NSColor.white.setFill()
        cursorPath.fill()
        
        image.unlockFocus()
        
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            
            let filename1x = (size == 1024) ? "icon_512x512@2x.png" : "icon_\(size)x\(size).png"
            let path1x = "\(iconsetDir)/\(filename1x)"
            try? png.write(to: URL(fileURLWithPath: path1x))
            
            if size <= 512 {
                let halfSize = size / 2
                if halfSize >= 16 {
                    let filename2x = "icon_\(halfSize)x\(halfSize)@2x.png"
                    let path2x = "\(iconsetDir)/\(filename2x)"
                    try? png.write(to: URL(fileURLWithPath: path2x))
                }
            }
        }
    }
    
    print("Iconset created successfully.")
}

generateAppIcon()
