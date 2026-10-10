#import <Cocoa/Cocoa.h>
#import "ClickEngine.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, ClickEngineDelegate>

@property (nonatomic, strong) NSStatusItem *statusItem;
- (void)updateStatusItemTitle;

@end
