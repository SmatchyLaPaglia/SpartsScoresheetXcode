//
//  ProjectAddon.m
//  CodeaProject
//
//  Created by Simeon Saint-Saens on 17/3/19.
//  Copyright © 2019 Two Lives Left. All rights reserved.
//

#import "ProjectAddon.h"

#include "ModuleIncludes.h"

#import "ProjectModule.h"

@interface ProjectAddon ()

@property (nullable, nonatomic, assign) lua_State* L;
@property (nullable, nonatomic, weak, readwrite) ThreadedRuntimeViewController* controller;

// The actual module instances in use for this run, created once so that any
// state a module stashes on itself during registerForAddon: (e.g. a native
// view it created) is still there when codeaDidFinishSetupForAddon: fires.
@property (nonatomic, strong) NSArray<id<Module>>* modules;

@end

@implementation ProjectAddon

+ (NSArray<id<Module>>*) defaultModules
{
    return @[
             [ProjectModule new],
            ];
}

- (void)codea:(nonnull ThreadedRuntimeViewController *)controller didCreateLuaState:(nonnull struct lua_State *)L isValidating:(BOOL)validating {
    self.L = L;
    self.controller = controller;
    self.modules = [ProjectAddon defaultModules];

    for(id<Module> mod in self.modules) {
        [mod registerForAddon:self];
    }
}

- (void)codeaWillDrawFrame:(ThreadedRuntimeViewController *)controller withDelta:(CGFloat)deltaTime {}

- (void)codeaDidFinishSetup:(CodeaViewController *)controller {
    // Give every module a chance to react once Lua's setup() has run and its
    // globals exist. Modules that don't implement this optional hook are
    // skipped.
    for(id<Module> mod in self.modules) {
        if ([mod respondsToSelector:@selector(codeaDidFinishSetupForAddon:)]) {
            [mod codeaDidFinishSetupForAddon:self];
        }
    }

    if( self.ready ) {
        self.ready(self);
    }
}

@end
