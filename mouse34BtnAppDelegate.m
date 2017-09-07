//
//  mouse34BtnAppDelegate.m
//  mouse34Btn
//
//  Created by user on 10.03.17.
//  Copyright © 2017 O.Ivanov. All rights reserved.
//

#import "mouse34BtnAppDelegate.h"

@implementation mouse34BtnAppDelegate

CFMachPortRef eventTap = NULL;
CFMachPortRef mouseTap = NULL;
CGPoint firstLocation = {0,0};
CGPoint lastLocation = {0,0};
bool m_bScroll = false;
int32_t m_bDisScroll = 0;
int32_t m_CountMove = 0;

CGEventRef myCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *ref) {
    switch (type) {
        case kCGEventOtherMouseDown:
        {
            int64_t buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
            switch(buttonNumber){
                case 2:                     //middle mouse button
                {
                    if(m_bDisScroll > 0){   //contextual menu most probably is on
                        if(m_bDisScroll == 2){
                            m_bScroll = true;
                            CGPoint location = CGEventGetLocation(event);
                            firstLocation.x = lastLocation.x = location.x;
                            firstLocation.y = lastLocation.y = location.y;
                        }
                        m_bDisScroll = 0;
                        //send left mouse down event to hide or select contextual menu
                        CGPoint location = CGEventGetLocation(event);
                        CGEventRef clickMouse = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, location, kCGMouseButtonLeft);
                        CGEventSetType(clickMouse, kCGEventLeftMouseDown);
                        CGEventPost(kCGHIDEventTap, clickMouse);
                        CGEventSetType(clickMouse, kCGEventLeftMouseUp);
                        CGEventPost(kCGHIDEventTap, clickMouse);
                        CFRelease(clickMouse);
                        return NULL;
                    }
                    int64_t clickNumbers = CGEventGetIntegerValueField(event, kCGMouseEventClickState);
                    if(clickNumbers == 1){ //single click allow/disable scroll
                        m_bScroll = !m_bScroll;
                    }
                    else if(clickNumbers == 2) { //double click - send Cmd+w to close tab/window where cursor hovers
                        m_bScroll = !m_bScroll;  //double click also calls single click first, so we revert it
                        CGCharCode chKey = 13;   //w
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
                    if(m_bScroll){
                        CGPoint location = CGEventGetLocation(event);
                        firstLocation.x = lastLocation.x = location.x;
                        firstLocation.y = lastLocation.y = location.y;
                        if(mouseTap && !CGEventTapIsEnabled(mouseTap)) {
                            CGEventTapEnable(mouseTap, YES);
                        }
                    }
                    else if(CGEventTapIsEnabled(mouseTap)){
                        CGEventTapEnable(mouseTap, NO);
                    }
					return NULL;
                }
                    break;
					
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
					return NULL;
                }
                    break;
            }
        }
            break;
        
		case kCGEventRightMouseUp:
        {
            CGPoint location = CGEventGetLocation(event);
            location.x += 2;
            CGEventRef moveMouse = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, location, 0); //move the cursor at right on contextual menu
            CGEventPost(kCGHIDEventTap, moveMouse);
            CFRelease(moveMouse);
            //disable scroll until left mouse click to select menu item
            m_bDisScroll = (m_bScroll ? 2 : 1);
            if(m_bScroll){
                m_bScroll = false;
                //hide contextual menu after x sec.
                mouse34BtnAppDelegate* self = (mouse34BtnAppDelegate*)(ref);
                [NSTimer scheduledTimerWithTimeInterval:4.0 target:self
											   selector:@selector(resetScrolling:)
											   userInfo:nil repeats:NO];
            }
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

CGEventRef mouseCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *ref) {
    switch (type) {
        case kCGEventMouseMoved:
        {
            if(m_bScroll){
                int32_t xScroll = 0; // Negative for right
                int32_t yScroll = 0; // Negative for down
                double scroll_speed = 0;
                int32_t mul_lines = 0;
                CGPoint location = CGEventGetLocation(event);
                if(round(lastLocation.x - location.x) != 0.00) xScroll = ((lastLocation.x < location.x)?-1:1);
                if(round(lastLocation.y - location.y) != 0.00) yScroll = ((lastLocation.y < location.y)?-1:1);
                if(fabs(lastLocation.x - location.x) > fabs(lastLocation.y - location.y)){
                    yScroll = 0; //when we move mostly on X make Y still
                    scroll_speed = fabs(lastLocation.x - location.x);
                }
                else {
                    xScroll = 0; //when we move mostly on Y make X still
                    scroll_speed = fabs(lastLocation.y - location.y);
                }
                if(scroll_speed > 20){
                    mul_lines = 3;
                }
                else if(scroll_speed > 8){
                    mul_lines = 2;
                }
                else if(scroll_speed > 4){
                    mul_lines = 1;
                }
                lastLocation.x = location.x;
                lastLocation.y = location.y;
                if((yScroll != 0) || (xScroll != 0)){
                    CGEventRef cgEvent = NULL;
                    if(mul_lines > 0){  //accelerate scrolling
                        cgEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine,
                                                                2,     // Wheels -> 1 for Y-only, 2 for Y-X, 3 for Y-X-Z
                                                                yScroll*mul_lines,
                                                                xScroll*mul_lines);
                    }
                    else {              //slow-down scrolling
                        cgEvent = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel,
                                                                2,     // Wheels -> 1 for Y-only, 2 for Y-X, 3 for Y-X-Z
                                                                yScroll*((scroll_speed > 3)?10:4),
                                                                xScroll*((scroll_speed > 3)?10:4));
                    }
                    CGEventSetType(cgEvent, kCGEventScrollWheel);
                    // Post the CGEvent to the event stream to have it automatically sent to the window under the cursor
                    CGEventPost(kCGHIDEventTap, cgEvent);
                    CFRelease(cgEvent);
                    m_CountMove++; //we need to allow cursor movement a few times, because we need mouseWillMove event instead of MouseMoved
                    if(m_CountMove >= 2){
                        //revert location to where middle button was clicked, this should make cursor still on Y
                        m_CountMove = 0;
                        lastLocation.x = firstLocation.x = location.x; //allow cursor movement on X
                        lastLocation.y = firstLocation.y;
                        CGEventRef moveMouse = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, firstLocation, 0);
                        CGEventPost(kCGHIDEventTap, moveMouse);
                        CFRelease(moveMouse);
                    }
                    //NSLog(@"D(%d, %f)\n", m_CountMove, scroll_speed);
                }
            }
            else if(m_bDisScroll == 2){ //we can't get location in resetScrolling
                CGPoint location = CGEventGetLocation(event);
                firstLocation.x = lastLocation.x = location.x;
                firstLocation.y = lastLocation.y = location.y;
            }
        }
            break;
            
        case kCGEventTapDisabledByTimeout:  //the event tap should be re-enabled
        {
            CGEventTapEnable(mouseTap, YES);
            return NULL;
        }
			break;
    }
    return event;
}

- (void)resetScrolling:(NSTimer*)theTimer
{
    m_bScroll = true;
    m_bDisScroll = 0;
    //send ESC key to hide contextual menu
    CGCharCode chKey = 53;   //Esc
    CGEventRef e;
    CGEventSourceRef eventSource = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    if(eventSource){
        e = CGEventCreateKeyboardEvent (eventSource, chKey, true); //key down
        if(e){
            CGEventPost(kCGHIDEventTap, e);
            CFRelease(e);
        }
        e = CGEventCreateKeyboardEvent (eventSource, chKey, false); //key up
        if(e){
            CGEventPost(kCGHIDEventTap, e);
            CFRelease(e);
        }
        CFRelease(eventSource);
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    CGEventMask eventMask = CGEventMaskBit(kCGEventOtherMouseDown) | CGEventMaskBit(kCGEventRightMouseUp);
    eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault, eventMask, myCGEventCallback, (void*)(self));
    
    //kCGEventMouseMoved takes CPU around 1%, so we should use this only on scroll
    mouseTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault, CGEventMaskBit(kCGEventMouseMoved), mouseCGEventCallback, NULL);
    if(eventTap && mouseTap){
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
        CGEventTapEnable(eventTap, YES);
        CFRelease(runLoopSource);
		
		runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, mouseTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
        CGEventTapEnable(mouseTap, NO);
        CFRelease(runLoopSource);
    }
    else {
        NSLog(@"mouse34Btn must be enabled as an assistive device, allow it in system settings.");
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    if(eventTap) CFRelease(eventTap);
	if(mouseTap) CFRelease(mouseTap);
}

@end
