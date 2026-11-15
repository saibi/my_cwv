import SwiftUI
import AppKit

// 앱 아이콘 생성: swiftc -parse-as-library cwv/CWV/AppGlyph.swift cwv/make_icon.swift -o build/make_icon && build/make_icon <출력.png>
// 이후 알파 제거: magick <출력.png> -alpha off <출력.png>
@main
struct MakeIcon {
    @MainActor static func main() {
        let view = ZStack {
            Color(red: 0.13, green: 0.36, blue: 0.75)
            AppGlyph().foregroundStyle(.white).padding(150)
        }.frame(width: 1024, height: 1024)
        let r = ImageRenderer(content: view)
        r.scale = 1
        guard let cg = r.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]),
              CommandLine.arguments.count > 1 else { print("usage: make_icon <out.png>"); exit(1) }
        try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
