//
//  AppDelegate.swift
//  ChromaprintTest
//
//  Created by teo on 07/01/16.
//  Copyright © 2016 Terminal Glow. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        print("So far...")
        
        //ChromaprintTestObjC.flibble()
        
        let algo : Int32 = 1 //UInt32(CHROMAPRINT_ALGORITHM_TEST2.rawValue)
        let chromaprintContext = chromaprint_new(algo)
//        ChromaprintContext *chromaprintContext = chromaprint_new(CHROMAPRINT_ALGORITHM_DEFAULT);
        print("I got contxt \(chromaprintContext)")
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

