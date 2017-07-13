//
//  RepoController.h
//  ShipHub
//
//  Created by James Howard on 7/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;
@class RepoPrefs;

typedef void (^RepoPrefsLoadedHandler)(BOOL wasNeeded, NSError *error);
typedef void (^RepoPrefsChosenHandler)(RepoPrefs *chosenPrefs);

@interface RepoController : NSWindowController

- (instancetype)initWithAuth:(Auth *)auth;

- (void)loadAndShowIfNeeded:(RepoPrefsLoadedHandler)loadedHandler chosenHandler:(RepoPrefsChosenHandler)chosenHandler;
- (void)loadData;

@end
