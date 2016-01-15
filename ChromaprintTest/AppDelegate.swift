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
    let fileName = "64.mp3"
//    let fileName = "low.wav"
//    let fileName = "64.wav"
//        let fileName = "small64.m4a"
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {

        /// Build the song path
        let songUrl = NSURL(fileURLWithPath: desktopPath+fileName )
        
        guard let (fingerprintString, duration) = generateFingerprint(fromSongAtUrl: songUrl) else {
            print("No fingerprint was generated")
            return
        }
        
        print("The song duration is \(duration)")
        print("The fingerprint is: \(fingerprintString)")
        
    }

    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

