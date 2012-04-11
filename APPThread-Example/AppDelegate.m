//
//  AppDelegate.m
//  APPThread-Example
//
//  Created by Anton Pavlyuk on 06.04.12.
//  Copyright (c) 2012 iHata. All rights reserved.
//

#import "AppDelegate.h"
#import "TestAPPThread.h"

@implementation AppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"mainThread (before) = %@", [NSThread currentThread]);
    TestAPPThread *testThread = [[TestAPPThread alloc] init];
    [testThread start];
    NSArray *array = [testThread awesomeArrayWithFirstObject:@"first"];
    [TestAPPThread testClassMethod];
    NSLog(@"returned object from restThread = %@", array);
    NSLog(@"mainThread (after) = %@", [NSThread currentThread]);
    
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window addSubview:[self label]];
    [self.window makeKeyAndVisible];
    return YES;
}

- (UILabel *)label
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 220.0, 320.0, 40.0)];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = UITextAlignmentCenter;
    label.textColor = [UIColor blackColor];
    label.font = [UIFont boldSystemFontOfSize:20.0];
    label.text = @"See logs";
    
    return label;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
