#import "SettingsManager.h"

@implementation SettingsManager

+ (instancetype)sharedManager {
    static SettingsManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SettingsManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Check if initialized before
    if ([defaults objectForKey:@"intervalMilliseconds"] == nil) {
        [self resetToDefaults];
        return;
    }
    
    _intervalHours = [defaults integerForKey:@"intervalHours"];
    _intervalMinutes = [defaults integerForKey:@"intervalMinutes"];
    _intervalSeconds = [defaults integerForKey:@"intervalSeconds"];
    _intervalMilliseconds = [defaults integerForKey:@"intervalMilliseconds"];
    if (_intervalHours == 0 && _intervalMinutes == 0 && _intervalSeconds == 0 && _intervalMilliseconds == 0) {
        _intervalMilliseconds = 100; // Default 100ms
    }
    
    _mouseButton = (MouseButtonType)[defaults integerForKey:@"mouseButton"];
    _clickAction = (ClickActionType)[defaults integerForKey:@"clickAction"];
    
    _stopMode = (StopConditionMode)[defaults integerForKey:@"stopMode"];
    _stopDurationHours = [defaults integerForKey:@"stopDurationHours"];
    _stopDurationMinutes = [defaults objectForKey:@"stopDurationMinutes"] ? [defaults integerForKey:@"stopDurationMinutes"] : 1;
    _stopDurationSeconds = [defaults integerForKey:@"stopDurationSeconds"];
    
    NSInteger clicks = [defaults integerForKey:@"stopClickCount"];
    _stopClickCount = clicks > 0 ? clicks : 1000;
    
    _locationMode = (LocationMode)[defaults integerForKey:@"locationMode"];
    _fixedX = [defaults doubleForKey:@"fixedX"];
    _fixedY = [defaults doubleForKey:@"fixedY"];
    
    NSInteger savedKey = [defaults integerForKey:@"hotkeyKeyCode"];
    NSString *savedName = [defaults stringForKey:@"hotkeyDisplayName"];
    if (savedKey == 0 || savedKey == 97 || [savedName isEqualToString:@"F6"]) {
        _hotkeyKeyCode = 50; // ` (backtick / tilde) default
        _hotkeyModifiers = 0;
        _hotkeyDisplayName = @"`";
    } else {
        _hotkeyKeyCode = (unsigned short)savedKey;
        _hotkeyModifiers = (NSUInteger)[defaults integerForKey:@"hotkeyModifiers"];
        _hotkeyDisplayName = savedName ?: @"`";
    }
    
    _startDelaySeconds = [defaults doubleForKey:@"startDelaySeconds"];
    _playSoundEffect = [defaults boolForKey:@"playSoundEffect"];
    _alwaysOnTop = [defaults objectForKey:@"alwaysOnTop"] ? [defaults boolForKey:@"alwaysOnTop"] : YES;
    
    // Remote desktop settings
    _remoteDesktopMode = [defaults objectForKey:@"remoteDesktopMode"] ? [defaults boolForKey:@"remoteDesktopMode"] : YES;
    _pauseOnMouseMove = [defaults boolForKey:@"pauseOnMouseMove"]; // Default NO for simultaneous movement
    _stopOnMouseMove = [defaults boolForKey:@"stopOnMouseMove"];
    double rDelay = [defaults doubleForKey:@"resumeDelaySeconds"];
    _resumeDelaySeconds = rDelay > 0.1 ? rDelay : 1.0;
    
    _backgroundAppClick = [defaults boolForKey:@"backgroundAppClick"];
    _targetAppBundleId = [defaults stringForKey:@"targetAppBundleId"] ?: @"";
    _targetAppName = [defaults stringForKey:@"targetAppName"] ?: @"";
    _targetPid = 0;
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setInteger:_intervalHours forKey:@"intervalHours"];
    [defaults setInteger:_intervalMinutes forKey:@"intervalMinutes"];
    [defaults setInteger:_intervalSeconds forKey:@"intervalSeconds"];
    [defaults setInteger:_intervalMilliseconds forKey:@"intervalMilliseconds"];
    
    [defaults setInteger:_mouseButton forKey:@"mouseButton"];
    [defaults setInteger:_clickAction forKey:@"clickAction"];
    
    [defaults setInteger:_stopMode forKey:@"stopMode"];
    [defaults setInteger:_stopDurationHours forKey:@"stopDurationHours"];
    [defaults setInteger:_stopDurationMinutes forKey:@"stopDurationMinutes"];
    [defaults setInteger:_stopDurationSeconds forKey:@"stopDurationSeconds"];
    [defaults setInteger:_stopClickCount forKey:@"stopClickCount"];
    
    [defaults setInteger:_locationMode forKey:@"locationMode"];
    [defaults setDouble:_fixedX forKey:@"fixedX"];
    [defaults setDouble:_fixedY forKey:@"fixedY"];
    
    [defaults setInteger:_hotkeyKeyCode forKey:@"hotkeyKeyCode"];
    [defaults setInteger:_hotkeyModifiers forKey:@"hotkeyModifiers"];
    [defaults setObject:_hotkeyDisplayName forKey:@"hotkeyDisplayName"];
    
    [defaults setDouble:_startDelaySeconds forKey:@"startDelaySeconds"];
    [defaults setBool:_playSoundEffect forKey:@"playSoundEffect"];
    [defaults setBool:_alwaysOnTop forKey:@"alwaysOnTop"];
    
    [defaults setBool:_remoteDesktopMode forKey:@"remoteDesktopMode"];
    [defaults setBool:_pauseOnMouseMove forKey:@"pauseOnMouseMove"];
    [defaults setBool:_stopOnMouseMove forKey:@"stopOnMouseMove"];
    [defaults setDouble:_resumeDelaySeconds forKey:@"resumeDelaySeconds"];
    
    [defaults setBool:_backgroundAppClick forKey:@"backgroundAppClick"];
    [defaults setObject:_targetAppBundleId forKey:@"targetAppBundleId"];
    [defaults setObject:_targetAppName forKey:@"targetAppName"];
    
    [defaults synchronize];
}

- (void)resetToDefaults {
    _intervalHours = 0;
    _intervalMinutes = 0;
    _intervalSeconds = 0;
    _intervalMilliseconds = 100; // 100ms default
    
    _mouseButton = MouseButtonTypeLeft;
    _clickAction = ClickActionTypeSingle;
    
    _stopMode = StopConditionModeDuration;
    _stopDurationHours = 0;
    _stopDurationMinutes = 1; // 1 minute default
    _stopDurationSeconds = 0;
    _stopClickCount = 1000;
    
    _locationMode = LocationModeCurrentCursor;
    _fixedX = 0;
    _fixedY = 0;
    
    _hotkeyKeyCode = 50; // ` (backtick / tilde)
    _hotkeyModifiers = 0;
    _hotkeyDisplayName = @"`";
    
    _startDelaySeconds = 0.0;
    _playSoundEffect = NO;
    _alwaysOnTop = YES;
    
    _remoteDesktopMode = YES; // 0.0s event suppression & permit local mouse events
    _pauseOnMouseMove = NO;  // Simultaneous movement by default
    _stopOnMouseMove = NO;
    _resumeDelaySeconds = 1.0;
    
    _backgroundAppClick = NO;
    _targetAppBundleId = @"";
    _targetAppName = @"";
    _targetPid = 0;
    
    [self saveSettings];
}

- (double)totalIntervalInSeconds {
    double total = (double)_intervalHours * 3600.0 +
                   (double)_intervalMinutes * 60.0 +
                   (double)_intervalSeconds +
                   (double)_intervalMilliseconds / 1000.0;
    return MAX(total, 0.001); // Min 1ms
}

- (double)totalStopDurationInSeconds {
    double total = (double)_stopDurationHours * 3600.0 +
                   (double)_stopDurationMinutes * 60.0 +
                   (double)_stopDurationSeconds;
    return MAX(total, 1.0);
}

@end
