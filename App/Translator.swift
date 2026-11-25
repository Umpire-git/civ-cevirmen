import Foundation
import Translation

/// Apple'ın cihaz üstü çeviri motoru (internetsiz). İngilizce → Türkçe.
/// TranslationSession sadece .translationTask içinde kullanılabildiği için
/// o kapanışın içinde sürekli dönen bir iş kuyruğu çalıştırıyoruz.
final class Translator {
    private struct Job {
        let texts: [String]
        let completion: ([String: String]) -> Void
    }

    private let lock = NSLock()
    private var continuation: AsyncStream<Job>.Continuation?
    private var generation = 0

    func submit(_ texts: [String], completion: @escaping ([String: String]) -> Void) {
        lock.lock()
        let c = continuation
        lock.unlock()
        guard let c else { completion([:]); return }
        c.yield(Job(texts: texts, completion: completion))
    }

    func run(session: TranslationSession, onReady: @escaping (Bool) -> Void) async {
        var ready = true
        do {
            try await session.prepareTranslation()
        } catch {
            ready = false
        }
        onReady(ready)

        let (stream, cont) = AsyncStream<Job>.makeStream()
        lock.lock()
        continuation?.finish()
        continuation = cont
        generation += 1
        let myGeneration = generation
        lock.unlock()

        for await job in stream {
            if Task.isCancelled { job.completion([:]); break }
            let requests = job.texts.enumerated().map {
                TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset))
            }
            var out: [String: String] = [:]
            do {
                let responses = try await session.translations(from: requests)
                for r in responses { out[r.sourceText] = r.targetText }
            } catch {
                // Toplu çeviri patlarsa tek tek dene.
                for text in job.texts {
                    if let r = try? await session.translate(text) { out[text] = r.targetText }
                }
            }
            job.completion(out)
        }

        lock.lock()
        if generation == myGeneration { continuation = nil }
        lock.unlock()
    }
}
