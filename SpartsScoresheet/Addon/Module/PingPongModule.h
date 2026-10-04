//
//  PingPongModule.h
//  SpartsScoresheet
//
//  Demonstrates the Codea addon round-trip in both directions:
//    Lua  -> native (Lua calls a C function registered by native code)
//    native -> Lua  (native calls a global Lua function)
//  by bouncing an integer back and forth between the two sides.
//
//  See xcodeAddons.lua for the Lua half of this demo.
//

#import <Foundation/Foundation.h>

#import "Module.h"

NS_ASSUME_NONNULL_BEGIN

@interface PingPongModule : NSObject<Module>

@end

NS_ASSUME_NONNULL_END
