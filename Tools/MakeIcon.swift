// Renders the app icon from the same SwiftUI frog the app draws.
// Usage: Tools/make-icon.sh
import SwiftUI
import AppKit

struct IconArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x7FD6FF), Color(hex: 0xD6F3FF)], startPoint: .top, endPoint: .center)
            Rectangle()
                .fill(LinearGradient(colors: [Color(hex: 0x5CCBF5), Color(hex: 0x2389DD)], startPoint: .top, endPoint: .bottom))
                .frame(height: 420)
                .frame(maxHeight: .infinity, alignment: .bottom)
            ForEach(0..<3, id: \.self) { i in
                Ellipse()
                    .stroke(.white.opacity(0.5 - Double(i) * 0.14), lineWidth: 14)
                    .frame(width: 700 + CGFloat(i) * 150, height: 230 + CGFloat(i) * 55)
                    .offset(y: 330)
            }
            Ellipse().fill(Color(hex: 0x3E8E33))
                .frame(width: 660, height: 250)
                .offset(y: 345)
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0x8BDB6A), Color(hex: 0x5DBB4A)], startPoint: .top, endPoint: .bottom))
                .frame(width: 640, height: 230)
                .offset(y: 325)
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(Color(hex: 0xFFE14D))
                    .frame(width: 34, height: 110)
                    .offset(y: -350)
                    .rotationEffect(.degrees(Double(i) * 28 - 42))
                    .offset(y: 40)
            }
            FrogView(size: 640, mouthOpen: 0.85, hat: nil)
                .offset(y: 40)
        }
        .frame(width: 1024, height: 1024)
    }
}

@main
struct MakeIcon {
    @MainActor static func main() {
        let renderer = ImageRenderer(content: IconArt())
        renderer.scale = 1
        renderer.isOpaque = true  // App Store icons must not have an alpha channel.
        guard let cg = renderer.cgImage else { fatalError("render failed") }
        let rep = NSBitmapImageRep(cgImage: cg)
        let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
        print("Wrote \(out)")
    }
}
