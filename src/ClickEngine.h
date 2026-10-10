#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "SettingsManager.h"

@protocol ClickEngineDelegate <NSObject>
@optional
- (void)clickEngineDidStart;
- (void)clickEngineDidStopWithReason:(NSString *)reason;
- (void)clickEngineDidPauseForUserMovement;
- (void)clickEngineDidResumeFromUserMovement;
- (void)clickEngineDidUpdateClicks:(NSInteger)clicks elapsed:(NSTimeInterval)elapsed remaining:(NSTimeInterval)remaining;
- (void)clickEngineCountdownTick:(NSInteger)secondsRemaining;
@end

@interface ClickEngine : NSObject

@property (nonatomic, weak) id<ClickEngineDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, assign, readonly) BOOL isCountingDown;
@property (nonatomic, assign, readonly) BOOL isPausedByUser;
@property (nonatomic, assign, readonly) NSInteger clicksPerformed;
@property (nonatomic, assign, readonly) NSTimeInterval elapsedSeconds;
@property (nonatomic, assign, readonly) NSTimeInterval remainingSeconds;

+ (instancetype)sharedEngine;
- (void)startWithSettings:(SettingsManager *)settings;
- (void)stopWithReason:(NSString *)reason;
- (void)toggleWithSettings:(SettingsManager *)settings;

@end
