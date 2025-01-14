//
//  AppDelegate.h
//  DockAltTab
//
//  Created by Steven G on 5/6/22.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    //permissions
    @public AXUIElementRef          _systemWideAccessibilityObject;
    
    //system state (non-live / eg. periodically updated)
    @public float           primaryScreenHeight;
    @public float           primaryScreenWidth;
    @public float           extendedOffsetX;
    @public float           extendedOffsetY;
    @public float           extendedOffsetYBottom;
    @public float           extScreenWidth;
    @public float           extScreenHeight;
    @public CGFloat         dockWidth;
    @public CGFloat         dockHeight;
    @public NSString*       dockPos;
    pid_t                  dockPID;
    pid_t                  finderPID;
    pid_t                  AltTabPID;
    BOOL                   unsupportedAltTab;
    BOOL                   allSpaces;
    BOOL                   autohide;
    BOOL                   steviaOS;
    NSString*              steviaOSSystemFiles;

    //app stuff
    NSString*              appVersion;
    NSString*              mostCurrentVersion;
    NSTimer*               timer;
    NSString*              appDisplayed;
    pid_t                  appDisplayedPID;
    NSString*              lastAppClickToggled;
    BOOL                   wasShowingContextMenu;

    //UI
    NSStatusItem            *statusItem;
    __weak IBOutlet NSView *LinksBox;
    __weak IBOutlet NSButton *requestScreenRecordingBtn;
    __weak IBOutlet NSButton *requestScreenRecordingInfoBtn;
    __weak IBOutlet NSMenu *menu;
    __weak IBOutlet NSTextField *appVersionRef;
    __weak IBOutlet NSTextField *delayLabel;
    __weak IBOutlet NSTextField *updateRemindRef;
    BOOL                    isMenuItemChecked;
    BOOL                    isClickToggleChecked;
    BOOL                    isReopenPreviewsChecked;
    BOOL                    isLockDockContentsChecked;
    BOOL                    isLockDockSizeChecked;
    BOOL                    isLockDockPositionChecked;
    BOOL                    isShowHiddenChecked;
    float                   dockDelay;
    int                     previewDelay;
    __weak IBOutlet NSButton *menuItemCheckBox;
    __weak IBOutlet NSButton *updateToggleCheckbox;
    __weak IBOutlet NSButton *clickToggleCheckBox;
    __weak IBOutlet NSButton *reopenPreviewsCheckbox;
    __weak IBOutlet NSButton *lockDockContentsCheckbox;
    __weak IBOutlet NSButton *lockDockSizeCheckbox;
    __weak IBOutlet NSButton *lockDockPositionCheckbox;
    __weak IBOutlet NSButton *showHiddenCheckbox;
    __weak IBOutlet NSTextField *dockDelayInput;
    __weak IBOutlet NSSliderCell *previewDelaySlider;
    __weak IBOutlet NSBox *unsupportedBox;
    
    NSPoint               matchedDockIconPos;
}
@property BOOL isMenuItemChecked;
@property BOOL isClickToggleChecked;
@property BOOL isReopenPreviewsChecked;
@property BOOL isLockDockContentsChecked;
@property BOOL isLockDockSizeChecked;
@property BOOL isLockDockPositionChecked;
@property BOOL isShowHiddenChecked;
@property (nonatomic) float dockDelay; // text input value (0 to Infinity)
@property int previewDelay; // slider value (1 to 100)
//- (float) timeDiff;
- (void) dockItemClickHide: (CGPoint)carbonPoint : (AXUIElementRef) el : (NSDictionary*)info : (BOOL) clickToClose;
- (void) mousedown: (CGEventRef) e : (CGEventType) etype : (BOOL) clickToClose;
- (void) mouseup: (CGEventRef) e : (CGEventType) etype : (BOOL) clickToClose;
- (void) bindScreens;
- (void) enableClickToClose;
- (void) reopenDock;
- (void) reopenPreview: (NSString*) cachedApp;
- (IBAction) preferences:(id)sender;
- (IBAction)requestScreenRecordingPermission:(id)sender;
@end
