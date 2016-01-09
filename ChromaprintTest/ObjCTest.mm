//
//  ObjCTest.m
//  ChromaprintTest
//
//  Created by teo on 08/01/16.
//  Copyright © 2016 Terminal Glow. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "chromaprint.h"
#import "ObjCTest.h"
#import "balls.h"
//#import <Accelerate/Accellerate.h>

@implementation ChromaprintTestObjC

+ (void)flibble {
    ChromaprintContext *chromaprintContext = chromaprint_new(CHROMAPRINT_ALGORITHM_DEFAULT);
    BALLS nad = BALLS();
    nad.bounce();
    NSLog(@"Hola");
}
@end