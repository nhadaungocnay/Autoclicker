#import "MainWindowController.h"
#import "HotkeyManager.h"
#import <ApplicationServices/ApplicationServices.h>

@interface MainWindowController () {
    // Top Accessibility banner
    NSView *_accessibilityBanner;
    
    // Status Card Views
    NSView *_statusCard;
    NSView *_statusDot;
    NSTextField *_statusLabel;
    NSTextField *_hotkeyBadge;
    NSTextField *_clicksValLabel;
    NSTextField *_timeValLabel;
    NSTextField *_timeTitleLabel;
    NSTextField *_speedValLabel;
    NSButton *_startStopBtn;
    
    // Interval Inputs
    NSTextField *_intHoursField;
    NSTextField *_intMinsField;
    NSTextField *_intSecsField;
    NSTextField *_intMsField;
    
    // Mouse Controls
    NSSegmentedControl *_mouseButtonSeg;
    NSSegmentedControl *_clickActionSeg;
    
    // Stop Condition Controls
    NSSegmentedControl *_stopModeSeg;
    NSView *_stopDurationContainer;
    NSView *_stopClicksContainer;
    NSTextField *_stopHoursField;
    NSTextField *_stopMinsField;
    NSTextField *_stopSecsField;
    NSTextField *_stopClicksField;
    
    // Remote Desktop Shield Controls
    NSButton *_remoteDesktopCheck;
    NSView *_remoteDesktopOptionsContainer;
    NSSegmentedControl *_remoteBehaviorSeg;
    NSView *_resumeDelayContainer;
    NSPopUpButton *_resumeDelayPopup;
    NSButton *_useOptionCHotkeyBtn;
    
    // Background Target App Controls
    NSButton *_backgroundAppCheck;
    NSPopUpButton *_targetAppPopup;
    
    // Hotkey Controls
    NSButton *_recordHotkeyBtn;
    
    // Location Controls
    NSSegmentedControl *_locationModeSeg;
    NSView *_fixedLocationContainer;
    NSTextField *_fixedXField;
    NSTextField *_fixedYField;
    NSButton *_pickCoordsBtn;
    NSTimer *_pickTimer;
    NSInteger _pickCountdown;
    
    // Options
    NSButton *_alwaysOnTopCheck;
    NSButton *_soundCheck;
    NSPopUpButton *_delayPopup;
    
    NSTimer *_accessibilityCheckTimer;
}
@end

@implementation MainWindowController

+ (instancetype)sharedController {
    static MainWindowController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MainWindowController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 450, 750);
    NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Auto Clicker (M-Chip Edition)";
    [window center];
    
    self = [super initWithWindow:window];
    if (self) {
        _settings = [SettingsManager sharedManager];
        _engine = [ClickEngine sharedEngine];
        _engine.delegate = self;
        
        [self setupUI];
        [self updateWindowLevel];
        [self startAccessibilityMonitoring];
        [self setupHotkeyListener];
    }
    return self;
}

- (void)setupUI {
    NSWindow *window = self.window;
    NSView *contentView = window.contentView;
    contentView.wantsLayer = YES;
    
    // Create ScrollView to hold content
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:contentView.bounds];
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = NO;
    scrollView.drawsBackground = NO;
    
    // Container height: 860px to accommodate Remote Desktop Shield
    NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 430, 860)];
    container.wantsLayer = YES;
    scrollView.documentView = container;
    [contentView addSubview:scrollView];
    
    CGFloat y = 810;
    
    // Accessibility Banner
    _accessibilityBanner = [self createAccessibilityBannerAtY:y];
    [container addSubview:_accessibilityBanner];
    [self updateAccessibilityBanner];
    
    y -= 70;
    
    // 1. Status & Start/Stop Big Card
    _statusCard = [self createStatusCardAtY:y];
    [container addSubview:_statusCard];
    
    y -= 130;
    
    // 2. Click Interval Box
    NSView *intervalBox = [self createIntervalBoxAtY:y];
    [container addSubview:intervalBox];
    
    y -= 115;
    
    // 3. Mouse Configuration Box
    NSView *mouseBox = [self createMouseBoxAtY:y];
    [container addSubview:mouseBox];
    
    y -= 85;
    
    // 4. Remote Desktop Shield Box (New!)
    NSView *remoteBox = [self createRemoteDesktopShieldBoxAtY:y];
    [container addSubview:remoteBox];
    
    y -= 145;
    
    // 5. Auto-Stop Condition Box
    NSView *stopBox = [self createStopConditionBoxAtY:y];
    [container addSubview:stopBox];
    
    y -= 110;
    
    // 6. Hotkey & Location Box
    NSView *hotkeyLocationBox = [self createHotkeyLocationBoxAtY:y];
    [container addSubview:hotkeyLocationBox];
    
    y -= 135;
    
    // 7. Options Box
    NSView *optionsBox = [self createOptionsBoxAtY:y];
    [container addSubview:optionsBox];
}

#pragma mark - Section Builders

- (NSView *)createAccessibilityBannerAtY:(CGFloat)y {
    NSView *banner = [[NSView alloc] initWithFrame:NSMakeRect(16, y, 400, 48)];
    banner.wantsLayer = YES;
    banner.layer.backgroundColor = [[NSColor systemYellowColor] colorWithAlphaComponent:0.15].CGColor;
    banner.layer.cornerRadius = 8;
    banner.layer.borderColor = [[NSColor systemYellowColor] colorWithAlphaComponent:0.4].CGColor;
    banner.layer.borderWidth = 1;
    
    NSTextField *txt = [self makeLabel:@"⚠️ Cần cấp quyền Accessibility để click chuột" bold:YES size:11];
    txt.frame = NSMakeRect(12, 16, 260, 18);
    [banner addSubview:txt];
    
    NSButton *grantBtn = [NSButton buttonWithTitle:@"Cấp Quyền" target:self action:@selector(grantAccessibilityClicked:)];
    grantBtn.frame = NSMakeRect(295, 10, 95, 28);
    grantBtn.bezelStyle = NSBezelStyleRounded;
    [banner addSubview:grantBtn];
    
    return banner;
}

- (NSView *)createStatusCardAtY:(CGFloat)y {
    NSView *card = [[NSView alloc] initWithFrame:NSMakeRect(16, y, 400, 115)];
    card.wantsLayer = YES;
    card.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    card.layer.cornerRadius = 10;
    card.layer.borderColor = [[NSColor labelColor] colorWithAlphaComponent:0.08].CGColor;
    card.layer.borderWidth = 1;
    
    // Status Dot
    _statusDot = [[NSView alloc] initWithFrame:NSMakeRect(14, 86, 12, 12)];
    _statusDot.wantsLayer = YES;
    _statusDot.layer.cornerRadius = 6;
    _statusDot.layer.backgroundColor = [NSColor systemGrayColor].CGColor;
    [card addSubview:_statusDot];
    
    // Status Text
    _statusLabel = [self makeLabel:@"STOPPED" bold:YES size:12];
    _statusLabel.textColor = [NSColor secondaryLabelColor];
    _statusLabel.frame = NSMakeRect(32, 83, 175, 18);
    [card addSubview:_statusLabel];
    
    // Hotkey Badge
    _hotkeyBadge = [self makeLabel:[NSString stringWithFormat:@"Key: %@", _settings.hotkeyDisplayName] bold:YES size:11];
    _hotkeyBadge.alignment = NSTextAlignmentRight;
    _hotkeyBadge.textColor = [NSColor controlAccentColor];
    _hotkeyBadge.frame = NSMakeRect(215, 83, 85, 18);
    [card addSubview:_hotkeyBadge];
    
    // Live Stats
    // Clicks
    NSTextField *clicksTitle = [self makeLabel:@"Clicks Sent" bold:NO size:10];
    clicksTitle.frame = NSMakeRect(14, 48, 80, 14);
    [card addSubview:clicksTitle];
    
    _clicksValLabel = [self makeLabel:@"0" bold:YES size:18];
    _clicksValLabel.frame = NSMakeRect(14, 20, 80, 26);
    [card addSubview:_clicksValLabel];
    
    // Time
    _timeTitleLabel = [self makeLabel:@"Remaining Time" bold:NO size:10];
    _timeTitleLabel.frame = NSMakeRect(105, 48, 95, 14);
    [card addSubview:_timeTitleLabel];
    
    _timeValLabel = [self makeLabel:@"01:00.0" bold:YES size:18];
    _timeValLabel.frame = NSMakeRect(105, 20, 95, 26);
    [card addSubview:_timeValLabel];
    
    // Speed
    NSTextField *speedTitle = [self makeLabel:@"Speed" bold:NO size:10];
    speedTitle.frame = NSMakeRect(210, 48, 75, 14);
    [card addSubview:speedTitle];
    
    _speedValLabel = [self makeLabel:@"100 ms" bold:YES size:15];
    _speedValLabel.frame = NSMakeRect(210, 20, 75, 26);
    [card addSubview:_speedValLabel];
    
    // Start / Stop Action Button
    _startStopBtn = [NSButton buttonWithTitle:@"START" target:self action:@selector(toggleClicked:)];
    _startStopBtn.frame = NSMakeRect(305, 20, 82, 75);
    _startStopBtn.bezelStyle = NSBezelStyleRegularSquare;
    _startStopBtn.wantsLayer = YES;
    _startStopBtn.layer.cornerRadius = 8;
    _startStopBtn.layer.backgroundColor = [NSColor systemGreenColor].CGColor;
    _startStopBtn.contentTintColor = [NSColor whiteColor];
    _startStopBtn.font = [NSFont boldSystemFontOfSize:14];
    [card addSubview:_startStopBtn];
    
    return card;
}

- (NSView *)createIntervalBoxAtY:(CGFloat)y {
    NSView *box = [[NSView alloc] initWithFrame:NSMakeRect(16, y, 400, 105)];
    box.wantsLayer = YES;
    box.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    box.layer.cornerRadius = 10;
    box.layer.borderColor = [[NSColor labelColor] colorWithAlphaComponent:0.08].CGColor;
    box.layer.borderWidth = 1;
    
    NSTextField *title = [self makeLabel:@"⚡ Tốc Độ Click (Click Interval)" bold:YES size:12];
    title.frame = NSMakeRect(12, 78, 220, 18);
    [box addSubview:title];
    
    // Input Fields: Hours, Mins, Secs, Ms
    CGFloat fieldW = 54;
    _intHoursField = [self makeNumberField:_settings.intervalHours width:fieldW tag:101];
    _intHoursField.frame = NSMakeRect(12, 46, fieldW, 24);
    [box addSubview:_intHoursField];
    NSTextField *lH = [self makeLabel:@"Hours" bold:NO size:10];
    lH.alignment = NSTextAlignmentCenter;
    lH.frame = NSMakeRect(12, 30, fieldW, 14);
    [box addSubview:lH];
    
    _intMinsField = [self makeNumberField:_settings.intervalMinutes width:fieldW tag:102];
    _intMinsField.frame = NSMakeRect(76, 46, fieldW, 24);
    [box addSubview:_intMinsField];
    NSTextField *lM = [self makeLabel:@"Mins" bold:NO size:10];
    lM.alignment = NSTextAlignmentCenter;
    lM.frame = NSMakeRect(76, 30, fieldW, 14);
    [box addSubview:lM];
    
    _intSecsField = [self makeNumberField:_settings.intervalSeconds width:fieldW tag:103];
    _intSecsField.frame = NSMakeRect(140, 46, fieldW, 24);
    [box addSubview:_intSecsField];
    NSTextField *lS = [self makeLabel:@"Secs" bold:NO size:10];
    lS.alignment = NSTextAlignmentCenter;
    lS.frame = NSMakeRect(140, 30, fieldW, 14);
    [box addSubview:lS];
    
    _intMsField = [self makeNumberField:_settings.intervalMilliseconds width:68 tag:104];
    _intMsField.frame = NSMakeRect(204, 46, 68, 24);
    [box addSubview:_intMsField];
    NSTextField *lMs = [self makeLabel:@"Millisecs" bold:NO size:10];
    lMs.alignment = NSTextAlignmentCenter;
    lMs.frame = NSMakeRect(204, 30, 68, 14);
    [box addSubview:lMs];
    
    // Quick Presets
    NSArray *presets = @[@"10ms", @"50ms", @"100ms", @"250ms", @"500ms", @"1s"];
    CGFloat px = 12;
    for (int i = 0; i < presets.count; i++) {
        NSButton *btn = [NSButton buttonWithTitle:presets[i] target:self action:@selector(intervalPresetClicked:)];
        btn.tag = i;
        btn.bezelStyle = NSBezelStyleInline;
        btn.frame = NSMakeRect(px, 6, 58, 20);
        btn.font = [NSFont systemFontOfSize:10];
        [box addSubview:btn];
        px += 64;
    }
    
    return box;
}

- (NSView *)createMouseBoxAtY:(CGFloat)y {
    NSView *box = [[NSView alloc] initWithFrame:NSMakeRect(16, y, 400, 75)];
    box.wantsLayer = YES;
    box.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    box.layer.cornerRadius = 10;
    box.layer.borderColor = [[NSColor labelColor] colorWithAlphaComponent:0.08].CGColor;
    box.layer.borderWidth = 1;
    
    NSTextField *title = [self makeLabel:@"🖱️ Cấu Hình Chuột" bold:YES size:12];
    title.frame = NSMakeRect(12, 48, 200, 18);
    [box addSubview:title];
    
    // Mouse Button Segmented
    _mouseButtonSeg = [NSSegmentedControl segmentedControlWithLabels:@[@"Trái (Left)", @"Phải (Right)", @"Giữa"]
                                                        trackingMode:NSSegmentSwitchTrackingSelectOne
                                                              target:self
                                                              action:@selector(mouseButtonChanged:)];
    _mouseButtonSeg.selectedSegment = _settings.mouseButton;
    _mouseButtonSeg.frame = NSMakeRect(12, 14, 185, 26);
    [box addSubview:_mouseButtonSeg];
    
    // Click Action Segmented
    _clickActionSeg = [NSSegmentedControl segmentedControlWithLabels:@[@"Click Đơn", @"Click Đúp"]
                                                        trackingMode:NSSegmentSwitchTrackingSelectOne
                                                              target:self
                                                              action:@selector(clickActionChanged:)];
    _clickActionSeg.selectedSegment = _settings.clickAction;
    _clickActionSeg.frame = NSMakeRect(208, 14, 180, 26);
    [box addSubview:_clickActionSeg];
    
    return box;
}

#pragma mark - Remote Desktop Shield Box (NEW!)

- (NSView *)createRemoteDesktopShieldBoxAtY:(CGFloat)y {
    NSView *box = [[NSView alloc] initWithFrame:NSMakeRect(16, y, 400, 135)];
    box.wantsLayer = YES;
    box.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    box.layer.cornerRadius = 10;
    box.layer.borderColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.3].CGColor;
    box.layer.borderWidth = 1.2;
    
    NSTextField *title = [self makeLabel:@"🌐 Chrome Remote Desktop & Chuột" bold:YES size:12];
    title.textColor = [NSColor controlAccentColor];
    title.frame = NSMakeRect(12, 108, 380, 18);
    [box addSubview:title];
    
    // Segmented behavior: 3 options
    NSTextField *behLbl = [self makeLabel:@"Khi di chuột:" bold:NO size:11];
    behLbl.frame = NSMakeRect(12, 82, 80, 18);
    [box addSubview:behLbl];
    
    _remoteBehaviorSeg = [NSSegmentedControl segmentedControlWithLabels:@[@"⚡ Vừa Di Vừa Click", @"⏸️ Tạm Dừng Khi Di", @"🛑 Dừng Hẳn"]
                                                           trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                 target:self
                                                                 action:@selector(remoteBehaviorChanged:)];
    if (_settings.stopOnMouseMove) {
        _remoteBehaviorSeg.selectedSegment = 2;
    } else if (_settings.pauseOnMouseMove) {
        _remoteBehaviorSeg.selectedSegment = 1;
    } else {
        _remoteBehaviorSeg.selectedSegment = 0; // Default: Vừa Di Vừa Click Song Song!
    }
    _remoteBehaviorSeg.frame = NSMakeRect(88, 78, 300, 26);
    [box addSubview:_remoteBehaviorSeg];
    
    // Resume delay container (shown only if Tạm Dừng is selected)
    _resumeDelayContainer = [[NSView alloc] initWithFrame:NSMakeRect(12, 46, 376, 24)];
    NSTextField *delLbl = [self makeLabel:@"Tiếp tục sau khi dừng rê chuột:" bold:NO size:11];
    delLbl.frame = NSMakeRect(0, 3, 180, 18);
    [_resumeDelayContainer addSubview:delLbl];
    
    _resumeDelayPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(185, 0, 95, 24) pullsDown:NO];
    [_resumeDelayPopup addItemsWithTitles:@[@"0.5 giây", @"1.0 giây", @"1.5 giây", @"2.0 giây"]];
    if (_settings.resumeDelaySeconds >= 2.0) [_resumeDelayPopup selectItemAtIndex:3];
    else if (_settings.resumeDelaySeconds >= 1.5) [_resumeDelayPopup selectItemAtIndex:2];
    else if (_settings.resumeDelaySeconds <= 0.6) [_resumeDelayPopup selectItemAtIndex:0];
    else [_resumeDelayPopup selectItemAtIndex:1];
    _resumeDelayPopup.target = self;
    _resumeDelayPopup.action = @selector(resumeDelayChanged:);
    [_resumeDelayContainer addSubview:_resumeDelayPopup];
    
    _resumeDelayContainer.hidden = (_remoteBehaviorSeg.selectedSegment != 1);
    [box addSubview:_resumeDelayContainer];
    
    // Hint text
    NSTextField *hintTxt = [self makeLabel:@"💡 Mặc định 'Vừa Di Vừa Click' cho phép rê chuột và click song song không gián đoạn." bold:NO size:10];
    hintTxt.textColor = [NSColor secondaryLabelColor];
    hintTxt.frame = NSMakeRect(12, 10, 376, 30);
    [box addSubview:hintTxt];
    
    return box;
}

- (NSView *)createStopConditionBoxAtY:(CGFloat)y {
    NSView *box = [[NSView alloc] initWithFrame:NSMakeRect(16, y, 400, 98)];
    box.wantsLayer = YES;
    box.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    box.layer.cornerRadius = 10;
    box.layer.borderColor = [[NSColor labelColor] colorWithAlphaComponent:0.08].CGColor;
    box.layer.borderWidth = 1;
    
    NSTextField *title = [self makeLabel:@"⏱️ Điều Kiện Tự Động Dừng (Mặc định 1 phút)" bold:YES size:12];
    title.frame = NSMakeRect(12, 72, 300, 18);
    [box addSubview:title];
    
    _stopModeSeg = [NSSegmentedControl segmentedControlWithLabels:@[@"Theo Thời Gian", @"Số Lượt Click", @"Chạy Liên Tục"]
                                                     trackingMode:NSSegmentSwitchTrackingSelectOne
                                                           target:self
                                                           action:@selector(stopModeChanged:)];
    _stopModeSeg.selectedSegment = _settings.stopMode;
    _stopModeSeg.frame = NSMakeRect(12, 42, 376, 26);
    [box addSubview:_stopModeSeg];
    
    // Duration Inputs Container
    _stopDurationContainer = [[NSView alloc] initWithFrame:NSMakeRect(12, 8, 376, 30)];
    NSTextField *stopLbl = [self makeLabel:@"Dừng sau:" bold:NO size:11];
    stopLbl.frame = NSMakeRect(0, 6, 65, 16);
    [_stopDurationContainer addSubview:stopLbl];
    
    _stopHoursField = [self makeNumberField:_settings.stopDurationHours width:45 tag:201];
    _stopHoursField.frame = NSMakeRect(70, 3, 45, 22);
    [_stopDurationContainer addSubview:_stopHoursField];
    NSTextField *sh = [self makeLabel:@"h" bold:NO size:11];
    sh.frame = NSMakeRect(118, 5, 15, 16);
    [_stopDurationContainer addSubview:sh];
    
    _stopMinsField = [self makeNumberField:_settings.stopDurationMinutes width:45 tag:202];
    _stopMinsField.frame = NSMakeRect(135, 3, 45, 22);
    [_stopDurationContainer addSubview:_stopMinsField];
    NSTextField *sm = [self makeLabel:@"m" bold:NO size:11];
    sm.frame = NSMakeRect(183, 5, 15, 16);
    [_stopDurationContainer addSubview:sm];
    
    _stopSecsField = [self makeNumberField:_settings.stopDurationSeconds width:45 tag:203];
    _stopSecsField.frame = NSMakeRect(200, 3, 45, 22);
    [_stopDurationContainer addSubview:_stopSecsField];
    NSTextField *ss = [self makeLabel:@"s" bold:NO size:11];
    ss.frame = NSMakeRect(248, 5, 15, 16);
    [_stopDurationContainer addSubview:ss];
    
    [box addSubview:_stopDurationContainer];
    
    // Clicks Input Container
    _stopClicksContainer = [[NSView alloc] initWithFrame:NSMakeRect(12, 8, 376, 30)];
    _stopClicksContainer.hidden = YES;
    NSTextField *stopCLbl = [self makeLabel:@"Dừng sau:" bold:NO size:11];
    stopCLbl.frame = NSMakeRect(0, 6, 65, 16);
    [_stopClicksContainer addSubview:stopCLbl];
    
    _stopClicksField = [self makeNumberField:_settings.stopClickCount width:90 tag:204];
    _stopClicksField.frame = NSMakeRect(70, 3, 90, 22);
    [_stopClicksContainer addSubview:_stopClicksField];
    
    NSTextField *cSuffix = [self makeLabel:@"clicks" bold:NO size:11];
    cSuffix.frame = NSMakeRect(168, 6, 60, 16);
    [_stopClicksContainer addSubview:cSuffix];
    
    [box addSubview:_stopClicksContainer];
    
    [self updateStopModeViews];
    
    return box;
}

- (NSView *)createHotkeyLocationBoxAtY:(CGFloat)y {
    NSView *box = [[NSView alloc] initWithFrame:NSMakeRect(16, y, 400, 125)];
    box.wantsLayer = YES;
    box.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    box.layer.cornerRadius = 10;
    box.layer.borderColor = [[NSColor labelColor] colorWithAlphaComponent:0.08].CGColor;
    box.layer.borderWidth = 1;
    
    // Hotkey Row
    NSTextField *hkTitle = [self makeLabel:@"⌨️ Phím tắt:" bold:YES size:11];
    hkTitle.frame = NSMakeRect(12, 94, 75, 18);
    [box addSubview:hkTitle];
    
    _recordHotkeyBtn = [NSButton buttonWithTitle:[NSString stringWithFormat:@"Key: %@", _settings.hotkeyDisplayName]
                                          target:self
                                          action:@selector(recordHotkeyClicked:)];
    _recordHotkeyBtn.frame = NSMakeRect(85, 90, 115, 26);
    _recordHotkeyBtn.bezelStyle = NSBezelStyleRounded;
    [box addSubview:_recordHotkeyBtn];
    
    // Quick Hotkey Presets
    NSArray *hkPresets = @[@"`", @"F6", @"F7", @"⌥+C"];
    CGFloat hkX = 208;
    for (NSString *hk in hkPresets) {
        NSButton *b = [NSButton buttonWithTitle:hk target:self action:@selector(quickHotkeyClicked:)];
        b.bezelStyle = NSBezelStyleInline;
        b.frame = NSMakeRect(hkX, 94, 42, 18);
        b.font = [NSFont systemFontOfSize:10];
        [box addSubview:b];
        hkX += 46;
    }
    
    // Location Mode Row
    NSTextField *locTitle = [self makeLabel:@"📍 Vị trí:" bold:YES size:11];
    locTitle.frame = NSMakeRect(12, 60, 70, 18);
    [box addSubview:locTitle];
    
    _locationModeSeg = [NSSegmentedControl segmentedControlWithLabels:@[@"Con Trỏ Hiện Tại", @"Tọa Độ Cố Định"]
                                                         trackingMode:NSSegmentSwitchTrackingSelectOne
                                                               target:self
                                                               action:@selector(locationModeChanged:)];
    _locationModeSeg.selectedSegment = _settings.locationMode;
    _locationModeSeg.frame = NSMakeRect(85, 56, 300, 26);
    [box addSubview:_locationModeSeg];
    
    // Fixed Location Coordinates
    _fixedLocationContainer = [[NSView alloc] initWithFrame:NSMakeRect(12, 10, 376, 34)];
    _fixedLocationContainer.hidden = (_settings.locationMode != LocationModeFixed);
    
    NSTextField *lx = [self makeLabel:@"X:" bold:NO size:11];
    lx.frame = NSMakeRect(0, 8, 16, 16);
    [_fixedLocationContainer addSubview:lx];
    
    _fixedXField = [self makeNumberField:(NSInteger)_settings.fixedX width:65 tag:301];
    _fixedXField.frame = NSMakeRect(18, 5, 65, 22);
    [_fixedLocationContainer addSubview:_fixedXField];
    
    NSTextField *ly = [self makeLabel:@"Y:" bold:NO size:11];
    ly.frame = NSMakeRect(90, 8, 16, 16);
    [_fixedLocationContainer addSubview:ly];
    
    _fixedYField = [self makeNumberField:(NSInteger)_settings.fixedY width:65 tag:302];
    _fixedYField.frame = NSMakeRect(108, 5, 65, 22);
    [_fixedLocationContainer addSubview:_fixedYField];
    
    _pickCoordsBtn = [NSButton buttonWithTitle:@"Lấy tọa độ (sau 3s)" target:self action:@selector(pickCoordinatesClicked:)];
    _pickCoordsBtn.frame = NSMakeRect(190, 3, 180, 26);
    _pickCoordsBtn.bezelStyle = NSBezelStyleRounded;
    [_fixedLocationContainer addSubview:_pickCoordsBtn];
    
    [box addSubview:_fixedLocationContainer];
    
    return box;
}

- (NSView *)createOptionsBoxAtY:(CGFloat)y {
    NSView *box = [[NSView alloc] initWithFrame:NSMakeRect(16, y, 400, 95)];
    box.wantsLayer = YES;
    box.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    box.layer.cornerRadius = 10;
    box.layer.borderColor = [[NSColor labelColor] colorWithAlphaComponent:0.08].CGColor;
    box.layer.borderWidth = 1;
    
    _alwaysOnTopCheck = [NSButton checkboxWithTitle:@"Luôn nổi trên cùng (Always on Top)" target:self action:@selector(alwaysOnTopChanged:)];
    _alwaysOnTopCheck.state = _settings.alwaysOnTop ? NSControlStateValueOn : NSControlStateValueOff;
    _alwaysOnTopCheck.frame = NSMakeRect(12, 66, 220, 18);
    [box addSubview:_alwaysOnTopCheck];
    
    _soundCheck = [NSButton checkboxWithTitle:@"Âm thanh khi click" target:self action:@selector(soundChanged:)];
    _soundCheck.state = _settings.playSoundEffect ? NSControlStateValueOn : NSControlStateValueOff;
    _soundCheck.frame = NSMakeRect(240, 66, 150, 18);
    [box addSubview:_soundCheck];
    
    NSTextField *dlLbl = [self makeLabel:@"Trì hoãn bắt đầu:" bold:NO size:11];
    dlLbl.frame = NSMakeRect(12, 34, 105, 18);
    [box addSubview:dlLbl];
    
    _delayPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(115, 30, 105, 24) pullsDown:NO];
    [_delayPopup addItemsWithTitles:@[@"Không", @"1 Giây", @"2 Giây", @"3 Giây", @"5 Giây"]];
    NSInteger sel = 0;
    if (_settings.startDelaySeconds >= 5.0) sel = 4;
    else if (_settings.startDelaySeconds >= 3.0) sel = 3;
    else if (_settings.startDelaySeconds >= 2.0) sel = 2;
    else if (_settings.startDelaySeconds >= 1.0) sel = 1;
    [_delayPopup selectItemAtIndex:sel];
    _delayPopup.target = self;
    _delayPopup.action = @selector(delayChanged:);
    [box addSubview:_delayPopup];
    
    NSButton *resetBtn = [NSButton buttonWithTitle:@"Khôi phục mặc định" target:self action:@selector(resetDefaultsClicked:)];
    resetBtn.frame = NSMakeRect(250, 8, 140, 24);
    resetBtn.bezelStyle = NSBezelStyleInline;
    resetBtn.font = [NSFont systemFontOfSize:10];
    [box addSubview:resetBtn];
    
    return box;
}

#pragma mark - Helper Views

- (NSTextField *)makeLabel:(NSString *)text bold:(BOOL)bold size:(CGFloat)size {
    NSTextField *lbl = [NSTextField labelWithString:text];
    lbl.font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    return lbl;
}

- (NSTextField *)makeNumberField:(NSInteger)val width:(CGFloat)w tag:(NSInteger)tag {
    NSTextField *tf = [[NSTextField alloc] init];
    tf.stringValue = [NSString stringWithFormat:@"%ld", (long)val];
    tf.alignment = NSTextAlignmentCenter;
    tf.delegate = self;
    tf.tag = tag;
    return tf;
}

#pragma mark - Accessibility & Hotkeys

- (void)startAccessibilityMonitoring {
    [self updateAccessibilityBanner];
    _accessibilityCheckTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self updateAccessibilityBanner];
    }];
}

- (void)updateAccessibilityBanner {
    BOOL trusted = AXIsProcessTrusted();
    _accessibilityBanner.hidden = trusted;
}

- (void)grantAccessibilityClicked:(id)sender {
    NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
}

- (void)setupHotkeyListener {
    __weak typeof(self) weakSelf = self;
    [[HotkeyManager sharedManager] startListeningWithHandler:^{
        [weakSelf toggleClicked:nil];
    }];
}

- (void)updateWindowLevel {
    self.window.level = _settings.alwaysOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel;
}

#pragma mark - UI Actions

- (void)toggleClicked:(id)sender {
    if (!AXIsProcessTrusted()) {
        [self grantAccessibilityClicked:nil];
    }
    [_engine toggleWithSettings:_settings];
    [self postStateChanged];
}

- (void)recordHotkeyClicked:(id)sender {
    _recordHotkeyBtn.title = @"Bấm phím bất kỳ...";
    __weak typeof(self) weakSelf = self;
    [[HotkeyManager sharedManager] beginRecordingWithCompletion:^(unsigned short keyCode, NSUInteger modifiers, NSString *displayName) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        strongSelf.settings.hotkeyKeyCode = keyCode;
        strongSelf.settings.hotkeyModifiers = modifiers;
        strongSelf.settings.hotkeyDisplayName = displayName;
        [strongSelf.settings saveSettings];
        [[HotkeyManager sharedManager] updateRegisteredHotKey];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf->_recordHotkeyBtn.title = [NSString stringWithFormat:@"Key: %@", displayName];
            strongSelf->_hotkeyBadge.stringValue = [NSString stringWithFormat:@"Key: %@", displayName];
            [strongSelf postStateChanged];
        });
    }];
}

- (void)quickHotkeyClicked:(NSButton *)sender {
    NSString *title = sender.title;
    if ([title isEqualToString:@"`"]) {
        _settings.hotkeyKeyCode = 50; _settings.hotkeyModifiers = 0; _settings.hotkeyDisplayName = @"`";
    } else if ([title isEqualToString:@"F6"]) {
        _settings.hotkeyKeyCode = 97; _settings.hotkeyModifiers = 0; _settings.hotkeyDisplayName = @"F6";
    } else if ([title isEqualToString:@"F7"]) {
        _settings.hotkeyKeyCode = 98; _settings.hotkeyModifiers = 0; _settings.hotkeyDisplayName = @"F7";
    } else if ([title isEqualToString:@"⌥+C"]) {
        _settings.hotkeyKeyCode = 8; _settings.hotkeyModifiers = NSEventModifierFlagOption; _settings.hotkeyDisplayName = @"⌥ Opt + C";
    }
    [_settings saveSettings];
    [[HotkeyManager sharedManager] updateRegisteredHotKey];
    _recordHotkeyBtn.title = [NSString stringWithFormat:@"Key: %@", _settings.hotkeyDisplayName];
    _hotkeyBadge.stringValue = [NSString stringWithFormat:@"Key: %@", _settings.hotkeyDisplayName];
    [self postStateChanged];
}

- (void)setBacktickHotkeyClicked:(id)sender {
    _settings.hotkeyKeyCode = 50;
    _settings.hotkeyModifiers = 0;
    _settings.hotkeyDisplayName = @"`";
    [_settings saveSettings];
    [[HotkeyManager sharedManager] updateRegisteredHotKey];
    _recordHotkeyBtn.title = @"Key: `";
    _hotkeyBadge.stringValue = @"Key: `";
    [self postStateChanged];
}

- (void)setOptionCHotkeyClicked:(id)sender {
    _settings.hotkeyKeyCode = 8;
    _settings.hotkeyModifiers = NSEventModifierFlagOption;
    _settings.hotkeyDisplayName = @"⌥ Opt + C";
    [_settings saveSettings];
    [[HotkeyManager sharedManager] updateRegisteredHotKey];
    _recordHotkeyBtn.title = @"Key: ⌥ Opt + C";
    _hotkeyBadge.stringValue = @"Key: ⌥ Opt + C";
    [self postStateChanged];
}

- (void)remoteDesktopToggleChanged:(NSButton *)sender {
    _settings.remoteDesktopMode = (sender.state == NSControlStateValueOn);
    [_settings saveSettings];
    [self postStateChanged];
}

- (void)remoteBehaviorChanged:(NSSegmentedControl *)sender {
    if (sender.selectedSegment == 0) {
        _settings.pauseOnMouseMove = NO;
        _settings.stopOnMouseMove = NO;
    } else if (sender.selectedSegment == 1) {
        _settings.pauseOnMouseMove = YES;
        _settings.stopOnMouseMove = NO;
    } else {
        _settings.pauseOnMouseMove = NO;
        _settings.stopOnMouseMove = YES;
    }
    [_settings saveSettings];
    _resumeDelayContainer.hidden = (sender.selectedSegment != 1);
    [self postStateChanged];
}

- (void)resumeDelayChanged:(NSPopUpButton *)sender {
    switch (sender.indexOfSelectedItem) {
        case 0: _settings.resumeDelaySeconds = 0.5; break;
        case 1: _settings.resumeDelaySeconds = 1.0; break;
        case 2: _settings.resumeDelaySeconds = 1.5; break;
        case 3: _settings.resumeDelaySeconds = 2.0; break;
    }
    [_settings saveSettings];
}

- (void)intervalPresetClicked:(NSButton *)sender {
    NSInteger tag = sender.tag;
    _settings.intervalHours = 0;
    _settings.intervalMinutes = 0;
    
    switch (tag) {
        case 0: _settings.intervalSeconds = 0; _settings.intervalMilliseconds = 10; break;
        case 1: _settings.intervalSeconds = 0; _settings.intervalMilliseconds = 50; break;
        case 2: _settings.intervalSeconds = 0; _settings.intervalMilliseconds = 100; break;
        case 3: _settings.intervalSeconds = 0; _settings.intervalMilliseconds = 250; break;
        case 4: _settings.intervalSeconds = 0; _settings.intervalMilliseconds = 500; break;
        case 5: _settings.intervalSeconds = 1; _settings.intervalMilliseconds = 0; break;
    }
    [_settings saveSettings];
    [self refreshInputFields];
}

- (void)mouseButtonChanged:(NSSegmentedControl *)sender {
    _settings.mouseButton = (MouseButtonType)sender.selectedSegment;
    [_settings saveSettings];
}

- (void)clickActionChanged:(NSSegmentedControl *)sender {
    _settings.clickAction = (ClickActionType)sender.selectedSegment;
    [_settings saveSettings];
}

- (void)stopModeChanged:(NSSegmentedControl *)sender {
    _settings.stopMode = (StopConditionMode)sender.selectedSegment;
    [_settings saveSettings];
    [self updateStopModeViews];
}

- (void)updateStopModeViews {
    _stopDurationContainer.hidden = (_settings.stopMode != StopConditionModeDuration);
    _stopClicksContainer.hidden = (_settings.stopMode != StopConditionModeClicks);
    _timeTitleLabel.stringValue = (_settings.stopMode == StopConditionModeDuration) ? @"Remaining Time" : @"Elapsed Time";
}

- (void)locationModeChanged:(NSSegmentedControl *)sender {
    _settings.locationMode = (LocationMode)sender.selectedSegment;
    [_settings saveSettings];
    _fixedLocationContainer.hidden = (_settings.locationMode != LocationModeFixed);
}

- (void)pickCoordinatesClicked:(id)sender {
    _pickCountdown = 3;
    _pickCoordsBtn.title = [NSString stringWithFormat:@"Rê chuột tới đích: %lds...", (long)_pickCountdown];
    [_pickTimer invalidate];
    
    _pickTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        self->_pickCountdown--;
        if (self->_pickCountdown <= 0) {
            [timer invalidate];
            self->_pickTimer = nil;
            self->_pickCoordsBtn.title = @"Lấy tọa độ (sau 3s)";
            
            CGEventRef ev = CGEventCreate(NULL);
            if (ev) {
                CGPoint p = CGEventGetLocation(ev);
                self->_settings.fixedX = round(p.x);
                self->_settings.fixedY = round(p.y);
                CFRelease(ev);
            }
            [self->_settings saveSettings];
            self->_fixedXField.stringValue = [NSString stringWithFormat:@"%.0f", self->_settings.fixedX];
            self->_fixedYField.stringValue = [NSString stringWithFormat:@"%.0f", self->_settings.fixedY];
            [[NSSound soundNamed:@"Glass"] play];
        } else {
            self->_pickCoordsBtn.title = [NSString stringWithFormat:@"Rê chuột tới đích: %lds...", (long)self->_pickCountdown];
        }
    }];
}

- (void)alwaysOnTopChanged:(NSButton *)sender {
    _settings.alwaysOnTop = (sender.state == NSControlStateValueOn);
    [_settings saveSettings];
    [self updateWindowLevel];
}

- (void)soundChanged:(NSButton *)sender {
    _settings.playSoundEffect = (sender.state == NSControlStateValueOn);
    [_settings saveSettings];
}

- (void)delayChanged:(NSPopUpButton *)sender {
    switch (sender.indexOfSelectedItem) {
        case 0: _settings.startDelaySeconds = 0.0; break;
        case 1: _settings.startDelaySeconds = 1.0; break;
        case 2: _settings.startDelaySeconds = 2.0; break;
        case 3: _settings.startDelaySeconds = 3.0; break;
        case 4: _settings.startDelaySeconds = 5.0; break;
    }
    [_settings saveSettings];
}

- (void)resetDefaultsClicked:(id)sender {
    [_settings resetToDefaults];
    [self refreshInputFields];
    [self updateWindowLevel];
    [self postStateChanged];
}

- (void)refreshInputFields {
    _intHoursField.stringValue = [NSString stringWithFormat:@"%ld", (long)_settings.intervalHours];
    _intMinsField.stringValue = [NSString stringWithFormat:@"%ld", (long)_settings.intervalMinutes];
    _intSecsField.stringValue = [NSString stringWithFormat:@"%ld", (long)_settings.intervalSeconds];
    _intMsField.stringValue = [NSString stringWithFormat:@"%ld", (long)_settings.intervalMilliseconds];
    
    _mouseButtonSeg.selectedSegment = _settings.mouseButton;
    _clickActionSeg.selectedSegment = _settings.clickAction;
    
    _stopModeSeg.selectedSegment = _settings.stopMode;
    _stopHoursField.stringValue = [NSString stringWithFormat:@"%ld", (long)_settings.stopDurationHours];
    _stopMinsField.stringValue = [NSString stringWithFormat:@"%ld", (long)_settings.stopDurationMinutes];
    _stopSecsField.stringValue = [NSString stringWithFormat:@"%ld", (long)_settings.stopDurationSeconds];
    _stopClicksField.stringValue = [NSString stringWithFormat:@"%ld", (long)_settings.stopClickCount];
    
    _remoteDesktopCheck.state = _settings.remoteDesktopMode ? NSControlStateValueOn : NSControlStateValueOff;
    _remoteDesktopOptionsContainer.hidden = !_settings.remoteDesktopMode;
    _remoteBehaviorSeg.selectedSegment = _settings.stopOnMouseMove ? 1 : 0;
    
    _locationModeSeg.selectedSegment = _settings.locationMode;
    _fixedXField.stringValue = [NSString stringWithFormat:@"%.0f", _settings.fixedX];
    _fixedYField.stringValue = [NSString stringWithFormat:@"%.0f", _settings.fixedY];
    
    _recordHotkeyBtn.title = [NSString stringWithFormat:@"Key: %@", _settings.hotkeyDisplayName];
    _hotkeyBadge.stringValue = [NSString stringWithFormat:@"Key: %@", _settings.hotkeyDisplayName];
    
    _alwaysOnTopCheck.state = _settings.alwaysOnTop ? NSControlStateValueOn : NSControlStateValueOff;
    _soundCheck.state = _settings.playSoundEffect ? NSControlStateValueOn : NSControlStateValueOff;
    
    double total = [_settings totalIntervalInSeconds];
    if (total < 1.0) {
        _speedValLabel.stringValue = [NSString stringWithFormat:@"%.0f ms", total * 1000.0];
    } else {
        _speedValLabel.stringValue = [NSString stringWithFormat:@"%.2f s", total];
    }
    
    [self updateStopModeViews];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    NSTextField *tf = obj.object;
    NSInteger val = [tf.stringValue integerValue];
    
    switch (tf.tag) {
        case 101: _settings.intervalHours = val; break;
        case 102: _settings.intervalMinutes = val; break;
        case 103: _settings.intervalSeconds = val; break;
        case 104: _settings.intervalMilliseconds = MAX(1, val); break;
        case 201: _settings.stopDurationHours = val; break;
        case 202: _settings.stopDurationMinutes = val; break;
        case 203: _settings.stopDurationSeconds = val; break;
        case 204: _settings.stopClickCount = MAX(1, val); break;
        case 301: _settings.fixedX = [tf.stringValue doubleValue]; break;
        case 302: _settings.fixedY = [tf.stringValue doubleValue]; break;
    }
    [_settings saveSettings];
    
    double total = [_settings totalIntervalInSeconds];
    if (total < 1.0) {
        _speedValLabel.stringValue = [NSString stringWithFormat:@"%.0f ms", total * 1000.0];
    } else {
        _speedValLabel.stringValue = [NSString stringWithFormat:@"%.2f s", total];
    }
}

- (void)postStateChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ClickEngineStateChangedNotification" object:nil];
}

#pragma mark - ClickEngineDelegate

- (void)clickEngineDidStart {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_statusDot.layer.backgroundColor = [NSColor systemGreenColor].CGColor;
        self->_statusLabel.stringValue = @"RUNNING";
        self->_statusLabel.textColor = [NSColor systemGreenColor];
        
        self->_startStopBtn.title = @"STOP";
        self->_startStopBtn.layer.backgroundColor = [NSColor systemRedColor].CGColor;
        [self postStateChanged];
    });
}

- (void)clickEngineDidStopWithReason:(NSString *)reason {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_statusDot.layer.backgroundColor = [NSColor systemGrayColor].CGColor;
        self->_statusLabel.stringValue = @"STOPPED";
        self->_statusLabel.textColor = [NSColor secondaryLabelColor];
        
        self->_startStopBtn.title = @"START";
        self->_startStopBtn.layer.backgroundColor = [NSColor systemGreenColor].CGColor;
        [self postStateChanged];
    });
}

- (void)clickEngineDidPauseForUserMovement {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_statusDot.layer.backgroundColor = [NSColor systemOrangeColor].CGColor;
        self->_statusLabel.stringValue = @"PAUSED (Di chuột...)";
        self->_statusLabel.textColor = [NSColor systemOrangeColor];
        [self postStateChanged];
    });
}

- (void)clickEngineDidResumeFromUserMovement {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_engine.isRunning) {
            self->_statusDot.layer.backgroundColor = [NSColor systemGreenColor].CGColor;
            self->_statusLabel.stringValue = @"RUNNING";
            self->_statusLabel.textColor = [NSColor systemGreenColor];
            [self postStateChanged];
        }
    });
}

- (void)clickEngineCountdownTick:(NSInteger)secondsRemaining {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_statusDot.layer.backgroundColor = [NSColor systemOrangeColor].CGColor;
        self->_statusLabel.stringValue = [NSString stringWithFormat:@"BẮT ĐẦU TRONG %lds", (long)secondsRemaining];
        self->_statusLabel.textColor = [NSColor systemOrangeColor];
        
        self->_startStopBtn.title = @"STOP";
        self->_startStopBtn.layer.backgroundColor = [NSColor systemRedColor].CGColor;
        [self postStateChanged];
    });
}

- (void)clickEngineDidUpdateClicks:(NSInteger)clicks elapsed:(NSTimeInterval)elapsed remaining:(NSTimeInterval)remaining {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_clicksValLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)clicks];
        
        NSTimeInterval timeToShow = (self->_settings.stopMode == StopConditionModeDuration) ? remaining : elapsed;
        NSInteger totalSecs = (NSInteger)timeToShow;
        NSInteger mins = totalSecs / 60;
        NSInteger secs = totalSecs % 60;
        NSInteger ms = (NSInteger)((timeToShow - totalSecs) * 10);
        self->_timeValLabel.stringValue = [NSString stringWithFormat:@"%02ld:%02ld.%ld", (long)mins, (long)secs, (long)ms];
    });
}

@end
