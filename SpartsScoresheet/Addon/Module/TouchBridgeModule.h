//
//  TouchBridgeModule.h
//  SpartsScoresheet
//
//  Demonstrates synthesizing *input* across the native/Lua boundary, in both
//  directions:
//    native -> Lua : native code injects a synthetic touch/drag directly
//                    into Lua's touched(touch) callback, indistinguishable
//                    from a real screen touch.
//    Lua -> native : Lua calls native functions that drive a real UIButton
//                    (tap it, drag it) via ordinary UIKit APIs.
//
//  Adds two small native UIButtons over the Codea view as a visual demo:
//    "Tap -> Lua"   / "Drag -> Lua"  trigger the native -> Lua direction.
//    "Lua Target"                    is driven by Lua via the Lua -> native
//                                     direction (xcodeTapNativeButton /
//                                     xcodeDragNativeButton).
//
//  See xcodeAddons.lua for the Lua half of this demo.
//

#import <Foundation/Foundation.h>

#import "Module.h"

NS_ASSUME_NONNULL_BEGIN

@interface TouchBridgeModule : NSObject<Module>

@end

NS_ASSUME_NONNULL_END
