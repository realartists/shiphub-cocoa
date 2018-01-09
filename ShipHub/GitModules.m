//
//  GitModules.m
//  Ship
//
//  Created by James Howard on 1/9/18.
//  Copyright © 2018 Real Artists, Inc. All rights reserved.
//

#import "GitModules.h"

@interface GitModule : NSObject

@property NSString *path;
@property NSString *name;
@property NSURL *URL;

@end

@interface GitModules ()

@property NSArray<GitModule *> *modules;

@end

@implementation GitModules


- (id)initWithString:(NSString *)modulesStr {
    static dispatch_once_t onceToken;
    static NSRegularExpression *sectionRE;
    static NSRegularExpression *pathRE;
    static NSRegularExpression *urlRE;
    dispatch_once(&onceToken, ^{
        sectionRE = [NSRegularExpression regularExpressionWithPattern:@"^\\[submodule \"(.*?)\"\\]$" options:0 error:NULL];
        pathRE = [NSRegularExpression regularExpressionWithPattern:@"^\\s*path = (.*)" options:0 error:NULL];
        urlRE = [NSRegularExpression regularExpressionWithPattern:@"^\\s*url = (.*)" options:0 error:NULL];
    });
    
    if (self = [super init]) {
        __block GitModule *current = nil;
        NSMutableArray *found = [NSMutableArray new];
        [modulesStr enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
            
            NSTextCheckingResult *match = nil;
            
            if ((match = [sectionRE firstMatchInString:line options:0 range:NSMakeRange(0, line.length)]) != nil) {
                current = [GitModule new];
                current.name = [line substringWithRange:[match rangeAtIndex:1]];
                [found addObject:current];
            } else if ((match = [pathRE firstMatchInString:line options:0 range:NSMakeRange(0, line.length)])) {
                current.path = [line substringWithRange:[match rangeAtIndex:1]];
            } else if ((match = [urlRE firstMatchInString:line options:0 range:NSMakeRange(0, line.length)])) {
                @try {
                    current.URL = [NSURL URLWithString:[line substringWithRange:[match rangeAtIndex:1]]];
                } @catch (id exc) { }
            }
        }];
        
        _modules = found;
    }
    return self;
}

- (NSURL *)URLForSubmodule:(NSString *)submodulePath {
    for (GitModule *module in _modules) {
        if ([module.path isEqualToString:submodulePath]) {
            return module.URL;
        }
    }
    return nil;
}

@end

@implementation GitModule

@end

