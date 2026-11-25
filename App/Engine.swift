import Foundation
import UIKit
import SwiftUI
import Translation

/// Akış: eklentiden kare gelir → OCR → (önbellekte yoksa) çeviri → yazılar yerine basılır → yüzen pencere.
final class Engine: ObservableObject {
    @Published var status = "Başlamak için adımları sırayla izle."
    @Published var translationConfig: TranslationSession.Configuration? =
        TranslationSession.Configuration(source: Locale.Language(identifier: "en"),
                                         target: Locale.Language(identifier: "tr"))

    let translator = Translator()
    let pip = PiPController()
    private let receiver = FrameReceiver()
    private let work = DispatchQueue(label: "civ.engine", qos: .userInitiated)

    // Sadece `work` kuyruğunda erişilir.
    private var cache: [String: String] = [:]
    private var outputs: Set<String> = []
    private var busy = false
    private var lastSignature: [String] = []

    init() {
        receiver.onFrame = { [weak self] data in self?.handle(data) }
        receiver.start()
    }

    func prepareLanguages() {
        translationConfig?.invalidate()
        status = "Dil paketi kontrol ediliyor…"
    }

    @MainActor func languagesReady(_ ok: Bool) {
        status = ok ? "Dil paketi hazır. 2. adıma geç."
                    : "Dil paketi hazır değil. \"Dilleri hazırla\"ya bas ve indirmeyi onayla."
    }

    private func handle(_ data: Data) {
        work.async {
            guard !self.busy else { return }
            guard let image = UIImage(data: data)?.cgImage else { return }
            self.busy = true

            let blocks = OCR.read(image).filter { !self.outputs.contains($0.text) }
            let todo = Array(Set(blocks.map(\.text).filter { self.cache[$0] == nil }))

            if todo.isEmpty {
                self.render(image, blocks)
            } else {
                self.translator.submit(todo) { result in
                    self.work.async {
                        for (src, dst) in result {
                            self.cache[src] = dst
                            self.outputs.insert(dst)
                        }
                        self.render(image, blocks)
                    }
                }
            }
        }
    }

    private func render(_ image: CGImage, _ blocks: [OCR.Block]) {
        let items = blocks.compactMap { b -> Overlay.Item? in
            guard let tr = cache[b.text], tr != b.text else { return nil }
            return Overlay.Item(rect: b.rect, text: tr, sourceLineHeight: b.lineHeight)
        }
        if let out = Overlay.draw(base: image, items: items) {
            pip.show(out)
        }
        busy = false
        let n = items.count
        DispatchQueue.main.async { self.status = "Çalışıyor — ekranda \(n) metin çevrildi." }
    }
}
