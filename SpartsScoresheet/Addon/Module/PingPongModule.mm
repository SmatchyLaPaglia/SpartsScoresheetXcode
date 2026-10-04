//
//  PingPongModule.mm
//  SpartsScoresheet
//
//  See PingPongModule.h.
//

#import "PingPongModule.h"

#include "ModuleIncludes.h"

#import "ProjectAddon.h"
#import <RuntimeKit/RuntimeKit.h>

// Bounces stop once this many hops have happened, so a bug in either side
// can't wedge the app in an infinite native<->Lua recursion.
static const int kMaxPingPongHops = 6;

// Lua calls this directly: xcodePing(n)
// This is the Lua -> native half of the round trip.
static int lua_xcodePing(lua_State *L)
{
    lua_Integer n = luaL_optinteger(L, 1, 0);

    NSLog(@"🏓 [Xcode] received ping(%ld) from Lua", (long)n);

    // Bounce straight back into Lua while we're still on the Lua thread,
    // inside the same call. This is the native -> Lua half of the round trip.
    if (n < kMaxPingPongHops) {
        lua_getglobal(L, "luaPong");
        if (lua_isfunction(L, -1)) {
            lua_pushinteger(L, n + 1);
            if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
                NSLog(@"🏓 [Xcode] error calling luaPong: %s", lua_tostring(L, -1));
                lua_pop(L, 1);
            }
        } else {
            lua_pop(L, 1);
            NSLog(@"🏓 [Xcode] luaPong is not defined - is xcodeAddons.lua loaded?");
        }
    }

    lua_pushboolean(L, 1);
    return 1;
}

@implementation PingPongModule

- (void)registerForAddon:(ProjectAddon *)addon
{
    lua_register(addon.L, "xcodePing", lua_xcodePing);
}

- (void)codeaDidFinishSetupForAddon:(ProjectAddon *)addon
{
    // Kick off a bounce that *starts* on the native side, to demonstrate
    // native code calling into Lua without Lua having called first. We hop
    // onto the Lua thread via unsafeRunLuaBlock: since this delegate method
    // isn't guaranteed to already be running there.
    __weak ThreadedRuntimeViewController *controller = addon.controller;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [controller unsafeRunLuaBlock:^(CodeaLuaState * _Nonnull state) {
            NSLog(@"🏓 [Xcode] starting ping-pong from native");
            if ([state pushFunction:@"xcodeStartPingPong"]) {
                [state callFunctionWithArgCount:0];
            } else {
                NSLog(@"🏓 [Xcode] xcodeStartPingPong is not defined - is xcodeAddons.lua loaded?");
            }
        }];
    });
}

@end
