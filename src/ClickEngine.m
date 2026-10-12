#import "ClickEngine.h"
#import <CoreGraphics/CoreGraphics.h>
#import <sys/time.h>
#import <unistd.h>
#import <libproc.h>

extern void CGEventPostToPid(pid_t pid, CGEventRef event);

#define AUTOCLICKER_MAGIC 0x4155544FULL

static pid_t getChromeRemoteDesktopHostPid(void) {
    int pids[2048];
    int bytes = proc_listpids(PROC_ALL_PIDS, 0, pids, sizeof(pids));
    int count = bytes / sizeof(int);
    for (int i = 0; i < count; i++) {
        char name[1024];
        if (proc_name(pids[i], name, sizeof(name)) > 0) {
            if (strcmp(name, "remoting_me2me_host") == 0) {
                return (pid_t)pids[i];
            }
        }
    }
    return 0;
}

@interface ClickEngine () {
    dispatch_source_t _clickTimer;
    dispatch_source_t _progressTimer;
    NSTimer *_countdownTimer;
    NSTimer *_resumeTimer;
    dispatch_queue_t _clickQueue;
    
    NSDate *_startTime;
    double _targetDuration;
    NSInteger _targetClicks;
    SettingsManager *_activeSettings;
    
    // Dedicated Event Source permitting simultaneous mouse moves without suppression
    CGEventSourceRef _eventSource;
    
    // CoreGraphics Event Tap for optional auto-pause / stop on move
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _runLoopSource;
    
    // Upstream Active Event Tap for Chrome Remote Desktop Anti-Lockout
    CFMachPortRef _upstreamTap;
    CFRunLoopSourceRef _upstreamRunLoopSource;
    
    CGPoint _lastSimulatedClickPoint;
    NSTimeInterval _lastSimulatedClickTime;
    
@public
    pid_t _cachedCrdPid;
}

- (void)handleRealUserMouseMovementAtPoint:(CGPoint)loc;
- (void)reEnableEventTap;
- (void)reEnableUpstreamTap;
- (CGPoint)currentMouseLocation;

@end

static CGEventRef mouseEventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    ClickEngine *engine = (__bridge ClickEngine *)refcon;
    if (!engine) return event;
    
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        [engine reEnableEventTap];
        return event;
    }
    
    if (type == kCGEventMouseMoved || type == kCGEventLeftMouseDragged || type == kCGEventRightMouseDragged) {
        if (engine.isRunning) {
            CGPoint loc = CGEventGetLocation(event);
            [engine handleRealUserMouseMovementAtPoint:loc];
        }
    }
    return event;
}

static CGEventRef upstreamRewriterTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    ClickEngine *engine = (__bridge ClickEngine *)refcon;
    if (!engine) return event;
    
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        [engine reEnableUpstreamTap];
        return event;
    }
    
    int64_t magic = CGEventGetIntegerValueField(event, kCGEventSourceUserData);
    if (magic == AUTOCLICKER_MAGIC) {
        pid_t crdPid = engine->_cachedCrdPid;
        if (crdPid <= 0) {
            crdPid = getChromeRemoteDesktopHostPid();
            engine->_cachedCrdPid = crdPid;
        }
        if (crdPid > 0) {
            CGEventSetIntegerValueField(event, kCGEventSourceUnixProcessID, crdPid);
        }
    }
    return event;
}

@implementation ClickEngine

+ (instancetype)sharedEngine {
    static ClickEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ClickEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _clickQueue = dispatch_queue_create("com.autoclicker.engine", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        _isRunning = NO;
        _isCountingDown = NO;
        _isPausedByUser = NO;
        _clicksPerformed = 0;
        _elapsedSeconds = 0.0;
        _remainingSeconds = 0.0;
        _eventTap = NULL;
        _runLoopSource = NULL;
        _upstreamTap = NULL;
        _upstreamRunLoopSource = NULL;
        _eventSource = NULL;
        _cachedCrdPid = 0;
        
        [self setupEventSource];
    }
    return self;
}

- (void)dealloc {
    [self removeMouseMoveMonitoring];
    [self removeUpstreamRewriterTap];
    if (_eventSource) {
        CFRelease(_eventSource);
        _eventSource = NULL;
    }
}

- (void)setupEventSource {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CGSetLocalEventsSuppressionInterval(0.0);
    #pragma clang diagnostic pop
    
    if (_eventSource) {
        CFRelease(_eventSource);
        _eventSource = NULL;
    }
    _eventSource = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    if (_eventSource) {
        CGEventSourceSetLocalEventsFilterDuringSuppressionState(_eventSource,
            kCGEventFilterMaskPermitLocalMouseEvents | kCGEventFilterMaskPermitLocalKeyboardEvents | kCGEventFilterMaskPermitSystemDefinedEvents,
            kCGEventSuppressionStateSuppressionInterval);
        CGEventSourceSetLocalEventsFilterDuringSuppressionState(_eventSource,
            kCGEventFilterMaskPermitLocalMouseEvents | kCGEventFilterMaskPermitLocalKeyboardEvents | kCGEventFilterMaskPermitSystemDefinedEvents,
            kCGEventSuppressionStateRemoteMouseDrag);
    }
}

- (CGPoint)currentMouseLocation {
    CGEventRef ev = CGEventCreate(NULL);
    if (ev) {
        CGPoint pt = CGEventGetLocation(ev);
        CFRelease(ev);
        return pt;
    }
    NSPoint loc = [NSEvent mouseLocation];
    NSScreen *mainScreen = [NSScreen mainScreen];
    CGFloat screenH = mainScreen ? mainScreen.frame.size.height : 1080.0;
    return CGPointMake(loc.x, screenH - loc.y);
}

- (void)toggleWithSettings:(SettingsManager *)settings {
    if (_isRunning || _isCountingDown) {
        [self stopWithReason:@"Dừng bởi người dùng"];
    } else {
        [self startWithSettings:settings];
    }
}

- (void)startWithSettings:(SettingsManager *)settings {
    if (_isRunning || _isCountingDown) return;
    
    _activeSettings = settings;
    _clicksPerformed = 0;
    _elapsedSeconds = 0.0;
    _isPausedByUser = NO;
    
    [self setupEventSource];
    [self setupUpstreamRewriterTap];
    
    if (settings.startDelaySeconds > 0.5) {
        [self beginCountdown:(NSInteger)ceil(settings.startDelaySeconds)];
    } else {
        [self beginClicking];
    }
}

- (void)beginCountdown:(NSInteger)seconds {
    _isCountingDown = YES;
    __block NSInteger remaining = seconds;
    
    if ([self.delegate respondsToSelector:@selector(clickEngineCountdownTick:)]) {
        [self.delegate clickEngineCountdownTick:remaining];
    }
    
    [_countdownTimer invalidate];
    _countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        remaining--;
        if (remaining <= 0) {
            [timer invalidate];
            self->_countdownTimer = nil;
            self->_isCountingDown = NO;
            [self beginClicking];
        } else {
            if ([self.delegate respondsToSelector:@selector(clickEngineCountdownTick:)]) {
                [self.delegate clickEngineCountdownTick:remaining];
            }
        }
    }];
}

- (void)beginClicking {
    _isRunning = YES;
    _isPausedByUser = NO;
    _startTime = [NSDate date];
    _targetDuration = [_activeSettings totalStopDurationInSeconds];
    _targetClicks = _activeSettings.stopClickCount;
    _remainingSeconds = (_activeSettings.stopMode == StopConditionModeDuration) ? _targetDuration : 0.0;
    
    _lastSimulatedClickPoint = [self currentMouseLocation];
    
    // Ensure upstream rewriter tap is active and placed at head
    [self setupUpstreamRewriterTap];
    
    // Only setup Event Tap if user explicitly requested Pause or Stop on Mouse Move
    if (_activeSettings.pauseOnMouseMove || _activeSettings.stopOnMouseMove) {
        [self setupMouseMoveMonitoring];
    }
    
    if ([self.delegate respondsToSelector:@selector(clickEngineDidStart)]) {
        [self.delegate clickEngineDidStart];
    }
    
    double interval = [_activeSettings totalIntervalInSeconds];
    uint64_t intervalNs = (uint64_t)(interval * NSEC_PER_SEC);
    
    // High-precision Dispatch Timer for clicking
    _clickTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _clickQueue);
    dispatch_source_set_timer(_clickTimer, dispatch_time(DISPATCH_TIME_NOW, 0), intervalNs, 100000); // 100us leeway
    
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_clickTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_isRunning) return;
        
        // If pauseOnMouseMove is on and user is moving mouse, skip click
        if (strongSelf->_activeSettings.pauseOnMouseMove && strongSelf->_isPausedByUser) return;
        
        [strongSelf executeSingleClick];
    });
    
    dispatch_resume(_clickTimer);
    
    // Progress Timer for UI (50ms)
    _progressTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_progressTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 50 * NSEC_PER_MSEC, 10 * NSEC_PER_MSEC);
    
    dispatch_source_set_event_handler(_progressTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf->_isRunning || !strongSelf->_startTime) return;
        
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:strongSelf->_startTime];
        strongSelf->_elapsedSeconds = elapsed;
        
        if (strongSelf->_activeSettings.stopMode == StopConditionModeDuration) {
            NSTimeInterval remaining = MAX(0.0, strongSelf->_targetDuration - elapsed);
            strongSelf->_remainingSeconds = remaining;
            
            if (elapsed >= strongSelf->_targetDuration) {
                [strongSelf stopWithReason:[NSString stringWithFormat:@"Hết thời gian (%.0fs)", strongSelf->_targetDuration]];
                return;
            }
        } else if (strongSelf->_activeSettings.stopMode == StopConditionModeClicks) {
            if (strongSelf->_clicksPerformed >= strongSelf->_targetClicks) {
                [strongSelf stopWithReason:[NSString stringWithFormat:@"Đã đủ số lượt click (%ld)", (long)strongSelf->_targetClicks]];
                return;
            }
        }
        
        if ([strongSelf.delegate respondsToSelector:@selector(clickEngineDidUpdateClicks:elapsed:remaining:)]) {
            [strongSelf.delegate clickEngineDidUpdateClicks:strongSelf->_clicksPerformed
                                                   elapsed:strongSelf->_elapsedSeconds
                                                 remaining:strongSelf->_remainingSeconds];
        }
    });
    
    dispatch_resume(_progressTimer);
}

#pragma mark - Upstream Event Tap (Chrome Remote Desktop Anti-Lockout)

- (void)setupUpstreamRewriterTap {
    [self removeUpstreamRewriterTap];
    _cachedCrdPid = getChromeRemoteDesktopHostPid();
    
    CGEventMask mask = CGEventMaskBit(kCGEventLeftMouseDown) |
                       CGEventMaskBit(kCGEventLeftMouseUp) |
                       CGEventMaskBit(kCGEventRightMouseDown) |
                       CGEventMaskBit(kCGEventRightMouseUp) |
                       CGEventMaskBit(kCGEventOtherMouseDown) |
                       CGEventMaskBit(kCGEventOtherMouseUp);
    
    _upstreamTap = CGEventTapCreate(kCGSessionEventTap,
                                    kCGHeadInsertEventTap,
                                    kCGEventTapOptionDefault,
                                    mask,
                                    upstreamRewriterTapCallback,
                                    (__bridge void *)self);
    
    if (_upstreamTap) {
        _upstreamRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _upstreamTap, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), _upstreamRunLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(_upstreamTap, true);
    }
}

- (void)reEnableUpstreamTap {
    if (_upstreamTap) {
        CGEventTapEnable(_upstreamTap, true);
    }
}

- (void)removeUpstreamRewriterTap {
    if (_upstreamTap) {
        CGEventTapEnable(_upstreamTap, false);
        if (_upstreamRunLoopSource) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), _upstreamRunLoopSource, kCFRunLoopCommonModes);
            CFRelease(_upstreamRunLoopSource);
            _upstreamRunLoopSource = NULL;
        }
        CFRelease(_upstreamTap);
        _upstreamTap = NULL;
    }
}

#pragma mark - Optional Mouse Movement Monitoring (for explicit Pause/Stop settings)

- (void)setupMouseMoveMonitoring {
    [self removeMouseMoveMonitoring];
    
    CGEventMask mask = CGEventMaskBit(kCGEventMouseMoved) |
                       CGEventMaskBit(kCGEventLeftMouseDragged) |
                       CGEventMaskBit(kCGEventRightMouseDragged);
    
    _eventTap = CGEventTapCreate(kCGSessionEventTap,
                                 kCGHeadInsertEventTap,
                                 kCGEventTapOptionListenOnly,
                                 mask,
                                 mouseEventTapCallback,
                                 (__bridge void *)self);
    
    if (_eventTap) {
        _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(_eventTap, true);
    }
}

- (void)reEnableEventTap {
    if (_eventTap) {
        CGEventTapEnable(_eventTap, true);
    }
}

- (void)removeMouseMoveMonitoring {
    if (_eventTap) {
        CGEventTapEnable(_eventTap, false);
        if (_runLoopSource) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
            CFRelease(_runLoopSource);
            _runLoopSource = NULL;
        }
        CFRelease(_eventTap);
        _eventTap = NULL;
    }
    
    if (_resumeTimer) {
        [_resumeTimer invalidate];
        _resumeTimer = nil;
    }
}

- (void)handleRealUserMouseMovementAtPoint:(CGPoint)loc {
    if (!_isRunning) return;
    
    CGFloat dx = loc.x - _lastSimulatedClickPoint.x;
    CGFloat dy = loc.y - _lastSimulatedClickPoint.y;
    if (sqrt(dx*dx + dy*dy) < 5.0) return;
    
    if (_activeSettings.stopOnMouseMove) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stopWithReason:@"Dừng: Phát hiện di chuyển chuột"];
        });
        return;
    }
    
    if (_activeSettings.pauseOnMouseMove) {
        if (!_isPausedByUser) {
            _isPausedByUser = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector(clickEngineDidPauseForUserMovement)]) {
                    [self.delegate clickEngineDidPauseForUserMovement];
                }
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_resumeTimer invalidate];
            double delay = MAX(0.5, self->_activeSettings.resumeDelaySeconds);
            __weak typeof(self) weakSelf = self;
            self->_resumeTimer = [NSTimer scheduledTimerWithTimeInterval:delay repeats:NO block:^(NSTimer * _Nonnull timer) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf || !strongSelf->_isRunning) return;
                
                strongSelf->_isPausedByUser = NO;
                strongSelf->_resumeTimer = nil;
                
                if ([strongSelf.delegate respondsToSelector:@selector(clickEngineDidResumeFromUserMovement)]) {
                    [strongSelf.delegate clickEngineDidResumeFromUserMovement];
                }
            }];
        });
    }
}

#pragma mark - Click Execution (Simultaneous & Non-Blocking)

- (void)executeSingleClick {
    if (_activeSettings.pauseOnMouseMove && _isPausedByUser) return;
    
    CGPoint mousePos;
    if (_activeSettings.locationMode == LocationModeFixed) {
        mousePos = CGPointMake(_activeSettings.fixedX, _activeSettings.fixedY);
    } else {
        mousePos = [self currentMouseLocation];
    }
    
    _lastSimulatedClickPoint = mousePos;
    _lastSimulatedClickTime = [NSDate date].timeIntervalSince1970;
    
    CGEventType downType, upType;
    CGMouseButton cgButton;
    
    switch (_activeSettings.mouseButton) {
        case MouseButtonTypeLeft:
            downType = kCGEventLeftMouseDown;
            upType = kCGEventLeftMouseUp;
            cgButton = kCGMouseButtonLeft;
            break;
        case MouseButtonTypeRight:
            downType = kCGEventRightMouseDown;
            upType = kCGEventRightMouseUp;
            cgButton = kCGMouseButtonRight;
            break;
        case MouseButtonTypeMiddle:
            downType = kCGEventOtherMouseDown;
            upType = kCGEventOtherMouseUp;
            cgButton = kCGMouseButtonCenter;
            break;
    }
    
    int clickCount = (_activeSettings.clickAction == ClickActionTypeDouble) ? 2 : 1;
    BOOL isBackgroundApp = (_activeSettings.backgroundAppClick && _activeSettings.targetPid > 0);
    
    for (int i = 1; i <= clickCount; i++) {
        CGEventRef down = CGEventCreateMouseEvent(_eventSource, downType, mousePos, cgButton);
        CGEventRef up = CGEventCreateMouseEvent(_eventSource, upType, mousePos, cgButton);
        
        if (down && up) {
            CGEventSetIntegerValueField(down, kCGMouseEventClickState, i);
            CGEventSetIntegerValueField(up, kCGMouseEventClickState, i);
            
            // Tag with AUTOCLICKER_MAGIC so our upstream rewriter tap can identify it
            // and spoof the PID to CRD PID (remoting_me2me_host) right before CRD's tap sees it!
            CGEventSetIntegerValueField(down, kCGEventSourceUserData, AUTOCLICKER_MAGIC);
            CGEventSetIntegerValueField(up, kCGEventSourceUserData, AUTOCLICKER_MAGIC);
            
            pid_t crdPid = _cachedCrdPid > 0 ? _cachedCrdPid : getChromeRemoteDesktopHostPid();
            if (crdPid > 0) {
                CGEventSetIntegerValueField(down, kCGEventSourceUnixProcessID, crdPid);
                CGEventSetIntegerValueField(up, kCGEventSourceUnixProcessID, crdPid);
            }
            
            if (isBackgroundApp) {
                CGEventPostToPid(_activeSettings.targetPid, down);
                usleep(1500);
                CGEventPostToPid(_activeSettings.targetPid, up);
            } else {
                CGEventPost(kCGSessionEventTap, down);
                usleep(1500); // 1.5ms down duration
                CGEventPost(kCGSessionEventTap, up);
            }
            
            CFRelease(down);
            CFRelease(up);
        }
        
        if (i < clickCount) {
            usleep(15000); // 15ms double click gap
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_clicksPerformed++;
        if (self->_activeSettings.playSoundEffect) {
            [[NSSound soundNamed:@"Tink"] play];
        }
    });
}

- (void)stopWithReason:(NSString *)reason {
    if (!_isRunning && !_isCountingDown) return;
    
    // 1. Cancel timers immediately
    if (_countdownTimer) {
        [_countdownTimer invalidate];
        _countdownTimer = nil;
    }
    _isCountingDown = NO;
    _isPausedByUser = NO;
    
    if (_clickTimer) {
        dispatch_source_cancel(_clickTimer);
        _clickTimer = nil;
    }
    
    if (_progressTimer) {
        dispatch_source_cancel(_progressTimer);
        _progressTimer = nil;
    }
    
    _isRunning = NO;
    
    // 2. Wait for any in-flight click execution on the queue to complete cleanly
    dispatch_sync(_clickQueue, ^{
        // Serial barrier: guarantees no background click is half-finished
    });
    
    // 3. Dispatch a clean MouseUp with AUTOCLICKER_MAGIC to ensure no button is stuck down
    CGEventType upType;
    CGMouseButton cgButton;
    switch (self->_activeSettings.mouseButton) {
        case MouseButtonTypeRight:
            upType = kCGEventRightMouseUp;
            cgButton = kCGMouseButtonRight;
            break;
        case MouseButtonTypeMiddle:
            upType = kCGEventOtherMouseUp;
            cgButton = kCGMouseButtonCenter;
            break;
        case MouseButtonTypeLeft:
        default:
            upType = kCGEventLeftMouseUp;
            cgButton = kCGMouseButtonLeft;
            break;
    }
    
    CGPoint currentLoc = [self currentMouseLocation];
    CGEventRef cleanUp = CGEventCreateMouseEvent(self->_eventSource, upType, currentLoc, cgButton);
    if (cleanUp) {
        CGEventSetIntegerValueField(cleanUp, kCGEventSourceUserData, AUTOCLICKER_MAGIC);
        CGEventPost(kCGSessionEventTap, cleanUp);
        CFRelease(cleanUp);
    }
    
    // 4. Remove optional mouse move monitoring (for Pause/Stop on Move), but KEEP _upstreamTap alive!
    // Keeping _upstreamTap alive ensures trailing in-flight events are still rewritten to CRD PID,
    // preventing Chrome Remote Desktop from locking out remote input for 2 seconds after stop!
    [self removeMouseMoveMonitoring];
    
    // 5. Notify delegate
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(clickEngineDidStopWithReason:)]) {
            [self.delegate clickEngineDidStopWithReason:reason ?: @"Stopped"];
        }
    });
}

@end
