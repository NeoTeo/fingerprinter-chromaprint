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
        let algo : Int32 = 1 //UInt32(CHROMAPRINT_ALGORITHM_TEST2.rawValue)
        let chromaprintContext = chromaprint_new(algo)

        /// Get the song
        let songUrl = NSURL(fileURLWithPath: "/Users/teo/Desktop/64.mp3" )

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
                    AVLinearPCMIsBigEndianKey: 0,
                    AVLinearPCMIsFloatKey: 0,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsNonInterleaved: 0]
            
            let audioTrack = audioTracks[0]
            let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            
            reader.addOutput(trackOutput)
            reader.startReading()
            
            let sampleData = NSMutableData()
            
            while reader.status == AVAssetReaderStatus.Reading {
                if let sampleBufferRef = trackOutput.copyNextSampleBuffer() {
                    if let blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef) {
                        let bufferLength = CMBlockBufferGetDataLength(blockBufferRef)
                        let data = NSMutableData(length: bufferLength)
                        CMBlockBufferCopyDataBytes(blockBufferRef, 0, bufferLength, data!.mutableBytes)
                        let samples = UnsafeMutablePointer<Int16>(data!.mutableBytes)
                        sampleData.appendBytes(samples, length: bufferLength)
                        CMSampleBufferInvalidate(sampleBufferRef)
                    }
                }
            }
            print("The outputs \(sampleData)")
            
        return 42
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

