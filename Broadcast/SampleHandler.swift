import ReplayKit
import CoreImage
import Network
import ImageIO

/// Ekran kaydı eklentisi: saniyede ~1 kare alır, küçültür, JPEG yapıp ana uygulamaya yollar.
/// Eklentinin bellek sınırı düşük (~50 MB) olduğu için OCR ve çeviri burada değil, ana uygulamada yapılır.
class SampleHandler: RPBroadcastSampleHandler {
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let queue = DispatchQueue(label: "civ.sender")
    private var connection: NWConnection?
    private var sending = false
    private var finished = false
    private var lastSent = Date.distantPast

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        queue.async { self.connect() }
    }

    override func broadcastFinished() {
        queue.async {
            self.finished = true
            self.connection?.cancel()
        }
    }

    private func connect() {
        guard !finished, let port = NWEndpoint.Port(rawValue: Shared.port) else { return }
        let c = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        c.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .failed, .cancelled:
                self.sending = false
                if !self.finished {
                    self.queue.asyncAfter(deadline: .now() + 2) { self.connect() }
                }
            default:
                break
            }
        }
        connection = c
        c.start(queue: queue)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        let now = Date()
        guard now.timeIntervalSince(lastSent) >= Shared.interval else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastSent = now

        autoreleasepool {
            var image = CIImage(cvPixelBuffer: pixelBuffer)
            if let num = CMGetAttachment(sampleBuffer,
                                         key: RPVideoSampleOrientationKey as CFString,
                                         attachmentModeOut: nil) as? NSNumber,
               var orientation = CGImagePropertyOrientation(rawValue: num.uint32Value) {
                // ReplayKit yatayda sol/sağı ters bildiriyor; düzeltmezsek görüntü 180° dönük çıkıyor.
                switch orientation {
                case .left: orientation = .right
                case .right: orientation = .left
                case .leftMirrored: orientation = .rightMirrored
                case .rightMirrored: orientation = .leftMirrored
                default: break
                }
                image = image.oriented(orientation)
            }
            let longest = max(image.extent.width, image.extent.height)
            let scale = min(1, Shared.maxDimension / longest)
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            image = image.transformed(by: CGAffineTransform(translationX: -image.extent.origin.x,
                                                            y: -image.extent.origin.y))

            let options: [CIImageRepresentationOption: Any] = [
                CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.75
            ]
            guard let jpeg = ciContext.jpegRepresentation(of: image,
                                                          colorSpace: CGColorSpaceCreateDeviceRGB(),
                                                          options: options) else { return }
            queue.async { self.send(jpeg) }
        }
    }

    private func send(_ jpeg: Data) {
        guard !sending, let c = connection, c.state == .ready else { return }
        var packet = Data()
        let len = UInt32(jpeg.count)
        packet.append(UInt8((len >> 24) & 0xff))
        packet.append(UInt8((len >> 16) & 0xff))
        packet.append(UInt8((len >> 8) & 0xff))
        packet.append(UInt8(len & 0xff))
        packet.append(jpeg)
        sending = true
        c.send(content: packet, completion: .contentProcessed { [weak self] _ in
            self?.queue.async { self?.sending = false }
        })
    }
}
