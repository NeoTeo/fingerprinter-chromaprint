//
//  Fingerprinter.swift
//  ChromaprintTest
//
//  Created by teo on 15/01/16.
//  Copyright © 2016 Terminal Glow. All rights reserved.
//

import AVFoundation

func generateFingerprint(fromSongAtUrl songUrl : URL) -> (String, Double)? {
    
    /// Set the maximum number of seconds we're going to use for fingerprinting
    let maxLength = 120
    
    /** Create a single instance of an unsafe mutable Int8 pointer so we can
     pass it to chromaprint_get_fingerprint without errors.
     The defer ensures it is not leaked if we drop out early.
     */
    var fingerprint: UnsafeMutablePointer<Int8>? = UnsafeMutablePointer<Int8>.allocate(capacity: 1)
    defer {
        fingerprint?.deinitialize()
        fingerprint?.deallocate(capacity: 1)
    }
    
    /// Start by creating a chromaprint context.
    /// Not sure why CHROMAPRINT_ALGORITHM_DEFAULT isn't defined here.
    let algo = Int32(CHROMAPRINT_ALGORITHM_TEST2.rawValue)
    guard let chromaprintContext = chromaprint_new(algo) else { return nil }
    
    /// Decode the song and get back its duration.
    /// The chromaprintContext will contain the fingerprint.
    let duration = decodeAudio(songUrl, withMaxLength: maxLength, forContext: chromaprintContext)
    
    /** Make a fingerprint from the song data.
    (Note we can also get a hash back with chromprint_get_fingerprint_hash)
    */
    
    if chromaprint_get_fingerprint(chromaprintContext, &fingerprint) == 0 {
        print("Error: could not get fingerprint")
        return nil
    }
    
    let fingerprintString = NSString(cString: fingerprint!, encoding: String.Encoding.ascii.rawValue)
    
    chromaprint_dealloc(chromaprintContext)

    return (String(describing: fingerprintString), duration)
}

private func decodeAudio(
    _ fromUrl: URL,
    withMaxLength maxLength: Int ,
    forContext context: UnsafeMutablePointer<ChromaprintContext?>) -> Double {
    
    
        let asset = AVURLAsset(url: fromUrl)
        let reader = try! AVAssetReader(asset: asset)
        let audioTracks = asset.tracks(withMediaType: AVMediaTypeAudio)
        
        if audioTracks.count == 0 {
            print("Error: No audio tracks found")
            return 0
        }
        
        let outputSettings: [String:Int] =
        [   AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMIsBigEndianKey: 0,                   /// little endian
            AVLinearPCMIsFloatKey: 0,                       /// signed integer
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: 0]                 /// is interleaved
        
        let audioTrack = audioTracks[0]
        let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        
        /// Get the duration.
        let durationInSeconds = CMTimeGetSeconds(audioTrack.timeRange.duration)
        
        var sampleRate : Int32?
        var sampleChannels : Int32?
        let descriptions = audioTrack.formatDescriptions
        
        for d in 0..<descriptions.count {
            let item = descriptions[d] as! CMAudioFormatDescription
            let desc = CMAudioFormatDescriptionGetStreamBasicDescription(item)?.pointee
            //print("so d is \(d) and desc.mSampleRate is \(desc.mSampleRate)")
            if desc?.mSampleRate != 0 {
                sampleRate = Int32((desc?.mSampleRate)!)
            }
            if desc?.mChannelsPerFrame != 0 {
                sampleChannels = Int32((desc?.mChannelsPerFrame)!)
            }
        }
        
        /// Sanity check
        guard let rate = sampleRate, let channels = sampleChannels else { return 0 }
    
        reader.add(trackOutput)
        reader.startReading()
        
        let sampleData      = NSMutableData()
        var totalBuf: Int = 0
        
        /** Calculate remainingSamples as
         max length (in seconds) times number of samples read in a second.
         Sample rate is the number of samples per second
         and since we have two channels our number is
         max length * sample channels * sample rate
         */
        var remainingSamples = Int32(maxLength) * channels * rate
        
        /// start off chromaprint
        chromaprint_start(context, rate, channels)
        
        while reader.status == AVAssetReaderStatus.reading {
            if let sampleBufferRef = trackOutput.copyNextSampleBuffer() {
                if let blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef) {
                    
                    /// bufferLength is the total number of bytes in the buffer
                    /// Note that 16-bit samples are half that.
                    let bufferLength = CMBlockBufferGetDataLength(blockBufferRef)
                    totalBuf += bufferLength
                    
                    /// Create a mutable data buffer of bufferLength bytes
                    let data = NSMutableData(length: bufferLength)
                    
                    /// Copy bufferLength bytes from blockBufferRef into data
                    CMBlockBufferCopyDataBytes(
                        blockBufferRef,         /// source buffer
                        0,                      /// offset from start
                        bufferLength,           /// number of bytes to copy
                        data!.mutableBytes)     /// destination buffer
                    
                    let opaquePtr = OpaquePointer(data!.mutableBytes)
                    let samples = UnsafeMutablePointer<Int16>(opaquePtr)
//                    let samples = UnsafeMutablePointer<Int16>(data!.mutableBytes)
                    
                    /**
                     *  - ctx: Chromaprint context pointer
                     *  - data: raw audio data, should point to an array of 16-bit signed
                     *          integers in native byte-order
                     *  - size: size of the data buffer
                     (in samples, so divide by 2 - should use bitdepth val instead)
                     sampleCount already accounts for both channels since it is calculated
                     from the number of bytes read.
                     Each channel's sample count would be:
                     bytes per channel = bytes read divided by two
                     samples per channel = bytes per channel divided by two (for 16-bit samples)
                     
                     a shortcut is bufferLength>>2
                     */
                    let sampleCount = Int32(bufferLength>>1)
                    
                    /// pick the smaller of the two values so we don't remove too much
                    let length = min(remainingSamples, sampleCount)
                    
                    chromaprint_feed(context, UnsafeMutableRawPointer(samples),length)
                    
                    sampleData.append(samples, length: bufferLength)
                    CMSampleBufferInvalidate(sampleBufferRef)
                    
                    /// Cut short if we've set a maxLength
                    if maxLength != 0 {
                        remainingSamples -= length
                        if remainingSamples <= 0 {
                            break
                        }
                    }
                    
                }
            }
        }
        //            sampleData.writeToFile(desktopPath+fileName+".raw", atomically: true)
        
        chromaprint_finish(context)
        return durationInSeconds
}
