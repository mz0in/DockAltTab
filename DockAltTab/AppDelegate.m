//
//  AppDelegate.m
//  DockAltTab
//
//  Created by Steven G on 5/6/22.
//

#import "AppDelegate.h"
#import "src/helperLib.h"
#import "src/app.h"
#import "src/globals.h"

/* config */
const int TICKS_TO_HIDE = 2; // number of ticks * TICK_DELAY = x seconds
const NSArray* showBlacklist = @[@"Spotlight Search"]; // title of the app to ignore
/* hardcoded apple details */
const float T_TO_SWITCH_SPACE = 666 / 2; // (ms) time to wait before reshowing dock (when clicking switches spaces)

/* global variables */
BOOL shouldDelayedExpose = NO;
NSString* clickedBeforeDelayedExpose = @""; //appBID clicked on before delay finished
pid_t clickedBeforeDelayedExposePID = 0; //appPID clicked on before delay finished
BOOL clickedAfterExpose = NO;
BOOL dontCheckAgainAfterTrigger = NO; // stop polling AltTab windows to check if user closed it w/ a click (since can't listen for these clicks)
BOOL finderFrontmost = NO;
int spaceSwitchTicks = 0; // no. ticks since spaceSwitch started
CGFloat preSwitchIconSizeWidth = 0; //full icon size while mouse @ coordinates (before switching spaces) --space switch is complete when dimensions match
CGFloat preSwitchIconSizeHeight = 0; //full icon height while mouse @ coordinates (before switching spaces) --space switch is complete when dimensions match
BOOL finishSpaceSwitch = NO;
BOOL finishedSpaceSwitch = NO;

/* show & hide */
int ticksSinceHide = 0;
int ticksSinceShown = 0;
void showOverlay(NSString* appBID, pid_t appPID) {
    AppDelegate* del = [helperLib getApp];
    ticksSinceHide = 0;
    if ([del->appDisplayed isEqual:appBID]) return;
//    NSLog(@"show '%@'  '%@'  %d", del->lastAppClickToggled, clickedBeforeDelayedExpose, del->appDisplayedPID);
    //show immediately flags
    BOOL reopenedAfterSwitch = del->isReopenPreviewsChecked && finishedSpaceSwitch;
    if (!del->previewDelay || reopenedAfterSwitch || (![del->appDisplayed isEqual:@""] && !dontCheckAgainAfterTrigger && [clickedBeforeDelayedExpose isEqual:@""] && [del->lastAppClickToggled isEqual:@""])) { // show immediately
        del->appDisplayed = appBID;
        del->appDisplayedPID = appPID;
        if (![del->appDisplayed isEqual:@""]) [app AltTabHide]; // hide other apps previews
        [app AltTabShow:appBID];
        dontCheckAgainAfterTrigger = NO;
        del->lastAppClickToggled = @"";
        clickedBeforeDelayedExpose = @"";
    } else { // show w/ delay
        shouldDelayedExpose = YES;
        NSString* oldBID = appBID;
        setTimeout(^(void) {
            if (!shouldDelayedExpose) return;
            //delayed show flags
            if (![oldBID isEqual:del->appDisplayed] && ![del->appDisplayed isEqual:@""] && !dontCheckAgainAfterTrigger && [del->lastAppClickToggled isEqual:@""]) return;
            shouldDelayedExpose = NO; // don't run any other setTimeout's
            CGPoint carbonPoint2 = [helperLib carbonPointFrom: [NSEvent mouseLocation]];
            AXUIElementRef el = [helperLib elementAtPoint:carbonPoint2];
            NSDictionary* info2 = [helperLib axInfo:el]; //axTitle, axIsApplicationRunning, axPID, axIsAPplicationRunning
            if (![info2[@"subrole"] isEqual:@"AXApplicationDockItem"] || [app contextMenuExists: carbonPoint2:info2]) return;
            NSURL* appURL;
            AXUIElementCopyAttributeValue(el, kAXURLAttribute, (void*)&appURL);// BID w/ app url
            pid_t tarPID = (pid_t) [info2[@"PID"] integerValue];
            if (tarPID != del->dockPID || (tarPID == del->dockPID && ![[[NSBundle bundleWithURL:appURL] bundleIdentifier] isEqual:oldBID])) { } else {
                del->appDisplayed = oldBID;
                del->appDisplayedPID = appPID;
                if (![clickedBeforeDelayedExpose isEqual: oldBID]) {
                    if (![del->appDisplayed isEqual:@""]) [app AltTabHide]; // hide other apps previews
                    [app AltTabShow:oldBID];
                }
                dontCheckAgainAfterTrigger = NO;
                del->lastAppClickToggled = @"";
                clickedBeforeDelayedExpose = @"";
            }
        }, (int) ( ((float) del->previewDelay / 100 /* slider range */) * 2 /* slider max val */ * 1000 /* msec */) );
    }
    clickedAfterExpose = NO;
    ticksSinceShown = 0;
}
void hideOverlay(pid_t mousePID, NSString* appBID, pid_t appPID) {
    if (ticksSinceHide++ < TICKS_TO_HIDE) return;
    AppDelegate* del = [helperLib getApp];
    if ([del->appDisplayed isEqual:@""]) return;
    del->appDisplayedPID = (pid_t) 0;
    finishedSpaceSwitch = NO;
    if ([clickedBeforeDelayedExpose isEqual:del->appDisplayed]) {
        if (mousePID == del->dockPID) {
            if (![del->appDisplayed isEqual:appBID]) clickedBeforeDelayedExpose = @"";
        } else {
            if (appPID != clickedBeforeDelayedExposePID) clickedBeforeDelayedExpose = @"";
        }
        return;
    }
    del->appDisplayed = @"";
    [app AltTabHide];
    clickedAfterExpose = NO;
    dontCheckAgainAfterTrigger = NO;
}
const CGFloat ICONFUZZINESS = 0.1; //middle of icon = largest dimensions, top & bottom = +- 0.5px of the middle max
BOOL isSpaceSwitchComplete(CGFloat dockWidth, CGFloat dockHeight) { //todo: consider comparing icon positions instead (more accurate?)
    if (preSwitchIconSizeWidth == 0 && preSwitchIconSizeWidth == 0) return YES;
    CGFloat diffW = fabs(dockWidth - preSwitchIconSizeWidth);
    CGFloat diffH = fabs(dockHeight - preSwitchIconSizeHeight);
    if ((++spaceSwitchTicks >= 5 && diffW <= ICONFUZZINESS && diffH <= ICONFUZZINESS) || spaceSwitchTicks >= 10) {
        preSwitchIconSizeWidth = 0;
        preSwitchIconSizeHeight = 0;
        return YES;
    }
    return NO;
}

/*
    AppDelate
*/
@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@end
@implementation AppDelegate
    @synthesize isMenuItemChecked;
    @synthesize isClickToggleChecked;
    @synthesize isReopenPreviewsChecked;
    @synthesize previewDelay;
    @synthesize dockDelay;
    @synthesize isLockDockContentsChecked;
    @synthesize isLockDockSizeChecked;
    @synthesize isLockDockPositionChecked;
/*
   General / Event Listener Methods
*/
- (void)timerTick: (NSTimer*) arg {
    NSPoint mouseLocation = [NSEvent mouseLocation];
    CGPoint pt = [helperLib carbonPointFrom:mouseLocation];
    AXUIElementRef el = [helperLib elementAtPoint:pt];
    NSMutableDictionary* info = [NSMutableDictionary dictionaryWithDictionary: [helperLib axInfo:el]];
    pid_t tarPID = [info[@"PID"] intValue];

    if ((autohide || isReopenPreviewsChecked) && !isSpaceSwitchComplete(dockWidth, dockHeight)) return;
    //update dock size, if on dock icon
    if ([info[@"role"] isEqual:@"AXDockItem"]) {
        dockWidth = [info[@"width"] floatValue];
        dockHeight = [info[@"height"] floatValue];
    }
    if (tarPID == AltTabPID) {
        ticksSinceHide = 0;
        return;
    }
    wasShowingContextMenu = [app contextMenuExists:pt : info];
    if (wasShowingContextMenu) return;
    NSString* elBID = @"";
    NSString* tarBID = @"";
    if ([info[@"subrole"] isEqual:@"AXApplicationDockItem"]) {
        NSURL* appURL;
        AXUIElementCopyAttributeValue(el, kAXURLAttribute, (void*)&appURL);// BID w/ app url
        elBID = [[NSBundle bundleWithURL:appURL] bundleIdentifier];
        tarBID = elBID;
        tarPID = [helperLib getPID:tarBID]; // tarPID w/ BID
    } else { /* tarBID w/ tarPID */}
    
    // ? willShowOverlay
    BOOL willShow = [info[@"running"] intValue] && [info[@"subrole"] isEqual:@"AXApplicationDockItem"];
    int numWindows = willShow ? (int) [[helperLib getWindowsForOwnerPID:tarPID] count] : 0; // hidden / minimized windows not included
    if (willShow && [info[@"title"] isEqual:@"Parallels Mac VM"]) numWindows = 1; //if running - 1 window (but numWindows can't see it) //todo: why???
    if (willShow && numWindows == 0) {
        if ([helperLib runningAppFromAxTitle: info[@"title"]].isHidden) numWindows = 1;
        else numWindows = [helperLib numWindowsMinimized:info[@"title"]];
        if (numWindows == 0) willShow = NO;
    }

    if (![appDisplayed isEqual:@""] && [info[@"title"] isEqual:@"Spotlight Search"] && !dontCheckAgainAfterTrigger) {
        int ATWindowCount = (int) [[helperLib getWindowsForOwnerPID: AltTabPID] count];
        if (!ATWindowCount) {
            [app sendClick: pt];
            dontCheckAgainAfterTrigger = YES;
        }
    }

    // clicked to close AltTab previews - check if AltTab still open (todo: factor in closing by Esc key)
    if (![appDisplayed isEqual:@""] && !clickedAfterExpose && !dontCheckAgainAfterTrigger && ticksSinceShown > 1 && [clickedBeforeDelayedExpose isEqual:@""]) {
        int ATWindowCount = (int) [[helperLib getWindowsForOwnerPID: AltTabPID] count];
        if (!ATWindowCount) {
            if ([info[@"PID"] intValue] == dockPID && [appDisplayed isEqual:elBID]) {
                [self bindClick: (CGEventRef) nil : kCGEventLeftMouseDown : YES];
                dontCheckAgainAfterTrigger = YES;
//                NSLog(@"click to close");
            }
        }
    }
    if ([showBlacklist containsObject: info[@"title"]]) willShow = NO;
    if (willShow && ![appDisplayed isEqual:@""]) ticksSinceShown++;
    willShow && ![clickedBeforeDelayedExpose isEqual: tarBID] ? showOverlay(tarBID, tarPID) : hideOverlay([info[@"PID"] intValue], tarBID, tarPID);
//    NSLog(@"%@ %d",  willShow ? @"y" : @"n", numWindows);
}
- (void) enableClickToClose {clickedBeforeDelayedExpose = @"";clickedAfterExpose = NO;dontCheckAgainAfterTrigger = NO;ticksSinceShown = 2;} //NSLog(@"%d %d %d %d %d", ![appDisplayed isEqual:@""], !clickedAfterExpose, isClickToggleChecked, !dontCheckAgainAfterTrigger, ticksSinceShown > 1);
- (void) reopenPreview : (NSString*) cachedApp {
    setTimeout(^{ //wait until cached app guaranteed to be hidden
        NSRunningApplication* frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
        //apps that are slow to activate (well, technically they auto-activate, but the actual window gets keyboard focus slowly (ie: red yellow green buttons are grey), which adds them to the AltTab popup)
        //todo: find a less hackish method of preventing this preview addition (currently do so by synchronously clogging DockAltTab's thread (until it can tell/talk to the offending process window w/ applescript))
        BOOL isExtraSlow = ![cachedApp isEqual:@"org.mozilla.firefox"] && [[frontApp bundleIdentifier] isEqual:@"org.mozilla.firefox"];
        if (isExtraSlow) [helperLib runScript:[NSString stringWithFormat:@"tell application \"System Events\" to tell process \"%@\" to return window 1", [frontApp localizedName]]]; //tell application \"System Events\" to tell process \"Firefox\" to return enabled of menu item \"Minimize\" of menu 1 of menu bar item \"Window\" of menu bar 1    //original menu item check to see if ready, don't think it worked
        //show cached app previews & enable "click to close" (to unhide)
        [app AltTabShow:cachedApp];
        setTimeout(^{[self enableClickToClose];}, 67); //wait until AltTab guaranteed to be visible
    }, 90);
}
- (void) reopenDock { // reopen / focus the dock w/ fn + a (after switching spaces)
    if (isReopenPreviewsChecked) finishSpaceSwitch = YES; // call reopenPreview --after finished hiding
    if (!autohide) return; //don't reopen dock
    setTimeout(^{[helperLib runScript: [app reopenDockStr:YES]];}, T_TO_SWITCH_SPACE);
}
- (void) dockItemClickHide: (CGPoint)carbonPoint : (AXUIElementRef) el : (NSDictionary*)info : (BOOL) clickToClose {
    NSString* clickTitle = info[@"title"];
    pid_t clickPID = [info[@"PID"] intValue];
    if (![clickTitle isEqual:@"Trash"] && ![clickTitle isEqual:@"Finder"]) if (clickPID != finderPID) finderFrontmost = NO;
//    clickPID = [helperLib getPID:clickBID]; // tarPID w/ BID
    NSString* clickBID = @"";
    BOOL isBlacklisted = [showBlacklist containsObject:clickTitle];
    if ([clickTitle isEqual:@"Trash"]) {
        if (!finderFrontmost) finderFrontmost = YES;
        else {
            clickTitle = @"Finder";
            clickBID = @"com.apple.Finder";
    //        lastAppClickToggled = @"com.apple.Finder";
        }
    } else {
        NSURL* appURL;
        AXUIElementCopyAttributeValue(el, kAXURLAttribute, (void*)&appURL);// BID w/ app url
        clickBID = ((pid_t) [info[@"PID"] intValue] != dockPID || ![info[@"role"] isEqual:@"AXDockItem"]) || appURL == nil ? @"" : [[NSBundle bundleWithURL:appURL] bundleIdentifier];
    }
    if (![appDisplayed isEqual:@""] && !dontCheckAgainAfterTrigger && ticksSinceShown > 1) [app AltTabHide]; // "hiding" solely to reset preview position (AltTabHide does that...)   --part of the clickToClose conditions from timerTick

    
    //checks to continue
//    NSLog(@"'%@': %d, '%@', '%d', '%@'", appDisplayed, appDisplayedPID, lastAppClickToggled, clickedAfterExpose, clickedBeforeDelayedExpose);
    clickedBeforeDelayedExpose = clickBID;
    clickedBeforeDelayedExposePID = clickPID;
    if (![showBlacklist containsObject:clickTitle]) appDisplayed = clickBID;
    if (!isClickToggleChecked) return;
    __block BOOL showingContextMenu = [app contextMenuExists: carbonPoint:info]; //checks if contextMenu exists (but only looks around area cursor's placed)
    if (wasShowingContextMenu || showingContextMenu) {
        wasShowingContextMenu = NO;
        return;
    }
    if ((pid_t) [info[@"PID"] intValue] != dockPID || ![info[@"role"] isEqual:@"AXDockItem"]) return;
    if (![clickBID isEqual: appDisplayed] && ![clickBID isEqual: lastAppClickToggled] && (/*!clickedAfterExpose &&*/ !isBlacklisted)) return;
    if (![clickBID isEqual:@""]) lastAppClickToggled = clickBID;
    if ([clickTitle isEqual:@"Trash"] && finderFrontmost) return;

    NSRunningApplication* runningApp = [helperLib runningAppFromAxTitle:clickTitle];
    BOOL wasAppHidden = [runningApp isHidden];

    // reopen preview when clicks switches spaces && reopen dock w/ autohide turned on (consistent toggle click behavior)
    if ((autohide || isReopenPreviewsChecked) && !clickToClose && ![info[@"title"] isEqual: @"Trash"] && !wasAppHidden && [runningApp isActive]) {
        BOOL willSwitchSpace = [[helperLib runScript: [NSString stringWithFormat:@"tell application \"AltTab\" to set allCount to countWindows appBID \"%@\"\n\
        tell application \"System Events\" to tell process \"%@\" to return allCount - (count of windows)", appDisplayed, clickTitle]] intValue] != 0; // if app has windows in another spaces, (YES) clicking will switch
        if (willSwitchSpace) {
            preSwitchIconSizeWidth = dockWidth;
            preSwitchIconSizeHeight = dockHeight;
            dockWidth = preSwitchIconSizeWidth - (ICONFUZZINESS + 0.1); //"reset" width by barely going outside of range
            dockHeight = preSwitchIconSizeHeight - (ICONFUZZINESS + 0.1); //"reset" height by barely going outside of range
            spaceSwitchTicks = 0;
            finishedSpaceSwitch = NO;
            [self reopenDock];
        }
    }
    
    if (clickToClose) { // activate/unhide when clicking dock icon while AltTab showing
        if (wasAppHidden && ![appDisplayed isEqual:@""]) [runningApp unhide];
        if (![runningApp isActive]) [app activateApp: runningApp];
        return;
    }
    
    if (![runningApp isActive]) return;
    int oldProcesses = (int) [[clickTitle isEqual:@"Finder"] ? [helperLib getRealFinderWindows] : [helperLib getWindowsForOwner:clickTitle] count]; //on screen windows
    float countProcessT = (wasAppHidden) ? 0 : 333; //only skip timeout if:  app is hidden (which means it's already running (ie. not launching / opening a new window))
//    if (!clickToClose && autohide) countProcessT = 2000;
    CGFloat cachedW = preSwitchIconSizeWidth;       // hack to stop timer ticks & clicks (return; early) while in the middle of delayed hiding
    if (countProcessT) preSwitchIconSizeWidth = 1; // hack to stop timer ticks & clicks (return; early) while in the middle of delayed hiding
    setTimeout(^{
        preSwitchIconSizeWidth = cachedW; //undo hiding hack
        if (countProcessT) {
            //test for context menu (x time after click)
            CGPoint carbonPoint2 = [helperLib carbonPointFrom: [NSEvent mouseLocation]];
            NSDictionary* info2 = [helperLib axInfo:[helperLib elementAtPoint:carbonPoint2]]; //axTitle, axIsApplicationRunning, axPID, axIsAPplicationRunning
            if ((pid_t)[info2[@"PID"] intValue] != self->dockPID) return;
            showingContextMenu = [app contextMenuExists: carbonPoint2:info2]; //checks if contextMenu exists (but only looks around area cursor's placed)
            if (showingContextMenu) return;
        }
        
        //show / hide
        int numProcesses = (int) [[clickTitle isEqual:@"Finder"] ? [helperLib getRealFinderWindows] : [helperLib getWindowsForOwner:clickTitle] count]; //on screen windows
        if ((![self->appDisplayed isEqual:@""] && [self->lastAppClickToggled isEqual:@""]) || numProcesses != oldProcesses) {
            [app activateApp: runningApp]; //order of operations important (keep here) (above toggle update)
            return;
        }
        if ([runningApp isHidden] != wasAppHidden) return; //something already changed, don't change it further
        if (clickedAfterExpose || ![runningApp isHidden]) {
            [runningApp hide];
            clickedAfterExpose = YES;
        }else [app activateApp: runningApp];
        
        if (!finishSpaceSwitch) return; //isReopenPreviewsChecked:  show the preview (after switching spaces)
        finishSpaceSwitch = NO;
        finishedSpaceSwitch = YES;
        [self reopenPreview : clickBID];
    }, countProcessT);
}
- (void) bindClick: (CGEventRef) e : (CGEventType) etype : (BOOL) clickToClose {
    BOOL isOverlayShowing = ![appDisplayed isEqual:@""];
    BOOL rightBtn = (etype == kCGEventRightMouseDown);
    NSUInteger theFlags = [NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
    BOOL ctrlDown = theFlags & NSEventModifierFlagControl;
    BOOL optDown = theFlags & NSEventModifierFlagOption;
    BOOL cmdDown = theFlags & NSEventModifierFlagCommand;
    BOOL shiftDown = theFlags & NSEventModifierFlagShift;
    CGPoint carbonPoint = [helperLib carbonPointFrom: [NSEvent mouseLocation]];
    AXUIElementRef el = [helperLib elementAtPoint:carbonPoint];
    NSDictionary* info = [helperLib axInfo:el];
    
//    /* uncomment to restrict log to dock clicks */ if ([info[@"role"] isEqual:@"AXDockItem"])
//    /* uncomment to restrict log all clicks */        NSLog(@"%@ - ctrl=%d opt=%d cmd=%d shift=%d    steviaOS=%d, clicktoClose=%d", rightBtn ? @"right" : @"left", ctrlDown, optDown, cmdDown, shiftDown || [[helperLib runScript:@"tell application \"AltTab\" to keyState key \"Shift\""] isEqual:@"true"], steviaOS, clickToClose);
    
    // right clicks
    if (rightBtn) {
        if ([info[@"PID"] intValue] == dockPID) {
            wasShowingContextMenu = YES;
            if (isOverlayShowing && !dontCheckAgainAfterTrigger) {
                [app AltTabHide];
                dontCheckAgainAfterTrigger = YES; // prevent "clickToClose" from triggering
                // only modify trackpad clicks from double taps
//                if (CGEventGetIntegerValueField(e, kCGMouseEventSubtype) == 3 && isTrackpadDoubleTap) { // is trackpad? (virtual BTT trackpad clicks don't count (they're 0))   defaults read com.apple.AppleMultitouchTrackpad "TrackpadRightClick"
//                    AXUIElementPerformAction(el, CFSTR("AXShowMenu"));
//                    NSLog(@"trackpad two finger tap struggles");
//                }
                
                
                //modify all devices
//                [helperLib runScript:@""]; // setTimeout/dispatch_after blocks are unable to see dock el's, but blocking thread like this works
                
//                carbonPoint = [helperLib carbonPointFrom: [NSEvent mouseLocation]];
//                el = [helperLib elementAtPoint:carbonPoint];
//                NSString* oldTitle = info[@"title"];
//                info = [helperLib axInfo:el];
//
//                if ([app contextMenuExists:carbonPoint : info])  return NSLog(@"contextMenuExists -> rightClick");
//                if (![info[@"title"] isEqual:oldTitle]) return NSLog(@"too much movement");
//                AXUIElementPerformAction(el, CFSTR("AXShowMenu"));
//                NSLog(@" obj-c show contextmenu");
            }
        } else {} // ignore clicks not on dock
        return;
    }
    if (wasShowingContextMenu) {
        wasShowingContextMenu = NO;
        return; // NSLog(@"wasShowingContextMenu");
    }
    //else{ //    [helperLib runScript:@"delay .333"];
//        if ([app contextMenuExists:carbonPoint : info]) {
//            wasShowingContextMenu = NO;
//            [helperLib runScript:@"tell application \"System Events\" to key code 53"]; // send escape key to close (sometimes two contextmenu's pop up)
//            return NSLog(@"contextMenuExists -> left click -> esc");
//        }
//    }

//    NSLog(@"left click no menu");
    // left clicks
    if ((isOverlayShowing || [info[@"title"] isEqual:@"Trash"]) && !clickToClose) clickedAfterExpose = YES;
    if ([info[@"PID"] intValue] == dockPID) {
        if (ctrlDown) {
            if (clickToClose && isOverlayShowing) AXUIElementPerformAction(el, CFSTR("AXShowMenu"));
            return; // [Control] + Click:  always prevent clickToggle
        } else if (optDown) {return;} else if (cmdDown) { // [Option] + Click:  always prevent clickToggle
            if (steviaOS && clickToClose && isOverlayShowing) { // only runScript if overlay still visible (because overlay hides keystrokes from BTT)
                NSString *path = [NSString stringWithFormat:@"%@/click-cmd-cycle-windows.scpt", steviaOSSystemFiles];
                NSTask *task = [[NSTask alloc] init];// BTT trigger_named  has ~ 7sec delay (on this script only)
                NSString *commandToRun = [NSString stringWithFormat:@"/usr/bin/osascript -e \'run script \"%@\"'", path];

                NSArray *arguments = [NSArray arrayWithObjects: @"-c" , commandToRun, nil];
                [task setLaunchPath:@"/bin/sh"];
                [task setArguments:arguments];
                [task launch];
            }
           return; // [Command] + Click:  always prevent clickToggle
        } else {
            shiftDown = shiftDown || [[helperLib runScript:@"tell application \"AltTab\" to keyState key \"Shift\""] isEqual:@"true"]; // overlay absorbs modifier keys => get true keyState from AltTab
            if (steviaOS && shiftDown && clickToClose && isOverlayShowing) [helperLib runScript:@"tell application \"BetterTouchTool\" to trigger_named \"shiftClick\""];
            if (shiftDown) return; // [Shift] + Click: always prevent clickToggle
        }
     }
    
    if ([info[@"role"] isEqual:@"AXDockItem"]) {
        dockWidth = [info[@"width"] floatValue];
        dockHeight = [info[@"height"] floatValue];
    }
    if (!isSpaceSwitchComplete(dockWidth, dockHeight)) return;
    [self dockItemClickHide: carbonPoint : el : info : clickToClose];
}
- (void) bindScreens { //todo: 1 external display only atm 👁👄👁
    NSScreen* primScreen = [helperLib getScreen:0];
    NSScreen* extScreen = [helperLib getScreen:1];
    primaryScreenWidth = NSMaxX([primScreen frame]);
    primaryScreenHeight = NSMaxY([primScreen frame]);
    extScreenWidth = [extScreen frame].size.width;
    extScreenHeight =  [extScreen frame].size.height;
    extendedOffsetX = [extScreen frame].origin.x;
    extendedOffsetY = [extScreen frame].origin.y;
    extendedOffsetYBottom = !extScreen ? 0 : fabs(primaryScreenHeight - extScreenHeight) - extendedOffsetY;
}


/*
    Bindings & LifeCycle
*/
/* Links Box */
- (IBAction)homeLink:(id)sender {[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://DockAltTab.netlify.app"]];}
- (IBAction)donateLink:(id)sender {[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://DockAltTab.netlify.app/#donate"]];}
- (IBAction)releasesLink:(id)sender {[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/steventheworker/DockAltTab/releases"]];}
- (IBAction)sourceLink:(id)sender {[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/steventheworker/DockAltTab/issues"]];}
- (IBAction)discordLink:(id)sender {[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://discord.com/invite/f54j8hHxdJ"]];}
- (IBAction)linksBoxToggle:(id)sender {
    [LinksBox setHidden: ![LinksBox isHidden]];
    if ([LinksBox isHidden]) { //send to bottom of stack
        NSView* superview = [LinksBox superview];
        [LinksBox removeFromSuperview];
        [superview addSubview:LinksBox positioned:NSWindowBelow relativeTo:nil];
    } else { //send to top of stack
        NSView* superview = [LinksBox superview];
        [LinksBox removeFromSuperview];
        [superview addSubview: LinksBox];
    }
}

/* Bindings / UI handlers */
- (IBAction) preferences:(id)sender {
    NSColor* titColor;NSString* tit;
    if (!mostCurrentVersion) mostCurrentVersion = [app getCurrentVersion];
    BOOL greaterVersion = mostCurrentVersion != nil && [appVersion floatValue] > [mostCurrentVersion floatValue];
    if (mostCurrentVersion == NULL) [[updateRemindRef cell] setTitle: @"No internet; Update check failed"];
    else {
        if (greaterVersion) {
            tit = @"This is a pre⚙️release.";
            titColor = [NSColor systemBlueColor];
        } else if ([mostCurrentVersion isEqual:appVersion]) {
            tit = @"You're on the latest release.";
            titColor = [NSColor greenColor];
        } else {
            tit = [@"Version " stringByAppendingString: [mostCurrentVersion stringByAppendingString: @" has been released. You should update soon."]];
            titColor = [NSColor redColor];        }
    }
    [NSApp activateIgnoringOtherApps:YES];
    [_window makeKeyAndOrderFront:nil];
    [[appVersionRef cell] setTitle: greaterVersion ? [NSString stringWithFormat:@"v%@ >v%@", appVersion, mostCurrentVersion] : [@"v" stringByAppendingString: appVersion]];
    [[updateRemindRef cell] setTitle: tit];
    [updateRemindRef setTextColor: titColor];
}
- (IBAction)kill:(id)sender {
    [helperLib killDock];
    setTimeout(^{self->dockPID = [helperLib getPID:@"com.apple.dock"];}, 1000); //wait for new Dock process to relaunch so we can get the new PID
    dockPos = [helperLib getDockPosition]; // update dockPos on restart dock
    autohide = [helperLib dockautohide]; // update dockPos on restart dock
}
- (IBAction)AltTabRestart:(id)sender {
    dockPos = [helperLib getDockPosition]; // update dockPos on restart AltTab
    NSURL* appPath = [[helperLib runningAppFromAxTitle:@"AltTab"] executableURL];
    //(Execute shell command) "kill -9 AltTabPID"
    NSString* killCommand = [@"kill -9 " stringByAppendingString:[@(AltTabPID) stringValue]];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[ @"-c", killCommand]];
    [task launch];
    //make sure old process dead
    setTimeout(^{
        if (appPath) { //relaunch w/ path (shell)
            NSError *error = nil;
            NSArray *arguments = [NSArray new]; // [NSArray arrayWithObjects:@"Argument1", @"Argument2", nil];
            [[NSWorkspace sharedWorkspace] launchApplicationAtURL:appPath options:0 configuration:[NSDictionary dictionaryWithObject:arguments forKey:NSWorkspaceLaunchConfigurationArguments] error:&error];
        } else [helperLib runScript:@"tell application \"AltTab\" to activate"]; //no running AltTab, relaunch w/ applescript
        //make sure new process spawned
        setTimeout(^{
           self->AltTabPID = [helperLib getPID:@"com.steventheworker.alt-tab-macos"];
            if (self->AltTabPID == 0) {
                self->unsupportedAltTab = YES;
                [app viewToFront: self->unsupportedBox];
                self->AltTabPID = [helperLib getPID:@"com.lwouis.alt-tab-macos"];
                [self preferences:nil];
            } else {
                self->unsupportedAltTab = NO;
                [self->unsupportedBox setHidden: YES];
            }
        }, 1220);
    }, 333);
}

/* DockAltTab setting handlers */
- (IBAction)toggleMenuIcon:(id)sender {[statusItem setVisible:isMenuItemChecked];}
- (IBAction)toggleToggleDockApps:(id)sender {isClickToggleChecked = clickToggleCheckBox.state;[[NSUserDefaults standardUserDefaults] setBool: !((BOOL) clickToggleCheckBox.state) forKey:@"isClickToggleChecked"];}  // (!) default true
- (IBAction)bindReopenPreviewsSetting:(id)sender {isReopenPreviewsChecked = reopenPreviewsCheckbox.state;[[NSUserDefaults standardUserDefaults] setBool: ((BOOL) reopenPreviewsCheckbox.state) forKey:@"isReopenPreviewsChecked"];}  // (!) default false
- (IBAction)changeDelay:(id)sender {
    [[delayLabel cell] setTitle: [helperLib twoSigFigs: previewDelaySlider.floatValue / 100 * 2]]; // set slider label text
    [[NSUserDefaults standardUserDefaults] setInteger:previewDelaySlider.intValue forKey:@"previewDelay"];
}
- (IBAction) quit:(id)sender {[NSApp terminate:nil];}
- (IBAction)toggleMenuItem:(id)sender {[statusItem setVisible:isMenuItemChecked];}
- (IBAction)unsupportedMoreInfoClick:(id)sender {[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/lwouis/alt-tab-macos/pull/1590#issuecomment-1131809994"]];}
- (IBAction)unsupportedDownloadClick:(id)sender {[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/steventheworker/alt-tab-macos/releases/download/1.2/DockAltTab.AltTab.v6.46.1.zip"]];}

/* dock setting handlers */
- (IBAction)lockDockPosition:(id)sender {[helperLib dockSetting: CFSTR("position-immutable") : (BOOL) lockDockPositionCheckbox.state];}
- (IBAction)lockDockSize:(id)sender {[helperLib dockSetting: CFSTR("size-immutable") : (BOOL) lockDockSizeCheckbox.state];}
- (IBAction)lockDockContents:(id)sender {[helperLib dockSetting: CFSTR("contents-immutable") : (BOOL) lockDockContentsCheckbox.state];}
- (IBAction)setDockDelay:(float)setVal { //onSubmit / enter key / "Continuously Updates Value" checked in bindings
    setVal = dockDelayInput.floatValue;
    if (setVal < 0) setVal = dockDelay;
    dockDelay = setVal;
    NSLog(@"%f", setVal);
    [helperLib dockSettingFloat: CFSTR("autohide-delay") : setVal];
    dockDelayInput.floatValue = setVal;
}


/* Lifecycle */
- (void) awakeFromNib {
    isClickToggleChecked = YES;
    clickToggleCheckBox.state = YES;
    menuItemCheckBox.state = YES;
    //set menu bar item/icon
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSSquareStatusItemLength];
    [[statusItem button] setImage:[NSImage imageNamed:@"MenuIcon"]];
    [statusItem setMenu:menu];
    [statusItem setVisible:YES]; //without this, could stay hidden away
    if (!menuItemCheckBox.state) [statusItem setVisible:NO];
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {[app init];}
- (void)dealloc {//    [super dealloc]; //todo: why doesn't this work
    [timer invalidate];
    timer = nil;
    if (_systemWideAccessibilityObject) CFRelease(_systemWideAccessibilityObject);
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {/* Insert code here to tear down your application */}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {return NO;}
- (void)setNilValueForKey:(NSString *)key // nil UI handling
{
    if ([key isEqual:@"dockDelay"]) dockDelayInput.floatValue = dockDelay; // reset text field value on empty (nil)
}
@end
