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

        // Video: `seconds` worth of gray frames at 10 fps.
        let fps: Double = 10
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        let frameCount = max(1, Int((seconds * fps).rounded()))
        var presentationTime = CMTime.zero
        for _ in 0..<frameCount {
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            guard let pool = adaptor.pixelBufferPool else { throw SyntheticMovieError.noPixelBufferPool }
            var pixelBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer) == kCVReturnSuccess,
                  let pixelBuffer else { throw SyntheticMovieError.pixelBufferFailed }
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
                let pixels = UnsafeMutableRawBufferPointer(start: baseAddress, count: bytesPerRow * height)
                for index in pixels.indices { pixels[index] = 0x40 }
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? SyntheticMovieError.appendFailed
            }
            presentationTime = presentationTime + frameDuration
        }
        videoInput.markAsFinished()

        // Audio: silent mono PCM buffers, compressed to AAC by the writer.
        if let audioInput {
            let sampleRate = 44100.0
            let framesPerBuffer = 1024
            let bytesPerFrame = 2              // 16-bit mono
            let totalFrames = max(1, Int((seconds * sampleRate).rounded()))
            let memory = UnsafeMutableRawPointer.allocate(
                byteCount: framesPerBuffer * bytesPerFrame,
                alignment: 1
            )
            memory.initializeMemory(
                as: UInt8.self,
                repeating: 0,
                count: framesPerBuffer * bytesPerFrame
            )
            defer { memory.deallocate() }

            var framesWritten = 0
            var audioTime = CMTime.zero
            while framesWritten < totalFrames {
                while !audioInput.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 5_000_000)
                }
                let frameCount = min(framesPerBuffer, totalFrames - framesWritten)
                var bufferList = AudioBufferList()
                bufferList.mNumberBuffers = 1
                bufferList.mBuffers.mNumberChannels = 1
                bufferList.mBuffers.mDataByteSize = UInt32(frameCount * bytesPerFrame)
                bufferList.mBuffers.mData = memory
                guard audioInput.append(&bufferList, withPresentationTime: audioTime) else {
                    throw writer.error ?? SyntheticMovieError.appendFailed
                }
                audioTime = audioTime + CMTime(
                    value: CMTimeValue(frameCount),
                    timescale: CMTimeScale(sampleRate)
                )
                framesWritten += frameCount
            }
            audioInput.markAsFinished()
        }

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
}
