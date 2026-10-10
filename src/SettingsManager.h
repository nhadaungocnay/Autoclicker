#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MouseButtonType) {
    MouseButtonTypeLeft = 0,
    MouseButtonTypeRight = 1,
    MouseButtonTypeMiddle = 2
};

typedef NS_ENUM(NSInteger, ClickActionType) {
    ClickActionTypeSingle = 0,
    ClickActionTypeDouble = 1
};

typedef NS_ENUM(NSInteger, StopConditionMode) {
    StopConditionModeDuration = 0,
    StopConditionModeClicks = 1,
    StopConditionModeInfinite = 2
};

typedef NS_ENUM(NSInteger, LocationMode) {
    LocationModeCurrentCursor = 0,
    LocationModeFixed = 1
};

@interface SettingsManager : NSObject

@property (nonatomic, assign) NSInteger intervalHours;
@property (nonatomic, assign) NSInteger intervalMinutes;
@property (nonatomic, assign) NSInteger intervalSeconds;
@property (nonatomic, assign) NSInteger intervalMilliseconds;

@property (nonatomic, assign) MouseButtonType mouseButton;
@property (nonatomic, assign) ClickActionType clickAction;

@property (nonatomic, assign) StopConditionMode stopMode;
@property (nonatomic, assign) NSInteger stopDurationHours;
@property (nonatomic, assign) NSInteger stopDurationMinutes;
@property (nonatomic, assign) NSInteger stopDurationSeconds;
@property (nonatomic, assign) NSInteger stopClickCount;

@property (nonatomic, assign) LocationMode locationMode;
@property (nonatomic, assign) double fixedX;
@property (nonatomic, assign) double fixedY;

@property (nonatomic, assign) unsigned short hotkeyKeyCode;
@property (nonatomic, assign) NSUInteger hotkeyModifiers;
@property (nonatomic, copy) NSString *hotkeyDisplayName;

@property (nonatomic, assign) double startDelaySeconds;
@property (nonatomic, assign) BOOL playSoundEffect;
@property (nonatomic, assign) BOOL alwaysOnTop;

// Chrome Remote Desktop / Anti-Hijack Features
@property (nonatomic, assign) BOOL remoteDesktopMode;
@property (nonatomic, assign) BOOL pauseOnMouseMove;
@property (nonatomic, assign) BOOL stopOnMouseMove;
@property (nonatomic, assign) double resumeDelaySeconds;

// Background App Click (Target PID)
@property (nonatomic, assign) BOOL backgroundAppClick;
@property (nonatomic, assign) pid_t targetPid;
@property (nonatomic, copy) NSString *targetAppBundleId;
@property (nonatomic, copy) NSString *targetAppName;

+ (instancetype)sharedManager;
- (void)saveSettings;
- (void)loadSettings;
- (void)resetToDefaults;

- (double)totalIntervalInSeconds;
- (double)totalStopDurationInSeconds;

@end
