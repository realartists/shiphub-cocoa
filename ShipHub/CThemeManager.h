//
//  CThemeManager.h
//  Ship
//
//  Created by James Howard on 10/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const CThemeDidChangeNotification;

// Manages syntax highlighting code themes
@interface CThemeManager : NSObject <NSMenuDelegate>

+ (CThemeManager *)sharedManager;

@property (readonly) NSDictionary *activeThemeVariables;

@property (readonly) BOOL activeThemeIsDark;

@end
