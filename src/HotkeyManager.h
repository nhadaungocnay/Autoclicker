#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "SettingsManager.h"

typedef void (^HotkeyTriggerHandler)(void);
typedef void (^HotkeyRecordedHandler)(unsigned short keyCode, NSUInteger modifiers, NSString *displayName);

@interface HotkeyManager : NSObject

@property (nonatomic, assign, readonly) BOOL isListening;
@property (nonatomic, assign, readonly) BOOL isRecording;
@property (nonatomic, copy, readonly) HotkeyTriggerHandler triggerHandler;

+ (instancetype)sharedManager;
- (void)startListeningWithHandler:(HotkeyTriggerHandler)handler;
- (void)stopListening;
- (void)updateRegisteredHotKey;
- (void)beginRecordingWithCompletion:(HotkeyRecordedHandler)completion;
- (void)cancelRecording;

+ (NSString *)nameForKeyCode:(unsigned short)keyCode modifiers:(NSEventModifierFlags)modifiers;

@end
