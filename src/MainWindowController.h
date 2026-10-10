#import <Cocoa/Cocoa.h>
#import "SettingsManager.h"
#import "ClickEngine.h"

@interface MainWindowController : NSWindowController <ClickEngineDelegate, NSTextFieldDelegate>

@property (nonatomic, strong) SettingsManager *settings;
@property (nonatomic, strong) ClickEngine *engine;

+ (instancetype)sharedController;
- (void)refreshInputFields;

@end
