#import "AppDelegate.h"
#import "MainWindowController.h"
#import "SettingsManager.h"

@interface AppDelegate () {
    NSMenuItem *_statusMenuItem;
    NSMenuItem *_toggleMenuItem;
    NSMenuItem *_remoteModeMenuItem;
}
@property (nonatomic, strong) MainWindowController *mainController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    _mainController = [MainWindowController sharedController];
    [_mainController showWindow:nil];
    [_mainController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    [self setupStatusItem];
    
    // Register as secondary listener for click engine state updates
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(engineStateChanged:)
                                                 name:@"ClickEngineStateChangedNotification"
                                               object:nil];
}

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.title = @"🖱️ Off";
    
    NSMenu *menu = [[NSMenu alloc] init];
    
    _statusMenuItem = [[NSMenuItem alloc] initWithTitle:@"Auto Clicker: STOPPED" action:nil keyEquivalent:@""];
    [_statusMenuItem setEnabled:NO];
    [menu addItem:_statusMenuItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    SettingsManager *sm = [SettingsManager sharedManager];
    _toggleMenuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Start Clicking (%@)", sm.hotkeyDisplayName]
                                                 action:@selector(toggleClickingFromMenu:)
                                          keyEquivalent:@""];
    _toggleMenuItem.target = self;
    [menu addItem:_toggleMenuItem];
    
    _remoteModeMenuItem = [[NSMenuItem alloc] initWithTitle:@"🌐 Remote Desktop Shield (Active)"
                                                     action:@selector(toggleRemoteModeFromMenu:)
                                              keyEquivalent:@""];
    _remoteModeMenuItem.target = self;
    _remoteModeMenuItem.state = sm.remoteDesktopMode ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:_remoteModeMenuItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *showWin = [[NSMenuItem alloc] initWithTitle:@"Show Main Window" action:@selector(showMainWindowFromMenu:) keyEquivalent:@""];
    showWin.target = self;
    [menu addItem:showWin];
    
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Auto Clicker" action:@selector(terminate:) keyEquivalent:@"q"];
    [menu addItem:quitItem];
    
    self.statusItem.menu = menu;
}

- (void)updateStatusItemTitle {
    ClickEngine *engine = [ClickEngine sharedEngine];
    SettingsManager *sm = [SettingsManager sharedManager];
    
    if (engine.isRunning) {
        if (engine.isPausedByUser) {
            self.statusItem.button.title = @"🖱️ ⏸ Paused";
            _statusMenuItem.title = @"Status: PAUSED (Mouse moving)";
            _toggleMenuItem.title = [NSString stringWithFormat:@"Stop Clicking (%@)", sm.hotkeyDisplayName];
        } else {
            self.statusItem.button.title = @"🖱️ 🟢 Running";
            _statusMenuItem.title = [NSString stringWithFormat:@"Status: RUNNING (%ld clicks)", (long)engine.clicksPerformed];
            _toggleMenuItem.title = [NSString stringWithFormat:@"Stop Clicking (%@)", sm.hotkeyDisplayName];
        }
    } else if (engine.isCountingDown) {
        self.statusItem.button.title = @"🖱️ ⏳ Starting...";
        _statusMenuItem.title = @"Status: Starting countdown";
        _toggleMenuItem.title = @"Cancel Countdown";
    } else {
        self.statusItem.button.title = @"🖱️ Off";
        _statusMenuItem.title = @"Status: STOPPED";
        _toggleMenuItem.title = [NSString stringWithFormat:@"Start Clicking (%@)", sm.hotkeyDisplayName];
    }
    
    _remoteModeMenuItem.state = sm.remoteDesktopMode ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)toggleClickingFromMenu:(id)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    [[ClickEngine sharedEngine] toggleWithSettings:sm];
    [self updateStatusItemTitle];
}

- (void)toggleRemoteModeFromMenu:(id)sender {
    SettingsManager *sm = [SettingsManager sharedManager];
    sm.remoteDesktopMode = !sm.remoteDesktopMode;
    [sm saveSettings];
    [self updateStatusItemTitle];
    [[MainWindowController sharedController] refreshInputFields];
}

- (void)showMainWindowFromMenu:(id)sender {
    [_mainController showWindow:nil];
    [_mainController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)engineStateChanged:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateStatusItemTitle];
    });
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO; // Keep running in menu bar even if window closed!
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (!flag) {
        [_mainController showWindow:nil];
    }
    return YES;
}

@end
