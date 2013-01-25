//
//  APPReturnThread.m
//
//  Created by Anton Pavlyuk on 04.04.12.
//  Copyright (c) 2012 iHata. All rights reserved.
//

#import "APPThread.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const NSString *kAPPMethodPrefix = @"__";
static NSString *APPThreadPortName;

static const NSUInteger kSelfPtrKey = 0;
static const NSUInteger kSelectorKey = 1;
static const NSUInteger kArgumentsKey = 2;

void generateAPPThreadPortName(Class class);
void createAPPThreadMessagePort(id selfPtr);
CFDataRef sendMessageToAPPThreadMessagePortWithData(CFDataRef data, id selfPtr);
CFDataRef APPThreadLocalPortCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info);
void APPThreadLocalPortInvalidationCallBack(CFMessagePortRef ms, void *info);

@interface NSData (APPThreadData)
+ (NSData *)dataWithValue:(NSValue *)value;
@end

@implementation NSData (APPThreadData)

+ (NSData *)dataWithValue:(NSValue *)value
{
    NSUInteger size;
    const char *encoding = [value objCType];
    NSGetSizeAndAlignment(encoding, &size, NULL);
    
    void *ptr = malloc(size);
    [value getValue:ptr];
    NSData *data = [NSData dataWithBytes:ptr length:size];
    free(ptr);
    
    return data;
}

@end

@interface APPThread ()
@property (retain, readonly) NSObject *APPNil;
@property CFMessagePortRef APPThreadLocalPort;
@property CFRunLoopSourceRef runLoopSource;
@property (retain, atomic) id APPReturnObject;
@end

@implementation APPThread
{
    BOOL keepThreadAllive;
}

@synthesize APPNil = APPNil_;
@synthesize APPThreadLocalPort = APPThreadLocalPort_;
@synthesize APPReturnObject = APPReturnObject_;
@synthesize runLoopSource = runLoopSource_;

- (id)init
{
    self = [super init];
    if (self) {
        APPNil_ = [[NSNull null] retain];
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"dealloc WTF");
//    CFMessagePortInvalidate(APPThreadLocalPort_);
//    CFRelease(APPThreadLocalPort_);
//    //CFRunLoopStop(CFRunLoopGetCurrent());
    
    [APPNil_ release];
    self.APPReturnObject = nil;
    [super dealloc];
}

- (void)main
{
    @autoreleasepool {
        keepThreadAllive = YES;
        if (!APPThreadPortName && !APPThreadLocalPort_) {
            generateAPPThreadPortName(self.class);
            createAPPThreadMessagePort(self);
        }
        
        //CFRunLoopRun();
        do {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        } while (keepThreadAllive);
    }
}

- (void)invalidate
{
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource_, kCFRunLoopDefaultMode);
    CFRelease(runLoopSource_);
    
    CFMessagePortInvalidate(APPThreadLocalPort_);
    CFRelease(APPThreadLocalPort_);
    
    keepThreadAllive = NO;
}

#pragma mark - Redirect IMP

id redirectIMP(id self, SEL _cmd, ...)
{
    id returnObject = nil;
    
    @synchronized (self) {
        
        SEL selector = _cmd; // _cmd = someMethod
        NSString *selectorStr = NSStringFromSelector(selector);
        // modify @selector(someMethod) to @selector(___someMethod) to reach real IMP of the -someMethod
        selectorStr = [NSString stringWithFormat:@"%@%@", kAPPMethodPrefix, selectorStr];
        selector = NSSelectorFromString(selectorStr);
        
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
        
        [invocation setSelector:selector];
        
        BOOL isInstanceMethod = YES;
        Method realMethod = class_getInstanceMethod([self class], _cmd);
        Class metaClass;
        if (realMethod == NULL) {
            metaClass = objc_getMetaClass(class_getName([self class]));
            realMethod = class_getClassMethod(metaClass, _cmd);
            isInstanceMethod = NO;
        }
        
        NSUInteger numberOfArguments = method_getNumberOfArguments(realMethod);
        
        va_list argumentList = NULL;
        NSMutableArray *args = [NSMutableArray array];
        if (numberOfArguments > 2) {
            id eachObject;
            NSUInteger index = 2;
            
            va_start(argumentList, NULL);
            while ((eachObject = va_arg(argumentList, id))) {
                [invocation setArgument:&eachObject atIndex:index];
                if (eachObject) {
                    [args addObject:eachObject];
                } else {
                    [args addObject:[self APPNil]];
                }
                if (index == numberOfArguments - 2 + 1) {
                    break;
                }
                index++;
            }
            va_end(argumentList);
        }
        
        [invocation retainArguments];
        
        if (isInstanceMethod) {
            
            //        const char *methodReturnType = [invocation.methodSignature methodReturnType];
            //        const char *voidReturn = @encode(void);
            //        if (*methodReturnType == *voidReturn) {
            //            [self performSelector:@selector(handleInvocation:) onThread:self withObject:invocation waitUntilDone:NO];
            //            return nil;
            //        }
            
            NSMutableArray *mutArray = [NSMutableArray arrayWithCapacity:3];
            [mutArray insertObject:self atIndex:kSelfPtrKey];
            [mutArray insertObject:NSStringFromSelector(selector) atIndex:kSelectorKey];
            [mutArray insertObject:args atIndex:kArgumentsKey];
            
            NSValue *value = [NSValue value:&mutArray withObjCType:@encode(NSMutableArray *)];
            NSData *data = [NSData dataWithValue:value];
            
            CFDataRef dataRef = ( CFDataRef)data;
            
            CFDataRef returnDataRef = sendMessageToAPPThreadMessagePortWithData(dataRef, self);
            
            //NSLog(@"redirectIMP before retainCount = %ld", CFGetRetainCount(returnDataRef));
            
            if (returnDataRef) {
                
                CFIndex dataLength = CFDataGetLength(returnDataRef);
                if (dataLength > 0) {
                    NSData *returnData = (NSData *)returnDataRef;
                    NSValue *returnValue = [NSValue valueWithBytes:[returnData bytes] objCType:[invocation.methodSignature methodReturnType]];
                    //[returnValue getValue:&returnObject];
                    if (returnValue) {
                        returnObject = [[returnValue nonretainedObjectValue] retain];
                        [[self APPReturnObject] autorelease];
                        //returnObject = [self APPReturnObject];
                        //                    NSLog(@"APPReturnObject = %@", [self APPReturnObject]);
                        //                    NSLog(@"returnObject = %@", returnObject);
                    }
                    
                    if (returnDataRef) {
                        //NSLog(@"retainCount when release = %ld", CFGetRetainCount(returnDataRef));
                        if (CFGetRetainCount(returnDataRef) > 1) {
                            CFRelease(returnDataRef);
                        } else {
                            [(NSData *)returnDataRef autorelease];
                        }
                    }
                    
                } else {
                    CFRelease(returnDataRef);
                }
            }
            
            //NSLog(@"redirectIMP after retainCount = %ld", CFGetRetainCount(returnDataRef));
            
        } else {
            [NSThread detachNewThreadSelector:@selector(handleInvocation:) toTarget:self withObject:invocation];
        }
    }
    
    return returnObject;
}

- (void)handleInvocation:(NSInvocation *)anInvocation
{
	[anInvocation invokeWithTarget:self];
}

+ (void)handleInvocation:(NSInvocation *)anInvocation
{
	[anInvocation invokeWithTarget:self];
}

#pragma mark - Methods registration

+ (void)registerMethodsToExecuteOnlyInThisThread:(SEL)method1, ...
{
    @autoreleasepool {
        
        SEL selector;
        va_list argumentList = NULL;
        
        [self createFakeMethodForSelector:method1];
        
        if (method1) // The first argument isn't part of the varargs list, 
        {                                   
            va_start(argumentList, method1);
            while ((selector = va_arg(argumentList, SEL))) {
                [self createFakeMethodForSelector:selector];
            }
            va_end(argumentList);
        }
    }
}

+ (void)createFakeMethodForSelector:(SEL)aSelector
{
    BOOL isInstanceMethod = YES;
    
    Method realMethod = class_getInstanceMethod(self, aSelector);
    
    if (realMethod == NULL) {
        realMethod = class_getClassMethod(self, aSelector);
        isInstanceMethod = NO;
    }
    
    if (realMethod == NULL) {
        return;
    }
    
    const char *types = method_getTypeEncoding(realMethod);
    NSString *fakeMethodStr = NSStringFromSelector(aSelector);
    fakeMethodStr = [NSString stringWithFormat:@"%@%@", kAPPMethodPrefix, fakeMethodStr];
    SEL fakeMethodSEL = NSSelectorFromString(fakeMethodStr);
    
    Method fakeMethod;
    if (isInstanceMethod) {
        class_addMethod(self, fakeMethodSEL, (IMP)redirectIMP, types);
        fakeMethod = class_getInstanceMethod(self, fakeMethodSEL);
    } else {
        Class metaCalss = objc_getMetaClass(class_getName(self));
        class_addMethod(metaCalss, fakeMethodSEL, (IMP)redirectIMP, types);
        fakeMethod = class_getClassMethod(self, fakeMethodSEL);
    }
    method_exchangeImplementations(realMethod, fakeMethod);
}

#pragma mark - CFMessagePort

void generateAPPThreadPortName(Class class)
{
    APPThreadPortName = [[NSString stringWithFormat:@"%@%@%@", kAPPMethodPrefix, NSStringFromClass(class), kAPPMethodPrefix] retain];
}

void createAPPThreadMessagePort(id selfPtr)
{
    //CFMessagePortRef localPort = NULL; 
    //CFRunLoopSourceRef runLoopSource;  
    ((APPThread *)selfPtr).APPThreadLocalPort = CFMessagePortCreateLocal(kCFAllocatorDefault, // allocator 
                                                                         (CFStringRef)APPThreadPortName, // name for registering the port 
                                                                         &APPThreadLocalPortCallBack, // call this when message received 
                                                                         NULL, // contextual information 
                                                                         NULL); // free "info" field of context?
    
    if (((APPThread *)selfPtr).APPThreadLocalPort == NULL) { 
        fprintf(stderr, "*** CFMessagePortCreateLocal\n");
        createAPPThreadMessagePort(selfPtr);
    } else {
        //CFMessagePortSetInvalidationCallBack([(APPThread *)selfPtr APPThreadLocalPort], APPThreadLocalPortInvalidationCallBack);
        ((APPThread *)selfPtr).runLoopSource = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, // allocator 
                                                         ((APPThread *)selfPtr).APPThreadLocalPort, // create run-loop source for this port 
                                                         0); // priority index 
        CFRunLoopAddSource(CFRunLoopGetCurrent(), ((APPThread *)selfPtr).runLoopSource, kCFRunLoopDefaultMode); 
        CFRunLoopWakeUp(CFRunLoopGetCurrent());
        //CFRelease(runLoopSource); 
        //CFRelease(localPort);
    }
}

CFDataRef sendMessageToAPPThreadMessagePortWithData(CFDataRef data, id selfPtr)
{
    if (!APPThreadPortName) {
        generateAPPThreadPortName([selfPtr class]);
    }
    if (!((APPThread *)selfPtr).APPThreadLocalPort) {
        createAPPThreadMessagePort(selfPtr);
    }
    
    CFMessagePortRef remote = CFMessagePortCreateRemote(kCFAllocatorDefault, (CFStringRef)APPThreadPortName);
    CFDataRef returnData = NULL;
    if (remote == NULL) {
        NSLog(@"remote is NULL");
        //returnData = APPThreadLocalPortCallBack(NULL, 0, data, NULL);
        
    } else {
        if (kCFMessagePortSuccess != CFMessagePortSendRequest(remote, 0, 
                                                              data, 5.0, 5.0, kCFRunLoopDefaultMode, &returnData)) {
            NSLog(@"Message port %@ failed to receive request", remote);
        }
        CFRelease(remote);
    }
    //NSLog(@"sendMessage retainCount = %ld", CFGetRetainCount(returnData));
    return returnData;
}

CFDataRef APPThreadLocalPortCallBack(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) 
{
    NSMutableArray *array = nil;
    NSValue *incomeValue = [NSValue valueWithBytes:[(NSData *)data bytes] objCType:@encode(NSMutableArray *)];
    [incomeValue getValue:&array];
    
    id args = [array objectAtIndex:kArgumentsKey];
    id selfPtr = [array objectAtIndex:kSelfPtrKey];
    SEL selector = NSSelectorFromString([array objectAtIndex:kSelectorKey]);
    
    /*********** Sorry for this govnocode ***********/
    
    id first = nil;
    id second = nil;
    id third = nil;
    id fourth = nil;
    id fifth = nil;
    id sixth = nil;
    id seven = nil;
    id eight = nil;
    id nine = nil;
    id ten = nil;
    
    for (int i = 0; i < [args count]; i++) {
        id obj = [args objectAtIndex:i];
        switch (i) {
            case 0:
                if (obj != [selfPtr APPNil]) {
                    first = obj;
                }
                break;
            case 1:
                if (obj != [selfPtr APPNil]) {
                    second = obj;
                }
                break;
            case 2:
                if (obj != [selfPtr APPNil]) {
                    third = obj;
                }
                break;
            case 3:
                if (obj != [selfPtr APPNil]) {
                    fourth = obj;
                }
                break;
            case 4:
                if (obj != [selfPtr APPNil]) {
                    fifth = obj;
                }
                break;
            case 5:
                if (obj != [selfPtr APPNil]) {
                    sixth = obj;
                }
                break;
            case 6:
                if (obj != [selfPtr APPNil]) {
                    seven = obj;
                }
                break;
            case 7:
                if (obj != [selfPtr APPNil]) {
                    eight = obj;
                }
                break;
            case 8:
                if (obj != [selfPtr APPNil]) {
                    nine = obj;
                }
                break;
            case 9:
                if (obj != [selfPtr APPNil]) {
                    ten = obj;
                }
                break;
                
            default:
                break;
        }
    }
    
    //NSLog(@"callBackThread = %@, main = %@, self = %@", [NSThread currentThread], [NSThread mainThread], selfPtr);
    
    id returnObject = nil;
    const char *methodReturnType = [[selfPtr methodSignatureForSelector:selector] methodReturnType];
    const char *voidReturn = @encode(void);
    
    if (*methodReturnType == *voidReturn) {
        objc_msgSend(selfPtr, selector, first, second, third, fourth, fifth, sixth, seven, eight, nine, ten);
    } else {
        returnObject = objc_msgSend(selfPtr, selector, first, second, third, fourth, fifth, sixth, seven, eight, nine, ten);
    }
    
    NSData *myData = nil;
    CFDataRef myDataRef = NULL;
    if (returnObject) {
        [selfPtr setAPPReturnObject:returnObject];
        
        NSValue *value = [NSValue value:&returnObject withObjCType:methodReturnType];
        myData = [[NSData dataWithValue:value] retain];
        myDataRef = (CFDataRef)myData;
    }
    //NSLog(@"callback retainCount = %ld", CFGetRetainCount(myDataRef));
    return myDataRef;
}

void APPThreadLocalPortInvalidationCallBack(CFMessagePortRef ms, void *info)
{
    NSLog(@"messagePort invalidate :(");
}

@end
