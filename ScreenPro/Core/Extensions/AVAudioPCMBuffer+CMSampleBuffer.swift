import AVFoundation
import CoreMedia

/// Extension to convert AVAudioPCMBuffer to CMSampleBuffer for writing to AVAssetWriter (T055)
extension AVAudioPCMBuffer {

    /// Converts the audio buffer to a CMSampleBuffer for use with AVAssetWriter
    /// - Parameter time: The audio time for the buffer
    /// - Returns: A CMSampleBuffer if conversion succeeds, nil otherwise
    func toCMSampleBuffer(at time: AVAudioTime) -> CMSampleBuffer? {
        let formatDescription = format.formatDescription

        let frameCount = CMItemCount(frameLength)
        guard frameCount > 0 else { return nil }

        // Calculate timing
        let sampleRate = format.sampleRate
        let sampleTime = time.sampleTime

        // Create sample buffer using the presentation timestamp
        let presentationTime = CMTime(value: sampleTime, timescale: CMTimeScale(sampleRate))

        return createSampleBuffer(
            formatDescription: formatDescription,
            frameCount: frameCount,
            presentationTime: presentationTime
        )
    }

    /// Creates a CMSampleBuffer from the audio buffer with a specific presentation time
    /// - Parameter presentationTime: The CMTime for the sample's presentation timestamp
    /// - Returns: A CMSampleBuffer if conversion succeeds, nil otherwise
    func toCMSampleBuffer(presentationTime: CMTime) -> CMSampleBuffer? {
        let formatDescription = format.formatDescription

        let frameCount = CMItemCount(frameLength)
        guard frameCount > 0 else { return nil }

        return createSampleBuffer(
            formatDescription: formatDescription,
            frameCount: frameCount,
            presentationTime: presentationTime
        )
    }

    // MARK: - Private Helpers

    private func createSampleBuffer(
        formatDescription: CMAudioFormatDescription,
        frameCount: CMItemCount,
        presentationTime: CMTime
    ) -> CMSampleBuffer? {
        // Access the underlying audio buffer list (non-optional)
        let audioBufferListPtr = audioBufferList
        let bufferList = audioBufferListPtr.pointee

        // Calculate total data size - for PCM, use stride * frameLength
        let bytesPerFrame = format.streamDescription.pointee.mBytesPerFrame
        let totalSize = Int(bytesPerFrame) * Int(frameLength)

        guard totalSize > 0 else { return nil }

        // Create block buffer
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: totalSize,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: totalSize,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr, let buffer = blockBuffer else { return nil }

        // Copy audio data from the first buffer (mono/interleaved stereo)
        if bufferList.mNumberBuffers > 0 {
            let audioBuffer = bufferList.mBuffers
            if let data = audioBuffer.mData {
                let size = min(Int(audioBuffer.mDataByteSize), totalSize)
                status = CMBlockBufferReplaceDataBytes(
                    with: data,
                    blockBuffer: buffer,
                    offsetIntoDestination: 0,
                    dataLength: size
                )
            }
        }

        guard status == noErr else { return nil }

        // Create audio sample buffer
        var sampleBuffer: CMSampleBuffer?
        status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: buffer,
            formatDescription: formatDescription,
            sampleCount: frameCount,
            presentationTimeStamp: presentationTime,
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr else { return nil }

        return sampleBuffer
    }
}
