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
