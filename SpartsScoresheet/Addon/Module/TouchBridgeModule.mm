//
//  TouchBridgeModule.mm
//  SpartsScoresheet
//
//  See TouchBridgeModule.h.
//

#import "TouchBridgeModule.h"

#include "ModuleIncludes.h"

#import "ProjectAddon.h"
#import <RuntimeKit/RuntimeKit.h>
#import <RuntimeKit/touch.h>
#import <QuartzCore/QuartzCore.h>

static const CGFloat kButtonWidth  = 140;
static const CGFloat kButtonHeight = 40;
static const CGFloat kButtonMargin = 12;

@interface TouchBridgeModule ()

@property (nullable, nonatomic, weak) ProjectAddon *addon;

// The demo zone's rect, in Codea/Lua's own coordinate space (origin
// bottom-left, y-up) as reported by Lua via xcodeSetDemoZone(). Native code
// has no built-in notion of Codea's coordinate space, so Lua tells it.
@property (nonatomic, assign) CGRect demoZoneLuaSpace;
@property (nonatomic, assign) BOOL hasDemoZone;

@property (nullable, nonatomic, strong) UIButton *tapToLuaButton;
@property (nullable, nonatomic, strong) UIButton *dragToLuaButton;
@property (nullable, nonatomic, strong) UIButton *luaTargetButton;

@end

#pragma mark - Lua-callable functions (Lua -> native)

// xcodeSetDemoZone(x, y, w, h)
// Lets Lua tell native code where its on-screen demo zone is, in Codea's
// coordinate space, so the native -> Lua touch injection below knows where
// to aim.
static int lua_xcodeSetDemoZone(lua_State *L)
{
    TouchBridgeModule *self = (__bridge TouchBridgeModule *)lua_touserdata(L, lua_upvalueindex(1));

    lua_Number x = luaL_checknumber(L, 1);
    lua_Number y = luaL_checknumber(L, 2);
    lua_Number w = luaL_checknumber(L, 3);
    lua_Number h = luaL_checknumber(L, 4);

    self.demoZoneLuaSpace = CGRectMake(x, y, w, h);
    self.hasDemoZone = YES;

    return 0;
}

// xcodeTapNativeButton()
// Lua -> native: drives a real UIButton via its ordinary UIKit action, just
// as if a person had tapped it.
static int lua_xcodeTapNativeButton(lua_State *L)
{
    TouchBridgeModule *self = (__bridge TouchBridgeModule *)lua_touserdata(L, lua_upvalueindex(1));

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.luaTargetButton sendActionsForControlEvents:UIControlEventTouchUpInside];
    });

    return 0;
}

// xcodeDragNativeButton(dx, dy)
// Lua -> native: nudges a real UIButton's position, in Codea's y-up space
// (native code flips it to UIKit's y-down space).
static int lua_xcodeDragNativeButton(lua_State *L)
{
    TouchBridgeModule *self = (__bridge TouchBridgeModule *)lua_touserdata(L, lua_upvalueindex(1));

    lua_Number dx = luaL_checknumber(L, 1);
    lua_Number dy = luaL_checknumber(L, 2);

    dispatch_async(dispatch_get_main_queue(), ^{
        UIButton *button = self.luaTargetButton;
        CGPoint center = button.center;
        center.x += dx;
        center.y -= dy; // Codea's y grows upward; UIKit's grows downward.
        button.center = center;
    });

    return 0;
}

#pragma mark -

@implementation TouchBridgeModule

- (void)registerForAddon:(ProjectAddon *)addon
{
    self.addon = addon;

    void *selfPtr = (__bridge void *)self;

    lua_pushlightuserdata(addon.L, selfPtr);
    lua_pushcclosure(addon.L, lua_xcodeSetDemoZone, 1);
    lua_setglobal(addon.L, "xcodeSetDemoZone");

    lua_pushlightuserdata(addon.L, selfPtr);
    lua_pushcclosure(addon.L, lua_xcodeTapNativeButton, 1);
    lua_setglobal(addon.L, "xcodeTapNativeButton");

    lua_pushlightuserdata(addon.L, selfPtr);
    lua_pushcclosure(addon.L, lua_xcodeDragNativeButton, 1);
    lua_setglobal(addon.L, "xcodeDragNativeButton");
}

- (void)codeaDidFinishSetupForAddon:(ProjectAddon *)addon
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setUpDemoButtonsInView:addon.controller.view];
    });
}

#pragma mark - Native UI (demo scaffolding, not part of the addon mechanism itself)

- (void)setUpDemoButtonsInView:(UIView *)hostView
{
    if (!hostView || self.tapToLuaButton) {
        return;
    }

    // Sit below the safe area (notch/status bar/home indicator) rather than
    // a hardcoded offset, since the device chrome varies by simulator/model.
    CGFloat top = kButtonMargin + hostView.safeAreaInsets.top;
    CGFloat left = kButtonMargin + hostView.safeAreaInsets.left;

    self.tapToLuaButton = [self makeDemoButtonWithTitle:@"Tap → Lua"
                                                    frame:CGRectMake(left, top, kButtonWidth, kButtonHeight)
                                                   action:@selector(tapToLuaPressed:)];

    self.dragToLuaButton = [self makeDemoButtonWithTitle:@"Drag → Lua"
                                                     frame:CGRectMake(left, top + kButtonMargin + kButtonHeight, kButtonWidth, kButtonHeight)
                                                    action:@selector(dragToLuaPressed:)];

    self.luaTargetButton = [self makeDemoButtonWithTitle:@"Lua Target"
                                                     frame:CGRectMake(left, top + (kButtonMargin + kButtonHeight) * 2, kButtonWidth, kButtonHeight)
                                                    action:@selector(luaTargetPressed:)];

    [hostView addSubview:self.tapToLuaButton];
    [hostView addSubview:self.dragToLuaButton];
    [hostView addSubview:self.luaTargetButton];
}

- (UIButton *)makeDemoButtonWithTitle:(NSString *)title frame:(CGRect)frame action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = frame;
    button.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
    button.tintColor = [UIColor whiteColor];
    button.layer.cornerRadius = 8;
    button.titleLabel.font = [UIFont systemFontOfSize:13];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

#pragma mark - Native button actions (native -> Lua)

- (void)tapToLuaPressed:(UIButton *)sender
{
    NSLog(@"🏓 [Xcode] Tap -> Lua button pressed, injecting a synthetic tap into Lua");
    [self injectTapAtDemoZoneCenter];
}

- (void)dragToLuaPressed:(UIButton *)sender
{
    NSLog(@"🏓 [Xcode] Drag -> Lua button pressed, injecting a synthetic drag into Lua");
    [self injectDragAcrossDemoZone];
}

- (void)luaTargetPressed:(UIButton *)sender
{
    // This fires whether a person tapped the button for real, or Lua drove
    // it via xcodeTapNativeButton() -- from the button's point of view
    // there's no difference, which is exactly the point of this demo.
    NSLog(@"🏓 [Xcode] Lua Target button received TouchUpInside");
    [UIView animateWithDuration:0.1 animations:^{
        sender.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.85];
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.3 animations:^{
            sender.backgroundColor = [UIColor colorWithWhite:0 alpha:0.55];
        }];
    }];
}

#pragma mark - Synthetic touch injection (native -> Lua)

- (CGPoint)demoZoneCenter
{
    if (self.hasDemoZone) {
        return CGPointMake(CGRectGetMidX(self.demoZoneLuaSpace), CGRectGetMidY(self.demoZoneLuaSpace));
    }
    // Fallback if Lua hasn't reported a zone yet.
    return CGPointMake(110, 80);
}

- (void)injectTapAtDemoZoneCenter
{
    CGPoint p = [self demoZoneCenter];
    [self sendSyntheticTouchAtPoints:@[[NSValue valueWithCGPoint:p]]
                               states:@[@(INTERACTION_STATE_BEGAN)]
                             tapCount:1
                            touchID:9001];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self sendSyntheticTouchAtPoints:@[[NSValue valueWithCGPoint:p]]
                                   states:@[@(INTERACTION_STATE_ENDED)]
                                 tapCount:1
                                touchID:9001];
    });
}

- (void)injectDragAcrossDemoZone
{
    CGPoint center = [self demoZoneCenter];
    CGFloat halfWidth = self.hasDemoZone ? (self.demoZoneLuaSpace.size.width * 0.35) : 60;

    NSArray<NSValue *> *points = @[
        [NSValue valueWithCGPoint:CGPointMake(center.x - halfWidth, center.y)],
        [NSValue valueWithCGPoint:CGPointMake(center.x - halfWidth * 0.3, center.y)],
        [NSValue valueWithCGPoint:CGPointMake(center.x + halfWidth * 0.3, center.y)],
        [NSValue valueWithCGPoint:CGPointMake(center.x + halfWidth, center.y)],
    ];
    NSArray<NSNumber *> *states = @[
        @(INTERACTION_STATE_BEGAN),
        @(INTERACTION_STATE_CHANGED),
        @(INTERACTION_STATE_CHANGED),
        @(INTERACTION_STATE_ENDED),
    ];

    // Feed the points in one at a time, a beat apart, so Lua sees a real
    // drag gesture rather than four touches that all arrive at once.
    for (NSUInteger i = 0; i < points.count; i++) {
        NSTimeInterval delay = 0.08 * i;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self sendSyntheticTouchAtPoints:@[points[i]] states:@[states[i]] tapCount:1 touchID:9002];
        });
    }
}

- (void)sendSyntheticTouchAtPoints:(NSArray<NSValue *> *)points
                             states:(NSArray<NSNumber *> *)states
                           tapCount:(unsigned int)tapCount
                            touchID:(ptrdiff_t)touchID
{
    ThreadedRuntimeViewController *controller = self.addon.controller;
    if (!controller || points.count == 0) {
        return;
    }

    // __block so the pointer captured by the block below is mutable
    // (Objective-C blocks otherwise capture stack locals as const copies).
    __block touch_data touch;
    setupEmptyTouch(&touch);

    CGPoint p = points[0].CGPointValue;
    touch.ID = touchID;
    touch.x = p.x;
    touch.y = p.y;
    touch.prevX = p.x;
    touch.prevY = p.y;
    touch.type = TOUCH_TYPE_DIRECT;
    touch.state = states[0].unsignedIntValue;
    touch.tapCount = tapCount;
    touch.timestamp = CACurrentMediaTime();

    [controller unsafeRunLuaBlock:^(CodeaLuaState * _Nonnull state) {
        [state callTouchFunction:&touch count:1];
    }];
}

@end
