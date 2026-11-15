import SwiftUI

/// 앱 아이콘과 플로팅 버튼이 함께 쓰는 글리프: 말풍선(커뮤니티) 안의 글자 줄(읽기/글자 크기).
/// 줄은 뚫려 있어 배경이 비친다. 아이콘 PNG는 make_icon.swift가 이 뷰로 만든다.
struct AppGlyph: View {
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            let r = { (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) in
                CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
            }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 0.16 * s, style: .continuous).path(in: r(0.08, 0.14, 0.84, 0.60)).fill()
                Path { p in  // 꼬리
                    p.move(to: CGPoint(x: 0.22 * s, y: 0.73 * s))
                    p.addLine(to: CGPoint(x: 0.22 * s, y: 0.90 * s))
                    p.addLine(to: CGPoint(x: 0.46 * s, y: 0.73 * s))
                    p.closeSubpath()
                }.fill()
                Group {  // 글자 줄 (굵은 제목줄 + 본문 두 줄)
                    Capsule().path(in: r(0.20, 0.27, 0.60, 0.10)).fill()
                    Capsule().path(in: r(0.20, 0.43, 0.60, 0.06)).fill()
                    Capsule().path(in: r(0.20, 0.55, 0.38, 0.06)).fill()
                }.blendMode(.destinationOut)
            }
            .compositingGroup()
            .frame(width: g.size.width, height: g.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
