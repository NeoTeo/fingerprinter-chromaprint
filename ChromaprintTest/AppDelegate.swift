//
//  AppDelegate.swift
//  ChromaprintTest
//
//  Created by teo on 07/01/16.
//  Copyright © 2016 Terminal Glow. All rights reserved.
//

import Cocoa
import AVFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let desktopPath = "/Users/teo/Desktop/"
//    let fileName = "64.mp3"
//    let fileName = "low.wav"
//    let fileName = "64.wav"
        let fileName = "small64.m4a"
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {

        let maxLength = 120
        /** Create a single instance of an unsafe mutable Int8 pointer so we can 
            pass it to chromaprint_get_fingerprint without errors. 
            The defer ensures it is not leaked.
        */
        var fingerprint = UnsafeMutablePointer<Int8>.alloc(1)
        defer {
            print("Destroy & dealloc fingerprint")
            fingerprint.destroy()
            fingerprint.dealloc(1)
        }
        
        /// Start by creating a chromaprint context.
        /// Not sure why CHROMAPRINT_ALGORITHM_DEFAULT isn't defined here.
//        let algo : Int32 = 1 //UInt32(CHROMAPRINT_ALGORITHM_TEST2.rawValue)
        let algo = Int32(CHROMAPRINT_ALGORITHM_TEST2.rawValue)
        let chromaprintContext = chromaprint_new(algo)

        /// Get the song
//        let fileName = "low.wav"

//        let songUrl = NSURL(fileURLWithPath: "/Users/teo/Desktop/64.mp3" )
        let songUrl = NSURL(fileURLWithPath: desktopPath+fileName )
        
        /// Decode the song
        let duration = decodeAudio(songUrl, withMaxLength: maxLength, forContext: chromaprintContext)
        /** Make a fingerprint from the song data.
            (Note we can also get a hash back with chromprint_get_fingerprint_hash)
        */
        if chromaprint_get_fingerprint(chromaprintContext, &fingerprint) == 0 {
            print("Error: could not get fingerprint")
            return
        }
        
        let fingerprintString = NSString(CString: fingerprint, encoding: NSASCIIStringEncoding)
        
        chromaprint_dealloc(chromaprintContext)
        
        print("The song duration is \(duration)")
        print("The fingerprint is: \(fingerprintString)")
    }

    func decodeAudio(
        fromUrl: NSURL,
        withMaxLength maxLength: Int ,
        forContext context: UnsafeMutablePointer<ChromaprintContext>) -> Int {
        
            let asset = AVURLAsset(URL: fromUrl)
            let reader = try! AVAssetReader(asset: asset)
            let audioTracks = asset.tracksWithMediaType(AVMediaTypeAudio)
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

            var sampleRate : Int32?
            var sampleChannels : Int32?
            
            print("Format descriptions \(audioTrack.formatDescriptions)")
            let descriptions = audioTrack.formatDescriptions
            for d in 0..<descriptions.count {
                let item = descriptions[d] as! CMAudioFormatDescriptionRef
                let desc = CMAudioFormatDescriptionGetStreamBasicDescription(item).memory
                //print("so d is \(d) and desc.mSampleRate is \(desc.mSampleRate)")
                if desc.mSampleRate != 0 {
                    sampleRate = Int32(desc.mSampleRate)
                }
                if desc.mChannelsPerFrame != 0 {
                    sampleChannels = Int32(desc.mChannelsPerFrame)
                }
            }
            /// Sanity check
            guard (sampleRate != nil) && (sampleChannels != nil) else {
                return 0
            }

            reader.addOutput(trackOutput)
            reader.startReading()
            
            let sampleData      = NSMutableData()
            var totalBuf: Int = 0
            /// start off chromaprint
            chromaprint_start(context, sampleRate!, sampleChannels!)
            
            while reader.status == AVAssetReaderStatus.Reading {
                if let sampleBufferRef = trackOutput.copyNextSampleBuffer() {
                    if let blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef) {
                        /**
                        size_t lengthAtOffset;
                        size_t totalLength;
                        char* data;

*/
//                        var lengthAtOffset = 0
//                        var totalLength = 0
//                        var dataPointer = UnsafeMutablePointer<Int8>.alloc(1)
//                        defer {
//                            dataPointer.destroy()
//                            dataPointer.dealloc(1)
//                        }
//
//                        if CMBlockBufferGetDataPointer(blockBufferRef,
//                            0,                  /// start from offset zero
//                            &lengthAtOffset,    /// will be set to bytelength from above offset
//                            &totalLength,       /// will be set to bytelength from offset 0
//                            &dataPointer) == kCMBlockBufferNoErr {
//                            print("Datapointer \(dataPointer), \(lengthAtOffset), \(totalLength)")
//                                for idx in 0..<totalLength {
//                                    print(String(format:"%X", dataPointer[idx]))
//                                }
//                        }
                        
                        /// bufferLength is the total number of bytes in the buffer
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
                        
                        let samples = UnsafeMutablePointer<Int16>(data!.mutableBytes)
                        
                        /**
                        *  - ctx: Chromaprint context pointer
                        *  - data: raw audio data, should point to an array of 16-bit signed
                        *          integers in native byte-order
                        *  - size: size of the data buffer (in samples)
                        */
                        let bufLen = Int32(bufferLength)
                        chromaprint_feed(context, UnsafeMutablePointer<Void>(samples),bufLen>>1)
                        
                        print("Buffer length \(bufferLength)")
                        sampleData.appendBytes(samples, length: bufferLength)
                        CMSampleBufferInvalidate(sampleBufferRef)
                    }
                }
            }
            print("total buf \(totalBuf)")
            //print("The outputs \(sampleData)")
            
            sampleData.writeToFile(desktopPath+fileName+".raw", atomically: true)
            
            chromaprint_finish(context)
        return 42
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

