import SwiftUI
import AppKit

// 앱 아이콘 생성: swiftc -parse-as-library cwv/CWV/AppGlyph.swift cwv/make_icon.swift -o build/make_icon && build/make_icon <출력.png>
// 알파 없는 불투명 PNG로 저장한다.
@main
struct MakeIcon {
    @MainActor static func main() {
        let view = ZStack {
            Color(red: 0.13, green: 0.36, blue: 0.75)
            AppGlyph().foregroundStyle(.white).padding(150)
        }.frame(width: 1024, height: 1024)
        let r = ImageRenderer(content: view)
        r.scale = 1
        guard let cg = r.cgImage, let ctx = CGContext(
                data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              CommandLine.arguments.count > 1 else { print("usage: make_icon <out.png>"); exit(1) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))  // 알파 없는 컨텍스트로 옮겨 불투명하게 만든다
        let png = NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
        try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
