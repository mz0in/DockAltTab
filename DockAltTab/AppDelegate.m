//
//  AppDelegate.m
//  DockAltTab
//
//  Created by Steven G on 5/6/22.
//

#import "AppDelegate.h"
#import "src/helperLib.h"
#import "src/app.h"

/* config */
const int TICKS_TO_HIDE = 2; // number of ticks * TICK_DELAY = x seconds

/* hardcoded apple details */
const float T_TO_SWITCH_SPACE = 0.666 / 2; // time to wait before reshowing dock (when clicking switches spaces)

/* global variables */
BOOL shouldDelayedExpose = NO;
NSString* clickedBeforeDelayedExpose = @""; //appBID clicked on before delay finished
BOOL clickedAfterExpose = NO;
BOOL dontCheckAgainAfterTrigger = NO; // stop polling AltTab windows to check if user closed it w/ a click (since can't listen for these clicks)
BOOL finderFrontmost = NO;
int spaceSwitchTicks = 0; // no. ticks since spaceSwitch started
CGFloat preSwitchIconSizeWidth = 0; //full icon size while mouse @ coordinates (before switching spaces) --space switch is complete when dimensions match
CGFloat preSwitchIconSizeHeight = 0; //full icon height while mouse @ coordinates (before switching spaces) --space switch is complete when dimensions match
BOOL finishSpaceSwitch = NO;
BOOL reopenPreviewsChecked = YES;

/* show & hide */
int ticksSinceHide = 0;
int ticksSinceShown = 0;
void showOverlay(NSString* appBID, pid_t appPID) {
    AppDelegate* del = [helperLib getApp];
    ticksSinceHide = 0;
    if ([del->appDisplayed isEqual:appBID]) return;
    if (!del->previewDelay || (![del->appDisplayed isEqual:@""] && !dontCheckAgainAfterTrigger && ![clickedBeforeDelayedExpose isEqual:del->appDisplayed])) { // show immediately
        del->appDisplayed = appBID;
        del->appDisplayedPID = appPID;
        if (![del->appDisplayed isEqual:@""]) [app AltTabHide]; // hide other apps previews
        [app AltTabShow:appBID];
        dontCheckAgainAfterTrigger = NO;
    } else { // show w/ delay
        shouldDelayedExpose = YES;
        NSString* oldBID = appBID;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * (((float)del->previewDelay / 100) * 2)), dispatch_get_main_queue(), ^(void){
            if (!shouldDelayedExpose) return;
            if (![oldBID isEqual:del->appDisplayed] && ![del->appDisplayed isEqual:@""] && !dontCheckAgainAfterTrigger) return;
            shouldDelayedExpose = NO; // don't run any other dispatch_after's
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
            }
        });
    }
    clickedBeforeDelayedExpose = @"";
    clickedAfterExpose = NO;
    ticksSinceShown = 0;
    del->lastAppClickToggled = @"";
}
void hideOverlay(void) {
    if (ticksSinceHide++ < TICKS_TO_HIDE) return;
    AppDelegate* del = [helperLib getApp];
    if ([del->appDisplayed isEqual:@""]) return;
    del->appDisplayedPID = (pid_t) 0;
    if ([clickedBeforeDelayedExpose isEqual:del->appDisplayed]) {
        dontCheckAgainAfterTrigger = YES;
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

@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@end
@implementation AppDelegate
    @synthesize isMenuItemChecked;
    @synthesize isClickToggleChecked;
    @synthesize previewDelay;
    @synthesize isLockDockContentsChecked;
    @synthesize isLockDockSizeChecked;
    @synthesize isLockDockPositionChecked;
/* app */
- (void)timerTick: (NSTimer*) arg {
    NSPoint mouseLocation = [NSEvent mouseLocation];
    CGPoint pt = [helperLib carbonPointFrom:mouseLocation];
    AXUIElementRef el = [helperLib elementAtPoint:pt];
    NSMutableDictionary* info = [NSMutableDictionary dictionaryWithDictionary: [helperLib axInfo:el]];
    pid_t tarPID = [info[@"PID"] intValue];

    if ((autohide || reopenPreviewsChecked) && !isSpaceSwitchComplete(dockWidth, dockHeight)) return;
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

    // clicked to close AltTab previews - check if AltTab still open (todo: factor in closing by Esc key)
    if (![appDisplayed isEqual:@""] && !clickedAfterExpose && isClickToggleChecked && !dontCheckAgainAfterTrigger && ticksSinceShown > 1) {
        int ATWindowCount = (int) [[helperLib getWindowsForOwnerPID: AltTabPID] count];
        if (!ATWindowCount) {
            if ([info[@"PID"] intValue] == dockPID && [appDisplayed isEqual:elBID]) {
                [self bindClick: (CGEventRef) nil : YES];
                dontCheckAgainAfterTrigger = YES;
            }
        }
    }
    
    if (willShow && ![appDisplayed isEqual:@""]) ticksSinceShown++;
    willShow && ![clickedBeforeDelayedExpose isEqual: tarBID] ? showOverlay(tarBID, tarPID) : hideOverlay();
//    NSLog(@"%@ %d",  willShow ? @"y" : @"n", numWindows);
}
- (void) enableClickToClose {clickedBeforeDelayedExpose = @"";clickedAfterExpose = NO;dontCheckAgainAfterTrigger = NO;ticksSinceShown = 2;} //NSLog(@"%d %d %d %d %d", ![appDisplayed isEqual:@""], !clickedAfterExpose, isClickToggleChecked, !dontCheckAgainAfterTrigger, ticksSinceShown > 1);
- (void) reopenPreview : (NSString*) cachedApp {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.067), dispatch_get_main_queue(), ^(void){ //wait until cached app guaranteed to be hidden
        NSRunningApplication* frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
        //apps that are slow to activate (well, technically they auto-activate, but the actual window gets keyboard focus slowly (ie: red yellow green buttons are grey), which adds them to the AltTab popup)
        //todo: find a less hackish method of preventing this preview addition (currently do so by synchronously clogging DockAltTab's thread (until it can tell/talk to the offending process window w/ applescript))
        BOOL isExtraSlow = ![cachedApp isEqual:@"org.mozilla.firefox"] && [[frontApp bundleIdentifier] isEqual:@"org.mozilla.firefox"];
        if (isExtraSlow) [helperLib runScript:[NSString stringWithFormat:@"tell application \"System Events\" to tell process \"%@\" to return window 1", [frontApp localizedName]]]; //tell application \"System Events\" to tell process \"Firefox\" to return enabled of menu item \"Minimize\" of menu 1 of menu bar item \"Window\" of menu bar 1    //original menu item check to see if ready, don't think it worked
        //show cached app previews & enable "click to close" (to unhide)
        [app AltTabShow:cachedApp];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.067), dispatch_get_main_queue(), ^(void){[self enableClickToClose];}); //wait until AltTab guaranteed to be visible
    });
}
- (void) reopenDock: (BOOL) triggerEscape { // reopen / focus the dock w/ fn + a (after switching spaces)
    if (reopenPreviewsChecked) finishSpaceSwitch = YES; // call reopenPreview --after finished hiding
    if (!autohide) return; //don't reopen dock
    NSString* triggerEscapeStr = @"";
    if (triggerEscape) triggerEscapeStr = @"        delay 0.15\n\
        key code 53";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * T_TO_SWITCH_SPACE), dispatch_get_main_queue(), ^(void){
        NSString* scriptStr = [NSString stringWithFormat:@"tell application \"System Events\"\n\
            key down 63\n\
            key code 0\n\
            key up 63\n%@\n\
        end tell", triggerEscapeStr];
        [helperLib runScript: scriptStr];
    });
}
- (void) dockItemClickHide: (CGPoint)carbonPoint : (AXUIElementRef) el :(NSDictionary*)info : (BOOL) clickToClose {
    NSString* clickTitle = info[@"title"];
    if (![clickTitle isEqual:@"Trash"] && ![clickTitle isEqual:@"Finder"]) {
        pid_t clickPID = [info[@"PID"] intValue];
        if (clickPID != finderPID) finderFrontmost = NO;
    }
//    clickPID = [helperLib getPID:clickBID]; // tarPID w/ BID
    NSString* clickBID = @"";
    BOOL isBlacklisted = NO; //todo: = [showBlacklist containsObject:clickTitle];
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
        clickBID = appURL == nil ? @"non-dock item" : [[NSBundle bundleWithURL:appURL] bundleIdentifier];
    }
    
    //checks to continue
//    NSLog(@"'%@', '%@'", appDisplayed, lastAppClickToggled);
    clickedBeforeDelayedExpose = clickBID;
    appDisplayed = clickBID;
    if (!isClickToggleChecked) return;
    __block BOOL showingContextMenu = [app contextMenuExists: carbonPoint:info]; //checks if contextMenu exists (but only looks around area cursor's placed)
    if (wasShowingContextMenu || showingContextMenu) {
        wasShowingContextMenu = NO;
        return;
    }
    if ((pid_t) [info[@"PID"] intValue] != dockPID || ![info[@"role"] isEqual:@"AXDockItem"]) return;
    if (![clickBID isEqual: appDisplayed] && ![clickBID isEqual: lastAppClickToggled] && (/*!clickedAfterExpose &&*/ !isBlacklisted)) return;
    if ([clickTitle isEqual:@"Trash"] && finderFrontmost) return;

    NSRunningApplication* runningApp = [helperLib runningAppFromAxTitle:clickTitle];
    BOOL wasAppHidden = [runningApp isHidden];

    // reopen preview when clicks switches spaces && reopen dock w/ autohide turned on (consistent toggle click behavior)
    if ((autohide || reopenPreviewsChecked) && !clickToClose && ![info[@"title"] isEqual: @"Trash"] && !wasAppHidden && [runningApp isActive]) {
        BOOL willSwitchSpace = [[helperLib runScript: [NSString stringWithFormat:@"tell application \"AltTab\" to set allCount to countWindows appBID \"%@\"\n\
        tell application \"System Events\" to tell process \"%@\" to return allCount - (count of windows)", appDisplayed, clickTitle]] intValue] != 0; // if app has windows in another spaces, (YES) clicking will switch
        if (willSwitchSpace) {
            preSwitchIconSizeWidth = dockWidth;
            preSwitchIconSizeHeight = dockHeight;
            dockWidth = preSwitchIconSizeWidth - (ICONFUZZINESS + 0.1); //"reset" width by barely going outside of range
            dockHeight = preSwitchIconSizeHeight - (ICONFUZZINESS + 0.1); //"reset" height by barely going outside of range
            spaceSwitchTicks = 0;
            [self reopenDock: YES];
        }
    }
    
    if (clickToClose) { // activate/unhide when clicking dock icon while AltTab showing
        if (wasAppHidden && ![appDisplayed isEqual:@""]) [runningApp unhide];
        if (![runningApp isActive]) [runningApp activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        lastAppClickToggled = clickBID; //order of operations important (keep here) (below activate)
        [app AltTabHide]; // hiding solely to reset preview position (AltTabHide does that...)
        return;
    }
    
    if (![runningApp isActive]) return;
    int oldProcesses = (int) [[clickTitle isEqual:@"Finder"] ? [helperLib getRealFinderWindows] : [helperLib getWindowsForOwner:clickTitle] count]; //on screen windows
    float countProcessT = (wasAppHidden) ? 0 : 0.333; //only skip timeout if:  app is hidden (which means it's already running (ie. not launching / opening a new window))
//    if (!clickToClose && autohide) countProcessT = 2;
    CGFloat cachedW = preSwitchIconSizeWidth;       // hack to stop timer ticks & clicks (return; early) while in the middle of delayed hiding
    if (countProcessT) preSwitchIconSizeWidth = 1; // hack to stop timer ticks & clicks (return; early) while in the middle of delayed hiding
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * countProcessT), dispatch_get_main_queue(), ^(void){
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
            [runningApp activateWithOptions:NSApplicationActivateIgnoringOtherApps]; //order of operations important (keep here) (above toggle update)
            self->lastAppClickToggled = clickBID; //order of operations important (keep here) (below activate)
            return;
        }
        self->lastAppClickToggled = clickBID; //order of operations important (keep here)
        if ([runningApp isHidden] != wasAppHidden) return; //something already changed, don't change it further
        if (clickedAfterExpose) [runningApp hide]; else [runningApp activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        
        if (!finishSpaceSwitch) return; //reopenPreviewsChecked:  show the preview (after switching spaces)
        finishSpaceSwitch = NO;
        [self reopenPreview : clickBID];
    });
    
    
//    NSLog(@"%d", ++spaceSwitchCounter);
//    if (autohide) {
//        BOOL willSwitchSpace = [[helperLib runScript: [NSString stringWithFormat:@"tell application \"AltTab\" to set allCount to countWindows appBID \"%@\"\n\
//        tell application \"System Events\" to tell process \"%@\" to return allCount - (count of windows)", appDisplayed, clickTitle]] intValue] != 0; // if app has windows in another spaces, (YES) clicking will switch
//        if (willSwitchSpace) {
//            if (spaceSwitchCounter % 4 == 0) {
//                lastAppClickToggled = clickBID;
//                NSLog(@"switching!!!");
//                if (!clickToClose) [app refocusDock: YES];
//                return;
//            }
//            if (spaceSwitchCounter % 2 == 0) {
//                [runningApp hide]; //immediately hiding prevents space switching, //todo: find less hackish method
//                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.2), dispatch_get_main_queue(), ^(void){
//                    [runningApp activateWithOptions:NSApplicationActivateIgnoringOtherApps];
//                });
//            }
//        }
//    }

    // autohide means dock is hidden (after switching spaces), so we reshow it here
//    if (autohide) {
//        NSString* winCountAllSpaces = [helperLib runScript:[NSString stringWithFormat:@"tell application \"AltTab\" to return countWindows appBID \"%@\"", appDisplayed]];
//        NSLog(@"%d", (int) [[helperLib getWindowsForOwnerPID: appDisplayedPID] count] );
//        if ([winCountAllSpaces intValue] > 1) {
//            if (spaceSwitchCounter % 2 == 0) {
//                [runningApp isHidden] ? 1 : [runningApp hide];
//            }
//            else {
//                if (!clickToClose) [app refocusDock: YES];
//            }
//        }
//    }
}
- (void) bindClick: (CGEventRef) e : (BOOL) clickToClose {
    NSUInteger theFlags = [NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
    BOOL cmdDown = theFlags & NSEventModifierFlagCommand;
    BOOL shiftDown = theFlags & NSEventModifierFlagShift;
    CGPoint carbonPoint = [helperLib carbonPointFrom: [NSEvent mouseLocation]];
    AXUIElementRef el = [helperLib elementAtPoint:carbonPoint];
    NSDictionary* info = [helperLib axInfo:el];
    if ((![appDisplayed isEqual:@""] || [info[@"title"] isEqual:@"Trash"]) && !clickToClose) clickedAfterExpose = YES;
    
    if (clickToClose && steviaOS) {
        if (![appDisplayed isEqual:@""]) { // if AltTab showing
            if (shiftDown) {
                [helperLib runScript:@"tell application \"BetterTouchTool\" to trigger_named \"shiftClick\""];
//                return;
            }
            if (cmdDown && [info[@"PID"] intValue] == dockPID) {
                [helperLib runScript:@"tell application \"BetterTouchTool\" to trigger_named \"cmdClick\""];
//                return;
            }
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


/* UI */
- (IBAction) preferences:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [_window makeKeyAndOrderFront:nil];
    if (!mostCurrentVersion)
        mostCurrentVersion = [app getCurrentVersion];
    [[appVersionRef cell] setTitle:[@"v" stringByAppendingString:appVersion]];
    if (mostCurrentVersion == NULL) [[updateRemindRef cell] setTitle: @"No internet; Update check failed"];
    else {
        if (mostCurrentVersion == appVersion) {
            [[updateRemindRef cell] setTitle: @"You're on the latest release."];
            [updateRemindRef setTextColor:[NSColor greenColor]];
        } else {
            [[updateRemindRef cell] setTitle: [@"Version " stringByAppendingString: [mostCurrentVersion stringByAppendingString: @" has been released. You should update soon."]]];
            [updateRemindRef setTextColor:[NSColor redColor]];
        }
    }
    [[updateRemindRef cell] setTitle: mostCurrentVersion == NULL ? @"No internet; Update check failed" : (mostCurrentVersion == appVersion) ? @"You're on the latest release." : [@"Version " stringByAppendingString: [mostCurrentVersion stringByAppendingString: @" has been released. You should update soon."]]];
}
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
- (IBAction)toggleMenuIcon:(id)sender {[statusItem setVisible:isMenuItemChecked];}
- (IBAction)toggleToggleDockApps:(id)sender {[[NSUserDefaults standardUserDefaults] setBool: !((BOOL) clickToggleCheckBox.state) forKey:@"isClickToggleChecked"];}  // (!) default true
- (IBAction)changeDelay:(id)sender {
    [[delayLabel cell] setTitle: [helperLib twoSigFigs: previewDelaySlider.floatValue / 100 * 2]]; // set slider label text
    [[NSUserDefaults standardUserDefaults] setInteger:previewDelaySlider.intValue forKey:@"previewDelay"];
}
- (IBAction) quit:(id)sender {[NSApp terminate:nil];}
- (IBAction)toggleMenuItem:(id)sender {[statusItem setVisible:isMenuItemChecked];}
- (IBAction)unsupportedMoreInfoClick:(id)sender {[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/lwouis/alt-tab-macos/pull/1590#issuecomment-1131809994"]];}
- (IBAction)unsupportedDownloadClick:(id)sender {[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/steventheworker/alt-tab-macos/releases/download/1.1/DockAltTab.AltTab.v6.46.1.zip"]];}
/* dock settings */
- (IBAction)lockDockPosition:(id)sender {[helperLib dockSetting: CFSTR("position-immutable") : (BOOL) lockDockPositionCheckbox.state];}
- (IBAction)lockDockSize:(id)sender {[helperLib dockSetting: CFSTR("size-immutable") : (BOOL) lockDockSizeCheckbox.state];}
- (IBAction)lockDockContents:(id)sender {[helperLib dockSetting: CFSTR("contents-immutable") : (BOOL) lockDockContentsCheckbox.state];}
- (IBAction)kill:(id)sender {
    [helperLib killDock];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1), dispatch_get_main_queue(), ^(void){
        self->dockPID = [helperLib getPID:@"com.apple.dock"];  //wait for new Dock process to relaunch so we can get the new PID
    });
    dockPos = [helperLib getDockPosition]; // update dockPos on restart dock
    autohide = [helperLib dockautohide]; // update dockPos on restart dock
}
- (IBAction)AltTabRestart:(id)sender {
    dockPos = [helperLib getDockPosition]; // update dockPos on restart AltTab
    //(Execute shell command) "kill -9 AltTabPID"
    NSString* killCommand = [@"kill -9 " stringByAppendingString:[@(AltTabPID) stringValue]];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[ @"-c", killCommand]];
    [task launch];
    //make sure old process dead
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.333), dispatch_get_main_queue(), ^(void){
        //launch w/ applescript
        NSDictionary *error = nil;
        NSString* scriptTxt = @"tell application \"AltTab\" to activate";
        NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptTxt];
        [script executeAndReturnError:&error];
        if (error) NSLog(@"run error: %@", error);
        //make sure new process spawned
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1.22), dispatch_get_main_queue(), ^(void){
           self->AltTabPID = [helperLib getPID:@"com.steventheworker.alt-tab-macos"];
            if (self->AltTabPID == 0) {
                self->unsupportedAltTab = YES;
                [self->unsupportedBox setHidden: NO];
                self->AltTabPID = [helperLib getPID:@"com.lwouis.alt-tab-macos"];
                [self preferences:nil];
            } else {
                self->unsupportedAltTab = NO;
                [self->unsupportedBox setHidden: YES];
            }
        });
    });
}


/* Lifecycle */
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"DockAltTab started");
    [app initVars];
    [helperLib listenClicks];
    [helperLib listenScreens];
}
- (void)dealloc {//    [super dealloc]; //todo: why doesn't this work
    [timer invalidate];
    timer = nil;
    if (_systemWideAccessibilityObject) CFRelease(_systemWideAccessibilityObject);
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {/* Insert code here to tear down your application */}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {return NO;}
@end
