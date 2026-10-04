//
//  Module.h
//  FPaint
//
//  Created by Simeon Saint-Saens on 23/9/18.
//  Copyright © 2018 Two Lives Left. All rights reserved.
//

@class ProjectAddon;

@protocol Module <NSObject>

/// Called once, on the Lua thread, right after the Lua state is created.
/// Register your native functions/globals here. Do NOT call into Lua from
/// this method — Main.lua hasn't run yet, so its globals don't exist.
- (void) registerForAddon:(ProjectAddon *_Nonnull)addon;

@optional

/// Called once, on the Lua thread, after Lua's setup() has finished running.
/// It's now safe to call into Lua globals from here.
- (void) codeaDidFinishSetupForAddon:(ProjectAddon *_Nonnull)addon;

@end

