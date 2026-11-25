import Foundation
import CoreGraphics

/// Uygulama ile ekran kaydı eklentisi arasındaki ortak ayarlar.
/// İkisi aynı cihazda 127.0.0.1 üzerinden konuşur (App Group gerekmez, SideStore ile sorunsuz).
enum Shared {
    static let port: UInt16 = 47123
    /// Kaç saniyede bir kare gönderilsin.
    static let interval: TimeInterval = 1.0
    /// Gönderilen karenin en uzun kenarı (piksel). OCR doğruluğu ile hız arasındaki denge.
    static let maxDimension: CGFloat = 1800
}
