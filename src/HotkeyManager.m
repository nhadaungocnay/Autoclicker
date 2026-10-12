#import "HotkeyManager.h"
#import <Carbon/Carbon.h>
#import <CoreGraphics/CoreGraphics.h>

static UInt32 carbonModifiersFromCocoa(NSUInteger cocoaModifiers) {
    UInt32 carbon = 0;
    if (cocoaModifiers & NSEventModifierFlagCommand) carbon |= cmdKey;
    if (cocoaModifiers & NSEventModifierFlagShift)   carbon |= shiftKey;
    if (cocoaModifiers & NSEventModifierFlagOption)  carbon |= optionKey;
    if (cocoaModifiers & NSEventModifierFlagControl) carbon |= controlKey;
    return carbon;
}

@interface HotkeyManager () {
    id _localMonitor;
    CFMachPortRef _keyboardTap;
    CFRunLoopSourceRef _runLoopSource;
    EventHotKeyRef _carbonHotKeyRef;
    EventHandlerRef _carbonEventHandlerRef;
    HotkeyRecordedHandler _recordCompletion;
    NSTimeInterval _lastTriggerTime;
}

- (void)reEnableTap;
- (void)handleRecordedKeyCode:(unsigned short)code flags:(CGEventFlags)flags;
- (BOOL)matchesKeyCode:(unsigned short)keyCode flags:(CGEventFlags)flags;
- (void)fireTrigger;

@end

static OSStatus carbonHotKeyHandler(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
    HotkeyManager *manager = (__bridge HotkeyManager *)userData;
    if (manager) {
        [manager fireTrigger];
    }
    return noErr;
}

static CGEventRef keyboardTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    HotkeyManager *manager = (__bridge HotkeyManager *)refcon;
    if (!manager) return event;
    
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        [manager reEnableTap];
        return event;
    }
    
    if (type == kCGEventKeyDown) {
        int64_t keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        CGEventFlags flags = CGEventGetFlags(event);
        
        if (manager.isRecording) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [manager handleRecordedKeyCode:(unsigned short)keyCode flags:flags];
            });
            return event;
        }
        
        if ([manager matchesKeyCode:(unsigned short)keyCode flags:flags]) {
            [manager fireTrigger];
        }
    }
    return event;
}

@implementation HotkeyManager

+ (instancetype)sharedManager {
    static HotkeyManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HotkeyManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isListening = NO;
        _isRecording = NO;
        _keyboardTap = NULL;
        _runLoopSource = NULL;
        _carbonHotKeyRef = NULL;
        _carbonEventHandlerRef = NULL;
        _lastTriggerTime = 0.0;
        
        [self installCarbonEventHandler];
    }
    return self;
}

- (void)dealloc {
    [self stopListening];
    if (_carbonEventHandlerRef) {
        RemoveEventHandler(_carbonEventHandlerRef);
        _carbonEventHandlerRef = NULL;
    }
}

- (void)installCarbonEventHandler {
    EventTypeSpec eventType;
    eventType.eventClass = kEventClassKeyboard;
    eventType.eventKind = kEventHotKeyPressed;
    
    InstallApplicationEventHandler(&carbonHotKeyHandler, 1, &eventType, (__bridge void *)self, &_carbonEventHandlerRef);
}

- (void)fireTrigger {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - _lastTriggerTime < 0.25) return; // Debounce 250ms
    _lastTriggerTime = now;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_triggerHandler) {
            self->_triggerHandler();
        }
    });
}

- (void)startListeningWithHandler:(HotkeyTriggerHandler)handler {
    _triggerHandler = [handler copy];
    [self stopListening];
    
    // 1. Carbon Global HotKey (Gold standard: works 100% across all apps, ignores mouse position, no TCC Input Monitoring required)
    [self updateRegisteredHotKey];
    
    // 2. CoreGraphics Event Tap (ListenOnly: low overhead, intercepts across WindowServer session)
    [self setupKeyboardTap];
    
    // 3. Local monitor for in-app UI interactions
    __weak typeof(self) weakSelf = self;
    _localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return event;
        
        if (strongSelf->_isRecording) {
            [strongSelf handleKeyEvent:event isRecording:YES];
            return nil;
        }
        
        if ([strongSelf matchesEvent:event]) {
            [strongSelf fireTrigger];
            return nil;
        }
        return event;
    }];
    
    _isListening = YES;
}

- (void)updateRegisteredHotKey {
    if (_carbonHotKeyRef) {
        UnregisterEventHotKey(_carbonHotKeyRef);
        _carbonHotKeyRef = NULL;
    }
    
    SettingsManager *sm = [SettingsManager sharedManager];
    EventHotKeyID hotKeyID;
    hotKeyID.signature = 'ACHK';
    hotKeyID.id = 1;
    
    UInt32 carbonMods = carbonModifiersFromCocoa(sm.hotkeyModifiers);
    UInt32 keyCode = (UInt32)sm.hotkeyKeyCode;
    
    RegisterEventHotKey(keyCode, carbonMods, hotKeyID, GetApplicationEventTarget(), 0, &_carbonHotKeyRef);
}

- (void)setupKeyboardTap {
    [self removeKeyboardTap];
    
    CGEventMask mask = CGEventMaskBit(kCGEventKeyDown);
    _keyboardTap = CGEventTapCreate(kCGSessionEventTap,
                                    kCGTailAppendEventTap,
                                    kCGEventTapOptionListenOnly,
                                    mask,
                                    keyboardTapCallback,
                                    (__bridge void *)self);
    
    if (_keyboardTap) {
        _runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _keyboardTap, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(_keyboardTap, true);
    }
}

- (void)reEnableTap {
    if (_keyboardTap) {
        CGEventTapEnable(_keyboardTap, true);
    }
}

- (void)removeKeyboardTap {
    if (_keyboardTap) {
        CGEventTapEnable(_keyboardTap, false);
        if (_runLoopSource) {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), _runLoopSource, kCFRunLoopCommonModes);
            CFRelease(_runLoopSource);
            _runLoopSource = NULL;
        }
        CFRelease(_keyboardTap);
        _keyboardTap = NULL;
    }
}

- (void)stopListening {
    if (_carbonHotKeyRef) {
        UnregisterEventHotKey(_carbonHotKeyRef);
        _carbonHotKeyRef = NULL;
    }
    [self removeKeyboardTap];
    if (_localMonitor) {
        [NSEvent removeMonitor:_localMonitor];
        _localMonitor = nil;
    }
    _isListening = NO;
}

- (void)beginRecordingWithCompletion:(HotkeyRecordedHandler)completion {
    _isRecording = YES;
    _recordCompletion = [completion copy];
}

- (void)cancelRecording {
    _isRecording = NO;
    _recordCompletion = nil;
}

- (BOOL)matchesKeyCode:(unsigned short)keyCode flags:(CGEventFlags)flags {
    SettingsManager *sm = [SettingsManager sharedManager];
    if (keyCode != sm.hotkeyKeyCode) return NO;
    
    uint64_t relevantCGFlags = flags & (kCGEventFlagMaskCommand | kCGEventFlagMaskShift | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate);
    uint64_t targetFlags = (uint64_t)sm.hotkeyModifiers & (NSEventModifierFlagCommand | NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption);
    
    return relevantCGFlags == targetFlags;
}

- (BOOL)matchesEvent:(NSEvent *)event {
    SettingsManager *sm = [SettingsManager sharedManager];
    if (event.keyCode != sm.hotkeyKeyCode) return NO;
    
    NSEventModifierFlags eventFlags = event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl | NSEventModifierFlagShift);
    NSEventModifierFlags targetFlags = (NSEventModifierFlags)sm.hotkeyModifiers;
    
    return eventFlags == targetFlags;
}

- (void)handleRecordedKeyCode:(unsigned short)code flags:(CGEventFlags)flags {
    if (!_isRecording) return;
    
    uint64_t relevantFlags = flags & (kCGEventFlagMaskCommand | kCGEventFlagMaskShift | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate);
    NSString *displayName = [HotkeyManager nameForKeyCode:code modifiers:(NSEventModifierFlags)relevantFlags];
    
    _isRecording = NO;
    if (_recordCompletion) {
        _recordCompletion(code, (NSUInteger)relevantFlags, displayName);
        _recordCompletion = nil;
    }
}

- (void)handleKeyEvent:(NSEvent *)event isRecording:(BOOL)isRecording {
    if (!isRecording) return;
    
    unsigned short code = event.keyCode;
    NSEventModifierFlags flags = event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagControl | NSEventModifierFlagShift);
    
    NSString *displayName = [HotkeyManager nameForKeyCode:code modifiers:flags];
    
    _isRecording = NO;
    if (_recordCompletion) {
        _recordCompletion(code, (NSUInteger)flags, displayName);
        _recordCompletion = nil;
    }
}

+ (NSString *)nameForKeyCode:(unsigned short)keyCode modifiers:(NSEventModifierFlags)modifiers {
    NSMutableArray *parts = [NSMutableArray array];
    
    if (modifiers & NSEventModifierFlagControl) [parts addObject:@"⌃ Ctrl"];
    if (modifiers & NSEventModifierFlagOption)  [parts addObject:@"⌥ Opt"];
    if (modifiers & NSEventModifierFlagShift)   [parts addObject:@"⇧ Shift"];
    if (modifiers & NSEventModifierFlagCommand) [parts addObject:@"⌘ Cmd"];
    
    NSString *keyName = @"";
    switch (keyCode) {
        case 122: keyName = @"F1"; break;
        case 120: keyName = @"F2"; break;
        case 99:  keyName = @"F3"; break;
        case 118: keyName = @"F4"; break;
        case 96:  keyName = @"F5"; break;
        case 97:  keyName = @"F6"; break;
        case 98:  keyName = @"F7"; break;
        case 100: keyName = @"F8"; break;
        case 101: keyName = @"F9"; break;
        case 109: keyName = @"F10"; break;
        case 103: keyName = @"F11"; break;
        case 111: keyName = @"F12"; break;
        case 49:  keyName = @"Space"; break;
        case 36:  keyName = @"Return"; break;
        case 48:  keyName = @"Tab"; break;
        case 51:  keyName = @"Delete"; break;
        case 53:  keyName = @"Esc"; break;
        case 123: keyName = @"← Left"; break;
        case 124: keyName = @"→ Right"; break;
        case 125: keyName = @"↓ Down"; break;
        case 126: keyName = @"↑ Up"; break;
        case 0: keyName = @"A"; break;
        case 1: keyName = @"S"; break;
        case 2: keyName = @"D"; break;
        case 3: keyName = @"F"; break;
        case 4: keyName = @"H"; break;
        case 5: keyName = @"G"; break;
        case 6: keyName = @"Z"; break;
        case 7: keyName = @"X"; break;
        case 8: keyName = @"C"; break;
        case 9: keyName = @"V"; break;
        case 11: keyName = @"B"; break;
        case 12: keyName = @"Q"; break;
        case 13: keyName = @"W"; break;
        case 14: keyName = @"E"; break;
        case 15: keyName = @"R"; break;
        case 16: keyName = @"Y"; break;
        case 17: keyName = @"T"; break;
        case 18: keyName = @"1"; break;
        case 19: keyName = @"2"; break;
        case 20: keyName = @"3"; break;
        case 21: keyName = @"4"; break;
        case 22: keyName = @"6"; break;
        case 23: keyName = @"5"; break;
        case 24: keyName = @"="; break;
        case 25: keyName = @"9"; break;
        case 26: keyName = @"7"; break;
        case 27: keyName = @"-"; break;
        case 28: keyName = @"8"; break;
        case 29: keyName = @"0"; break;
        case 30: keyName = @"]"; break;
        case 31: keyName = @"O"; break;
        case 32: keyName = @"U"; break;
        case 33: keyName = @"["; break;
        case 34: keyName = @"I"; break;
        case 35: keyName = @"P"; break;
        case 37: keyName = @"L"; break;
        case 38: keyName = @"J"; break;
        case 39: keyName = @"'"; break;
        case 40: keyName = @"K"; break;
        case 41: keyName = @";"; break;
        case 42: keyName = @"\\"; break;
        case 43: keyName = @","; break;
        case 44: keyName = @"/"; break;
        case 45: keyName = @"N"; break;
        case 46: keyName = @"M"; break;
        case 47: keyName = @"."; break;
        case 50: keyName = @"`"; break;
        default: keyName = [NSString stringWithFormat:@"Key (%d)", keyCode]; break;
    }
    
    [parts addObject:keyName];
    return [parts componentsJoinedByString:@" + "];
}

@end
