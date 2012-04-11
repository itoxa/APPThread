//
//  APPReturnThread.h
//
//  Created by Anton Pavlyuk on 04.04.12.
//  Copyright (c) 2012 iHata. All rights reserved.
//
/*
    How to use it:
 
    1. Drag APPThread files to your project;
    2. if your project uses ARC set -fno-objc-arc compiler flag for APPThread.m file;
    3. subclass APPThread;
    4. ovverride: + (void)load { [self registerMethodsToExecuteOnlyInThisThread:myMethod1, ..., nil]; }, 
        where myMethod1, ... - (instance) methods, which you want to execute only on this thread;
    5. call -start method of your APPThread subclass.
 
    LIMITATIONS:
 
    - If your method1, ... are class methods - each of these methods will be executed on a new separate thread.
    - All your registered class methods (method1, ...) should return only void and take only arguments of type id.
    - All your registered instance methods (method1, ...) may return void or id and take only arguments of type id.
    - Your registered instance methods should take no more than 10 arguments per one method.
    - You should initialize only one instance of your APPThread subclass.
 
    NOTES:
    
    - Registered instance methods won't invoke if method -start wasn't been called before.
    - If your registered instance method returns some object, this object will be returned in thread, from which method
        was called.
 
    TODO:
    - Covenient way to stop the thread.
*/

#import <Foundation/Foundation.h>

@interface APPThread : NSThread

+ (void)registerMethodsToExecuteOnlyInThisThread:(SEL)method1, ...;

@end
