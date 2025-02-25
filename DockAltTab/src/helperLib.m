//
//  helperLib.m
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import "helperLib.h"

NSDictionary* appAliases = @{
    @"Parallels Mac VM": @"macOS 12 VM",
    @"Visual Studio Code": @"Code",
    @"Adobe Lightroom Classic": @"Lightroom Classic",
    @"iTerm": @"iTerm2",
    @"PyCharm CE": @"PyCharm"
};

//prepare click handling
CGEventTapCallBack handleMouseDown(CGEventTapProxy proxy ,
                                  CGEventType type ,
                                  CGEventRef event ,
                                  void * refcon ) {
    [[helperLib getApp] mousedown:event : type : NO];
    return (CGEventTapCallBack) nil;
}
CGEventTapCallBack handleMouseUp(CGEventTapProxy proxy ,
                                  CGEventType type ,
                                  CGEventRef event ,
                                 void * refcon ) {
    [[helperLib getApp] mouseup:event : type : NO];
    return (CGEventTapCallBack) nil;
}
//listening to monitors attach / detach
void proc(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void* userInfo) {
    if (flags && kCGDisplayAddFlag && kCGDisplayRemoveFlag) {} else return;
    [[helperLib getApp] bindScreens];
}

@implementation helperLib
//formatting
+ (NSString*) twoSigFigs: (float) val {
    return [NSString stringWithFormat:@"%.02f", val];
}
//misc
+ (void) fetchBinary: (NSString*) url : (void(^)(NSData* _Nullable data)) cb {
    [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:url] completionHandler:
        ^(NSData* _Nullable data, NSURLResponse* _Nullable response, NSError * _Nullable error) { cb(data); }
    ] resume];
}
+ (void) fetch: (NSString*) url : (void(^)(NSString* data)) cb { // fetchString
    [self fetchBinary:url : ^(NSData * _Nullable data) {
        cb([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    }];
}
+ (void) fetchJSONArray: (NSString*) url : (void(^)(NSArray* data)) cb {
    [self fetchBinary:url : ^(NSData * _Nullable data) {
        cb([NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:(void*) nil]);
    }];
}
+ (void) fetchJSONDict: (NSString*) url : (void(^)(NSDictionary* data)) cb {
    [self fetchBinary:url : ^(NSData * _Nullable data) {
        cb([NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:(void*) nil]);
    }];
}
+ (NSString*) runScript: (NSString*) scriptTxt {
    NSDictionary *error = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource: scriptTxt];
    if (error) {
        NSLog(@"run error: %@", error);
        return @"";
    }
    return [[script executeAndReturnError:&error] stringValue];
}

// point math / screens
+ (CGPoint) carbonPointFrom:(NSPoint) cocoaPoint {
    NSScreen* screen = [helperLib getScreen:0];
    float menuScreenHeight = NSMaxY([screen frame]);
    return CGPointMake(cocoaPoint.x,  menuScreenHeight - cocoaPoint.y);
}
+ (NSScreen*) getScreen: (int) screenIndex {
    NSScreen* screen = nil;
    int i = 0;
    //check if monitor exist
    for (NSScreen *candidate in [NSScreen screens]) { //loop through screens
        if (i == 0 && !NSPointInRect(NSZeroPoint, [candidate frame])) continue; //the first screen is always zeroed out, other screens have offsets
        screen = candidate;
        if (i++ == screenIndex) break;
    }
    //if    &&  screenIndex  &&  loop return's primary monitor (the only monitor)     =>    screen = nil
    if (screen && screenIndex && ![screen frame].origin.x && ![screen frame].origin.y) screen = nil;
    return screen;
}
+ (void) triggerKeycode:(CGKeyCode) key {
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    CGEventRef down = CGEventCreateKeyboardEvent(src, key, true);
    CGEventRef up = CGEventCreateKeyboardEvent(src, key, false);
    CGEventPost(kCGHIDEventTap, down);
    CGEventPost(kCGHIDEventTap, up);
    CFRelease(down);
    CFRelease(up);
    CFRelease(src);
}


//app stuff
+ (AppDelegate *) getApp {return ((AppDelegate *)[[helperLib sharedApplication] delegate]);}
+ (NSApplication*) sharedApplication {return [NSApplication sharedApplication];}
+ (pid_t) getPID: (NSString*) tar {
    NSArray *appList = [[NSWorkspace sharedWorkspace] runningApplications];
    for (int i = 0; i < appList.count; i++) {
        NSRunningApplication *cur = appList[i];
        if (![tar isEqualTo: cur.bundleIdentifier]) continue;
        return cur.processIdentifier;
    }
    return 0;
}
+ (NSRunningApplication*) runningAppFromAxTitle:(NSString*) tar {
    NSArray *appList = [[NSWorkspace sharedWorkspace] runningApplications];
    for (int i = 0; i < appList.count; i++) {
        NSRunningApplication *cur = appList[i];
        if (![tar isEqualTo: cur.localizedName]) continue;
        return cur;
    }
    return nil;
}

//windows
+ (NSMutableArray*) getWindowsForOwner: (NSString *)owner {
    if (!owner || [@"" isEqual:owner]) return nil;
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    NSMutableArray *ownerWindowList = [NSMutableArray new];
    long int windowCount = CFArrayGetCount(windowList);
    for (int i = 0; i < windowCount; i++) {
        NSDictionary *win = CFArrayGetValueAtIndex(windowList, i);
        if ([@"Firefox.app" isEqualTo:owner] && [[win objectForKey:@"kCGWindowName"] isEqual:@"Picture-in-Picture"]) continue; // ignore PIP firefox windows   --BUT   @kCGWindowName - requires "Screen Recording" permissions
        if ([@"Firefox Developer Edition.app" isEqualTo:owner] && [[win objectForKey:@"kCGWindowName"] isEqual:@"Picture-in-Picture"]) continue; // ignore PIP firefox windows   --BUT   @kCGWindowName - requires "Screen Recording" permissions
        if (![owner isEqualTo:[win objectForKey:@"kCGWindowOwnerName"]]) continue;
        [ownerWindowList addObject:win];
    }
    CFRelease(windowList);
    return ownerWindowList;
}
+ (NSMutableArray*) getWindowsForOwnerPID:(pid_t) PID {
  if (!PID) return nil;
  CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
  NSMutableArray *ownerWindowList = [NSMutableArray new];
  long int windowCount = CFArrayGetCount(windowList);
  for (int i = 0; i < windowCount; i++) {
      NSDictionary *win = CFArrayGetValueAtIndex(windowList, i);
      if ([@"Firefox.app" isEqualTo:[win objectForKey:@"kCGWindowOwnerName"]] && [[win objectForKey:@"kCGWindowName"] isEqual:@"Picture-in-Picture"]) continue; // ignore PIP firefox windows   --BUT   @kCGWindowName - requires "Screen Recording" permissions
      if ([@"Firefox Developer Edition.app" isEqualTo:[win objectForKey:@"kCGWindowOwnerName"]] && [[win objectForKey:@"kCGWindowName"] isEqual:@"Picture-in-Picture"]) continue; // ignore PIP firefox windows   --BUT   @kCGWindowName - requires "Screen Recording" permissions
      if (PID != (pid_t) [[win objectForKey:@"kCGWindowOwnerPID"] intValue]) continue;
      [ownerWindowList addObject:win];
  }
  CFRelease(windowList);
  return ownerWindowList;
}
+ (NSMutableArray*) getRealFinderWindows {
    AppDelegate* del = [helperLib getApp];
    NSMutableArray* finderWins = [helperLib getWindowsForOwner:@"Finder"];
    NSMutableArray *ownerWindowList = [NSMutableArray new];
    for (NSDictionary* win in finderWins) {
        int winLayer = [[win objectForKey:@"kCGWindowLayer"] intValue];
        NSDictionary* bounds = [win objectForKey:@"kCGWindowBounds"];
        float w = [[bounds objectForKey:@"Width"] floatValue];
        float h = [[bounds objectForKey:@"Height"] floatValue];
//        float x = [[bounds objectForKey:@"X"] floatValue];
        float y = [[bounds objectForKey:@"Y"] floatValue];
//        if (winLayer < 0) continue; //winLayer is negative when it's the desktop's "finder" window
//        if (winLayer == 3) continue; //i think this is the desktop's finder window... (no other way to tell but size.x & size.y)
        if (winLayer != 0) continue; //not a standard window
        if (w < 100 || h < 100) continue; //no menu bar windows or teeny tiny windows (not possible anyways i think)
        if (y+h == del->primaryScreenHeight - (del->dockHeight ? del->dockHeight : 80) - 20 - 21) continue; //20 == MENUBARHEIGHT and 21 is where the ghost window shows for me... //todo: seeing if it vary's (the 21)
        [ownerWindowList addObject:win];
    }
    return ownerWindowList;
}
+ (int) numWindowsMinimized: (NSString*) tar {
    int numWindows = 0; //# minimized windows on active space
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll|kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    long int windowCount = CFArrayGetCount(windowList);
    for (int i = 0; i < windowCount; i++) {
        //get dictionary data
        NSDictionary *win = CFArrayGetValueAtIndex(windowList, i);
        if (![tar isEqualTo:[win objectForKey:@"kCGWindowOwnerName"]] || [[win objectForKey:@"kCGWindowLayer"] intValue] != 0) continue;
        // Get the AXUIElement windowList (e.g. elementList)
        int winPID = [[win objectForKey:@"kCGWindowOwnerPID"] intValue];
        AXUIElementRef appRef = AXUIElementCreateApplication(winPID);
        CFArrayRef elementList;
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute, (void *)&elementList);
        CFRelease(appRef);
        bool onActiveSpace = YES;
        //loop through looking for minimized && onActiveSpace
        long int numElements = elementList ? CFArrayGetCount(elementList) : 0;
        for (int j = 0; j < numElements; j++) {
            AXUIElementRef winElement = CFArrayGetValueAtIndex(elementList, j);
            CFBooleanRef winMinimized;
            AXUIElementCopyAttributeValue(winElement, kAXMinimizedAttribute, (CFTypeRef *)&winMinimized);
            if (winMinimized == kCFBooleanTrue && onActiveSpace) numWindows++;
//            CFRelease(winMinimized);
        }
        if (elementList) CFRelease(elementList);
    }
    CFRelease(windowList);
    return numWindows;
}


// AXUIelements
+ (AXUIElementRef) elementAtPoint:(CGPoint) carbonPoint {
    AXUIElementRef elementUnderCursor = NULL;
    AXUIElementCopyElementAtPosition([helperLib getApp]->_systemWideAccessibilityObject, carbonPoint.x, carbonPoint.y, &elementUnderCursor);
    return (__bridge AXUIElementRef)(CFBridgingRelease(elementUnderCursor));
}
+ (NSDictionary*) axInfo:(AXUIElementRef)el {
    NSString *axTitle = nil;
    NSNumber *axIsApplicationRunning;
    pid_t axPID = -1;
    NSString *role;
    NSString *subrole;
    CGSize size;
    CGPoint pt;

    if (el) {
        AXUIElementCopyAttributeValue(el, kAXTitleAttribute, (void *)&axTitle);
        axTitle = appAliases[axTitle] ? appAliases[axTitle] : axTitle; //app's with alias work weird (eg: VScode = Code)
        AXUIElementGetPid(el, &axPID);                                                                      //pid
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute, (void*)&role);                                    //role
        AXUIElementCopyAttributeValue(el, kAXSubroleAttribute, (void*)&subrole);                              //subrole
        AXUIElementCopyAttributeValue(el, kAXIsApplicationRunningAttribute, (void *)&axIsApplicationRunning);  //running?
        AXValueRef sizeAxRef;
        AXUIElementCopyAttributeValue(el, kAXSizeAttribute, (void*) &sizeAxRef);
        AXValueGetValue(sizeAxRef, kAXValueCGSizeType, &size);
        if (sizeAxRef) CFRelease(sizeAxRef);
        CFTypeRef positionRef;
        AXUIElementCopyAttributeValue(el, kAXPositionAttribute, (void*) &positionRef);
        AXValueGetValue(positionRef, kAXValueCGPointType, &pt);

    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
                                !axTitle ? @"" : axTitle, @"title",
                                @([axIsApplicationRunning intValue]), @"running",
                                @(axPID), @"PID",
                                !role ? @"" : role, @"role",
                                !subrole ? @"" : subrole, @"subrole",
                                @(size.width), @"width",
                                @(size.height), @"height",
                                @(pt.x), @"x",
                                @(pt.y), @"y"
                                 , nil];
}
+ (NSDictionary*) appInfo:(NSString*) owner {
    NSMutableArray* windows = [owner isEqual:@"Finder"] ? [helperLib getRealFinderWindows] : [helperLib getWindowsForOwner:owner]; //on screen windows
    //hidden & minimized (off screen windows)
    BOOL isHidden = NO;
    BOOL isMinimized = NO;
    if ([helperLib runningAppFromAxTitle:owner].isHidden) isHidden = YES;
    if ([helperLib numWindowsMinimized:owner]) isMinimized = YES;
    //add missing window(s) (a window can be hidden & minimized @ same time (don't want two entries))
    if (!isHidden && isMinimized) [windows addObject:@123456789]; //todo: properly add these two windowTypes to windowNumberList, but works
    return @{
        @"windows": windows,
        @"numWindows": [NSNumber numberWithInt:(int)[windows count]],
        @"isHidden": [NSNumber numberWithBool:isHidden],
        @"isMinimized": [NSNumber numberWithBool:isMinimized],
    };
}

//dock stuff
+ (void) dockSetting:  (CFStringRef) pref : (BOOL) val { //accepts int or Boolean (as int) settings only
    CFPreferencesSetAppValue(pref, !val ? kCFBooleanFalse : kCFBooleanTrue, CFSTR("com.apple.dock"));
    CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
}
+ (void) dockSettingFloat:  (CFStringRef) pref : (float) val { //accepts int or Boolean (as int) settings only
    CFPreferencesSetAppValue(pref, (__bridge CFPropertyListRef _Nullable)([NSNumber numberWithFloat:val]), CFSTR("com.apple.dock"));
    CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
}
+ (NSString*) getDockPosition {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString* pos = [[defaults persistentDomainForName:@"com.apple.dock"] valueForKey:@"orientation"];
    return pos ? pos : @"bottom";
}
+ (BOOL) dockautohide {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[[defaults persistentDomainForName:@"com.apple.dock"] valueForKey:@"autohide"] intValue] > 0;
}
+ (void) killDock {
    //(Execute shell command) "killall dock"
    NSString* killCommand = [@"/usr/bin/killall " stringByAppendingString:@"Dock"];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[ @"-c", killCommand]];
    [task launch];
}

//event listening
+ (void) listenScreens {CGDisplayRegisterReconfigurationCallback((CGDisplayReconfigurationCallBack) proc, (void*) nil);}
+ (void) listenMouseDown {[helperLib listenMask:CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown) : (CGEventTapCallBack) handleMouseDown];}
+ (void) listenMouseUp {[helperLib listenMask:CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventRightMouseUp) : (CGEventTapCallBack) handleMouseUp];}
+ (void) listenMask : (CGEventMask) emask : (CGEventTapCallBack) handler {
    CFMachPortRef myEventTap;
    CFRunLoopSourceRef eventTapRLSrc;
    myEventTap = CGEventTapCreate (
        kCGSessionEventTap, // Catch all events for current user session
        kCGTailAppendEventTap, // Append to end of EventTap list
        kCGEventTapOptionListenOnly, // We only listen, we don't modify
        emask,
        handler,
        nil // We need no extra data in the callback
    );
    eventTapRLSrc = CFMachPortCreateRunLoopSource( //runloop source
        kCFAllocatorDefault,
        myEventTap,
        0
    );
    CFRunLoopAddSource(// Add the source to the current RunLoop
        CFRunLoopGetCurrent(),
        eventTapRLSrc,
        kCFRunLoopDefaultMode
    );
    CFRelease(eventTapRLSrc);
}
@end
