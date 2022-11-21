//
//  app.h
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@interface app : NSObject
+ (BOOL) contextMenuExists: (CGPoint)carbonPoint : (NSDictionary*)info;
+ (NSString*) getCurrentVersion;
+ (void) init;
+ (NSString*) getShowString: (NSString*) appBID;
+ (void) AltTabShow: (NSString*) appBID;
+ (void) AltTabHide;
+ (float) maxDelay;
+ (NSString*) reopenDockStr: (BOOL) triggerEscape;
+ (void) activateApp: (NSRunningApplication*) app;
+ (void) sendClick : (CGPoint) pt;
+ (void) viewToFront: (NSView*) v;
+ (void) viewToBack: (NSView*) v;
@end
NS_ASSUME_NONNULL_END
