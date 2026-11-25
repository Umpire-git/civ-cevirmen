import UIKit

/// Ekran görüntüsünün üstüne, her İngilizce yazının yerine Türkçesini basar.
enum Overlay {
    struct Item {
        var rect: CGRect
        var text: String
        var sourceLineHeight: CGFloat
    }

    static func draw(base: CGImage, items: [Item]) -> CGImage? {
        let size = CGSize(width: base.width, height: base.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let image = renderer.image { ctx in
            UIImage(cgImage: base).draw(in: CGRect(origin: .zero, size: size))

            for item in items {
                let box = item.rect.insetBy(dx: -4, dy: -3)
                let maxHeight = max(box.height * 1.6, item.sourceLineHeight * 1.4)

                // Yazıyı kutuya sığdıracak en büyük punto.
                var fontSize = max(item.sourceLineHeight * 0.85, 9)
                var attr = attributes(fontSize)
                var bounds = measure(item.text, width: box.width, attr)
                while bounds.height > maxHeight && fontSize > 8 {
                    fontSize -= 1
                    attr = attributes(fontSize)
                    bounds = measure(item.text, width: box.width, attr)
                }

                let bg = CGRect(x: box.minX, y: box.minY,
                                width: box.width, height: max(box.height, ceil(bounds.height) + 4))
                UIColor(white: 0.06, alpha: 0.9).setFill()
                UIBezierPath(roundedRect: bg, cornerRadius: 4).fill()
                (item.text as NSString).draw(with: bg.insetBy(dx: 2, dy: 2),
                                             options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                             attributes: attr, context: nil)
            }
            _ = ctx
        }
        return image.cgImage
    }

    private static func attributes(_ size: CGFloat) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle()
        p.lineBreakMode = .byWordWrapping
        return [.font: UIFont.systemFont(ofSize: size, weight: .semibold),
                .foregroundColor: UIColor(red: 1, green: 0.93, blue: 0.7, alpha: 1),
                .paragraphStyle: p]
    }

    private static func measure(_ s: String, width: CGFloat, _ attr: [NSAttributedString.Key: Any]) -> CGRect {
        (s as NSString).boundingRect(with: CGSize(width: max(width - 4, 10), height: .greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin], attributes: attr, context: nil)
    }

    /// Okuma paneli: küçük pencerede okunabilsin diye sadece Türkçe metin, büyük puntoyla.
    /// Uzun açıklamalar okuma sırasıyla üstte, kısa düğme/başlık yazıları altta tek satırda.
    static func panel(items: [Item], size: CGSize = CGSize(width: 1200, height: 900)) -> CGImage? {
        let sorted = items.sorted {
            abs($0.rect.minY - $1.rect.minY) < 12 ? $0.rect.minX < $1.rect.minX : $0.rect.minY < $1.rect.minY
        }
        let wordCount: (String) -> Int = { $0.split(separator: " ").count }
        let long = sorted.filter { wordCount($0.text) >= 4 }.map(\.text)
        var seen = Set<String>()
        let short = sorted.filter { wordCount($0.text) < 4 }.map(\.text).filter { seen.insert($0).inserted }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let img = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor(white: 0.07, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            let margin: CGFloat = 36
            let width = size.width - margin * 2
            let shortText = short.joined(separator: "  ·  ")
            let accent = UIColor(red: 1, green: 0.85, blue: 0.5, alpha: 1)

            // Puntoyu, tüm metin sığana kadar küçült.
            var font: CGFloat = 52
            func layout(_ f: CGFloat) -> (CGFloat, CGFloat) {
                let bodyH = long.reduce(CGFloat(0)) { acc, t in
                    acc + measure(t, width: width + 4, body(f)).height + f * 0.6
                }
                let footH = shortText.isEmpty ? 0 : measure(shortText, width: width + 4, foot(f)).height + 24
                return (bodyH, footH)
            }
            var (bodyH, footH) = layout(font)
            while bodyH + footH > size.height - margin * 2 && font > 18 {
                font -= 2
                (bodyH, footH) = layout(font)
            }

            var y = margin
            for t in long {
                let h = measure(t, width: width + 4, body(font)).height
                accent.setFill()
                UIRectFill(CGRect(x: margin - 18, y: y + 6, width: 6, height: max(h - 12, 6)))
                (t as NSString).draw(with: CGRect(x: margin, y: y, width: width, height: h + 4),
                                     options: [.usesLineFragmentOrigin], attributes: body(font), context: nil)
                y += h + font * 0.6
            }
            if !shortText.isEmpty {
                let fy = max(y, size.height - margin - footH + 24)
                UIColor(white: 1, alpha: 0.15).setFill()
                UIRectFill(CGRect(x: margin, y: fy - 16, width: width, height: 2))
                (shortText as NSString).draw(with: CGRect(x: margin, y: fy, width: width, height: footH),
                                             options: [.usesLineFragmentOrigin], attributes: foot(font), context: nil)
            }
            if long.isEmpty && shortText.isEmpty {
                let p = NSMutableParagraphStyle(); p.alignment = .center
                ("Çevrilecek metin bekleniyor…" as NSString).draw(
                    in: CGRect(x: 0, y: size.height / 2 - 30, width: size.width, height: 60),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 40, weight: .medium),
                                     .foregroundColor: UIColor(white: 1, alpha: 0.5), .paragraphStyle: p])
            }
        }
        return img.cgImage
    }

    private static func body(_ f: CGFloat) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle(); p.lineBreakMode = .byWordWrapping; p.lineSpacing = f * 0.12
        return [.font: UIFont.systemFont(ofSize: f, weight: .semibold), .foregroundColor: UIColor.white, .paragraphStyle: p]
    }

    private static func foot(_ f: CGFloat) -> [NSAttributedString.Key: Any] {
        let p = NSMutableParagraphStyle(); p.lineBreakMode = .byWordWrapping
        return [.font: UIFont.systemFont(ofSize: f * 0.7, weight: .medium),
                .foregroundColor: UIColor(white: 1, alpha: 0.7), .paragraphStyle: p]
    }

    static func placeholder() -> CGImage? {
        let size = CGSize(width: 1200, height: 900)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let img = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor(white: 0.08, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let p = NSMutableParagraphStyle(); p.alignment = .center
            let text = "Civ Çevirmen\nEkran kaydı bekleniyor…"
            (text as NSString).draw(in: CGRect(x: 0, y: 360, width: size.width, height: 200),
                                    withAttributes: [.font: UIFont.systemFont(ofSize: 56, weight: .bold),
                                                     .foregroundColor: UIColor.white,
                                                     .paragraphStyle: p])
        }
        return img.cgImage
    }
}
