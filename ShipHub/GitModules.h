//
//  GitModules.h
//  Ship
//
//  Created by James Howard on 1/9/18.
//  Copyright © 2018 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GitModules : NSObject

- (id)initWithString:(NSString *)modules;

- (NSURL *)URLForSubmodule:(NSString *)submodulePath;

@end
