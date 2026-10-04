//
//  ProjectAddon.h
//  CodeaProject
//
//  Created by Simeon Saint-Saens on 17/3/19.
//  Copyright © 2019 Two Lives Left. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <RuntimeKit/RuntimeKit.h>

@class ProjectAddon;

NS_ASSUME_NONNULL_BEGIN

typedef void(^ProjectReady)(ProjectAddon*);

@interface ProjectAddon : NSObject<CodeaAddon>

@property (nullable, nonatomic, readonly) lua_State* L;
@property (nullable, nonatomic, strong) ProjectReady ready;

/// The runtime controller, exposed so modules can reach thread-safe helpers
/// like `unsafeRunLuaBlock:` and `runBlock:` (e.g. to call back into Lua from
/// a native UIKit callback, which fires on the main thread).
@property (nullable, nonatomic, readonly, weak) ThreadedRuntimeViewController* controller;

@end

NS_ASSUME_NONNULL_END
