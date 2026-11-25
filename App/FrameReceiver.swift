import Foundation
import Network

/// Ekran kaydı eklentisinden gelen JPEG kareleri 127.0.0.1 üzerinden alır.
/// Paket biçimi: 4 bayt uzunluk (big-endian) + JPEG.
final class FrameReceiver {
    var onFrame: ((Data) -> Void)?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "civ.receiver")

    func start() {
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        params.allowLocalEndpointReuse = true
        guard let port = NWEndpoint.Port(rawValue: Shared.port),
              let l = try? NWListener(using: params, on: port) else { return }
        l.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            conn.start(queue: self.queue)
            self.readHeader(conn)
        }
        l.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.listener?.cancel()
                self?.queue.asyncAfter(deadline: .now() + 2) { self?.start() }
            }
        }
        l.start(queue: queue)
        listener = l
    }

    private func readHeader(_ c: NWConnection) {
        c.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
            guard let self, let data, data.count == 4, error == nil else { c.cancel(); return }
            let b = [UInt8](data)
            let len = Int(b[0]) << 24 | Int(b[1]) << 16 | Int(b[2]) << 8 | Int(b[3])
            guard len > 0, len < 20_000_000 else { c.cancel(); return }
            self.readBody(c, len)
        }
    }

    private func readBody(_ c: NWConnection, _ len: Int) {
        c.receive(minimumIncompleteLength: len, maximumLength: len) { [weak self] data, _, _, error in
            guard let self, let data, data.count == len, error == nil else { c.cancel(); return }
            self.onFrame?(data)
            self.readHeader(c)
        }
    }
}
