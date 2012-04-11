//
//  TestAPPThread.m
//  APPThread-Example
//
//  Created by Anton Pavlyuk on 06.04.12.
//  Copyright (c) 2012 iHata. All rights reserved.
//

#import "TestAPPThread.h"

@implementation TestAPPThread

+ (void)load
{
    [self registerMethodsToExecuteOnlyInThisThread:@selector(awesomeArrayWithFirstObject:), @selector(testClassMethod)];
}

- (NSArray *)awesomeArrayWithFirstObject:(id)obj
{
    NSLog(@"awesomeArrayWithFirstObject methodThread = %@", [NSThread currentThread]);
    NSArray *array = [NSArray arrayWithObjects:obj, @"secondObject_string", [NSNumber numberWithInt:3], nil];
    return array;
}

+ (void)testClassMethod
{
    NSLog(@"testClassMethod methodThread = %@", [NSThread currentThread]);
}

@end
