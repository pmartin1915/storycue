import AVFoundation
import CoreVideo
import Foundation

enum SyntheticMovieError: Error {
    case cannotAddInput(String)
    case startWritingFailed
    case noPixelBufferPool
    case pixelBufferFailed
    case appendFailed
    case finishFailed
}

/// Writes a tiny real .mov for AVStitcherTests: 64×64 H.264 at 10 fps, plus silent mono
/// AAC when `withAudio`. On CI runners with no encoder this throws — the tests then skip
/// (S3 spec §6's pre-registered fallback), and real stitching is verified on device at S5.
enum SyntheticMovie {
    static func write(to url: URL, seconds: Double, withAudio: Bool) async throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let width = 64
        let height = 64

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        videoInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )
        guard writer.canAdd(videoInput) else { throw SyntheticMovieError.cannotAddInput("video") }
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if withAudio {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
            ])
            input.expectsMediaDataInRealTime = false
            guard writer.canAdd(input) else { throw SyntheticMovieError.cannotAddInput("audio") }
            writer.add(input)
            audioInput = input
        }

        guard writer.startWriting() else {
            throw writer.error ?? SyntheticMovieError.startWritingFailed
        }
        writer.startSession(atSourceTime: .zero)

        // Silent 16-bit mono PCM; the writer compresses it to AAC.
        let sampleRate = 44100
        var audioFormat: CMAudioFormatDescription?
        if audioInput != nil {
            var asbd = AudioStreamBasicDescription(
                mSampleRate: Float64(sampleRate),
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
                mBytesPerPacket: 2,
                mFramesPerPacket: 1,
                mBytesPerFrame: 2,
                mChannelsPerFrame: 1,
                mBitsPerChannel: 16,
                mReserved: 0
            )
            guard CMAudioFormatDescriptionCreate(
                allocator: kCFAllocatorDefault, asbd: &asbd, layoutSize: 0, layout: nil,
                magicCookieSize: 0, magicCookie: nil, extensions: nil,
                formatDescriptionOut: &audioFormat
            ) == noErr else { throw SyntheticMovieError.appendFailed }
        }

        // Video frames and audio buffers are appended interleaved, one 0.1 s step at a time:
        // AVAssetWriter stalls an input that runs too far ahead of the other.
        let fps = 10
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        let frameCount = max(1, Int((seconds * Double(fps)).rounded()))
        let audioFramesPerStep = sampleRate / fps
        for step in 0..<frameCount {
            let time = CMTimeMultiply(frameDuration, multiplier: Int32(step))

            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            guard let pool = adaptor.pixelBufferPool else { throw SyntheticMovieError.noPixelBufferPool }
            var pixelBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
                  let pixelBuffer else { throw SyntheticMovieError.pixelBufferFailed }
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
                memset(baseAddress, 0x40, CVPixelBufferGetBytesPerRow(pixelBuffer) * height)
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                throw writer.error ?? SyntheticMovieError.appendFailed
            }

            if let audioInput, let audioFormat {
                while !audioInput.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 5_000_000)
                }
                let sample = try silentAudio(
                    frames: audioFramesPerStep,
                    at: CMTime(value: CMTimeValue(step * audioFramesPerStep), timescale: CMTimeScale(sampleRate)),
                    format: audioFormat
                )
                guard audioInput.append(sample) else {
                    throw writer.error ?? SyntheticMovieError.appendFailed
                }
            }
        }
        videoInput.markAsFinished()
        audioInput?.markAsFinished()

        try await withCheckedThrowingContinuation { continuation in
            writer.finishWriting {
                if let error = writer.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        if writer.status != .completed {
            throw writer.error ?? SyntheticMovieError.finishFailed
        }
    }

    private static func silentAudio(
        frames: Int, at time: CMTime, format: CMAudioFormatDescription
    ) throws -> CMSampleBuffer {
        let byteCount = frames * 2
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: byteCount,
            blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
            dataLength: byteCount, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block
        ) == noErr, let block else { throw SyntheticMovieError.appendFailed }
        guard CMBlockBufferFillDataBytes(
            with: 0, blockBuffer: block, offsetIntoDestination: 0, dataLength: byteCount
        ) == noErr else { throw SyntheticMovieError.appendFailed }
        var sample: CMSampleBuffer?
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
            sampleCount: frames, presentationTimeStamp: time, packetDescriptions: nil,
            sampleBufferOut: &sample
        ) == noErr, let sample else { throw SyntheticMovieError.appendFailed }
        return sample
    }
}
