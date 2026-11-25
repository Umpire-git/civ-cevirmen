import AVKit
import AVFoundation
import UIKit
import SwiftUI
import CoreMedia
import CoreVideo

/// Oyunun üstünde yüzen pencere (Resim içinde Resim). İçine her saniye yeni bir görüntü basıyoruz.
final class PiPController: NSObject, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    let displayLayer = AVSampleBufferDisplayLayer()
    private var controller: AVPictureInPictureController?

    override init() {
        super.init()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.black.cgColor
    }

    func setupIfNeeded() {
        guard controller == nil, AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)

        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: displayLayer,
                                                                 playbackDelegate: self)
        let c = AVPictureInPictureController(contentSource: source)
        c.delegate = self
        c.canStartPictureInPictureAutomaticallyFromInline = true
        c.requiresLinearPlayback = true
        controller = c
        if let p = Overlay.placeholder() { show(p) }
    }

    func start() {
        setupIfNeeded()
        if let p = Overlay.placeholder() { show(p) }
        tryStart(attempt: 0)
    }

    private func tryStart(attempt: Int) {
        guard let c = controller, !c.isPictureInPictureActive else { return }
        if c.isPictureInPicturePossible {
            c.startPictureInPicture()
        } else if attempt < 20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.tryStart(attempt: attempt + 1) }
        }
    }

    func show(_ image: CGImage) {
        guard let sample = SampleBufferMaker.make(from: image) else { return }
        DispatchQueue.main.async {
            if self.displayLayer.status == .failed { self.displayLayer.flush() }
            self.displayLayer.enqueue(sample)
        }
    }

    // MARK: - AVPictureInPictureSampleBufferPlaybackDelegate (canlı yayın gibi davranıyoruz)
    func pictureInPictureController(_ c: AVPictureInPictureController, setPlaying playing: Bool) {}
    func pictureInPictureControllerTimeRangeForPlayback(_ c: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    func pictureInPictureControllerIsPlaybackPaused(_ c: AVPictureInPictureController) -> Bool { false }
    func pictureInPictureController(_ c: AVPictureInPictureController,
                                    didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    func pictureInPictureController(_ c: AVPictureInPictureController,
                                    skipByInterval skipInterval: CMTime,
                                    completion completionHandler: @escaping () -> Void) { completionHandler() }
}

enum SampleBufferMaker {
    static func make(from image: CGImage) -> CMSampleBuffer? {
        let w = image.width, h = image.height
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as [String: Any]
        ]
        var pbOut: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
                                  attrs as CFDictionary, &pbOut) == kCVReturnSuccess,
              let pb = pbOut else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: w, height: h,
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                | CGBitmapInfo.byteOrder32Little.rawValue)
        ctx?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        CVPixelBufferUnlockBaseAddress(pb, [])
        guard ctx != nil else { return nil }

        var formatOut: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pb,
                                                     formatDescriptionOut: &formatOut)
        guard let format = formatOut else { return nil }

        var timing = CMSampleTimingInfo(duration: .invalid,
                                        presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
                                        decodeTimeStamp: .invalid)
        var sampleOut: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pb,
                                                 formatDescription: format, sampleTiming: &timing,
                                                 sampleBufferOut: &sampleOut)
        guard let sample = sampleOut else { return nil }

        if let arr = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true),
           CFArrayGetCount(arr) > 0 {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(arr, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dict,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sample
    }
}

/// Uygulama ekranındaki önizleme kutusu (PiP buradan başlar).
final class LayerHostView: UIView {
    private let hosted: CALayer
    init(hosted: CALayer) {
        self.hosted = hosted
        super.init(frame: .zero)
        backgroundColor = .black
        layer.addSublayer(hosted)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        hosted.frame = bounds
    }
}

struct PiPHostView: UIViewRepresentable {
    let pip: PiPController
    func makeUIView(context: Context) -> LayerHostView {
        let v = LayerHostView(hosted: pip.displayLayer)
        DispatchQueue.main.async { pip.setupIfNeeded() }
        return v
    }
    func updateUIView(_ uiView: LayerHostView, context: Context) {}
}
