//
//  mouse34BtnAppDelegate.m
//  mouse34Btn
//
//  Created by user on 10.03.17.
//  Copyright © 2017 O.Ivanov. All rights reserved.
//

#import "mouse34BtnAppDelegate.h"

@implementation mouse34BtnAppDelegate

CFMachPortRef eventTap;

CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *ref) {
    switch (type) {
        case kCGEventOtherMouseDown:
        {
            int64_t buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
            switch(buttonNumber){
                case 3:
                case 4:
                {
                    CGCharCode chKey = 8;   //copy -> Cmd+C
                    if (buttonNumber == 4){
                        chKey = 9;          //paste -> Cmd+V
                    }
                    CGEventRef e;
                    CGEventSourceRef eventSource = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
                    if(eventSource){
                        e = CGEventCreateKeyboardEvent (eventSource, (CGKeyCode)55, true); //Cmd down
                        if(e){
                            CGEventPost(kCGHIDEventTap, e);
                            CFRelease(e);
                        }
                        e = CGEventCreateKeyboardEvent (eventSource, chKey, true); //key down
                        if(e){
                            CGEventSetFlags(e, kCGEventFlagMaskCommand);
                            CGEventPost(kCGHIDEventTap, e);
                            CFRelease(e);
                        }
                        e = CGEventCreateKeyboardEvent (eventSource, chKey, false); //key up
                        if(e){
                            CGEventSetFlags(e, kCGEventFlagMaskCommand);
                            CGEventPost(kCGHIDEventTap, e);
                            CFRelease(e);
                        }
                        e = CGEventCreateKeyboardEvent (eventSource, (CGKeyCode)55, false); //Cmd up
                        if(e){
                            CGEventPost(kCGHIDEventTap, e);
                            CFRelease(e);
                        }
                        CFRelease(eventSource);
                    }
                }
                    break;
            }
            return NULL;
        }
            break;
            
        case kCGEventTapDisabledByTimeout:
        case kCGEventTapDisabledByUserInput: //the event tap should be re-enabled
        {
            CGEventTapEnable(eventTap, YES);
            return NULL;
        }
            break;
    }
    return event;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    CGEventMask eventMask = CGEventMaskBit(kCGEventOtherMouseDown);
    eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault, eventMask, myCGEventCallback, NULL);
    
    if(eventTap){
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
        CGEventTapEnable(eventTap, YES);
        CFRelease(runLoopSource);
    }
    else {
        NSLog(@"mouse34Btn must be enabled as an assistive device, allow it in system settings.");
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    if(eventTap) CFRelease(eventTap);
}

@end
