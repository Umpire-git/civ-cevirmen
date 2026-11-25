import Foundation
import Vision
import CoreGraphics
import NaturalLanguage

/// Ekrandaki İngilizce yazıları ve konumlarını bulur, alt alta satırları paragrafa birleştirir.
enum OCR {
    struct Block {
        var text: String
        var rect: CGRect        // piksel, sol-üst köşe orijinli
        var lineHeight: CGFloat
    }

    static func read(_ image: CGImage) -> [Block] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.008

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch { return [] }

        let W = CGFloat(image.width), H = CGFloat(image.height)
        var lines: [Block] = []
        for obs in request.results ?? [] {
            guard let cand = obs.topCandidates(1).first, cand.confidence >= 0.3 else { continue }
            let text = cand.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard worthTranslating(text) else { continue }
            let bb = obs.boundingBox
            let rect = CGRect(x: bb.minX * W, y: (1 - bb.maxY) * H, width: bb.width * W, height: bb.height * H)
            lines.append(Block(text: text, rect: rect, lineHeight: rect.height))
        }
        return mergeParagraphs(lines)
    }

    /// Sayı, tek harf ve zaten Türkçe olan yazıları (ör. yüzen pencerenin kendisi) atla.
    static func worthTranslating(_ s: String) -> Bool {
        let letters = s.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard letters >= 2 else { return false }
        if s.rangeOfCharacter(from: CharacterSet(charactersIn: "ğĞıİşŞçÇöÖüÜ")) != nil { return false }
        if s.count >= 12 {
            let r = NLLanguageRecognizer()
            r.processString(s)
            if let lang = r.dominantLanguage, lang == .turkish { return false }
        }
        return true
    }

    /// Aynı sütunda, satır aralığı kadar yakın duran satırları tek paragraf yapar.
    /// Çeviri cümle bütünüyle yapılınca çok daha doğru çıkar.
    static func mergeParagraphs(_ lines: [Block]) -> [Block] {
        let sorted = lines.sorted { $0.rect.minY < $1.rect.minY }
        var paras: [(block: Block, last: CGRect)] = []

        for line in sorted {
            let h = line.rect.height
            var merged = false
            for i in paras.indices.reversed() {
                let last = paras[i].last
                let gap = line.rect.minY - last.maxY
                let sameColumn = abs(line.rect.minX - last.minX) < h * 1.2
                    || abs(line.rect.midX - last.midX) < h * 1.2
                let similarSize = h / max(last.height, 1) > 0.75 && h / max(last.height, 1) < 1.33
                if gap > -h * 0.3 && gap < h * 0.9 && sameColumn && similarSize {
                    var p = paras[i].block
                    if p.text.hasSuffix("-") {
                        p.text = String(p.text.dropLast()) + line.text
                    } else {
                        p.text += " " + line.text
                    }
                    p.rect = p.rect.union(line.rect)
                    paras[i] = (p, line.rect)
                    merged = true
                    break
                }
            }
            if !merged { paras.append((line, line.rect)) }
        }
        return paras.map { $0.block }
    }
}
