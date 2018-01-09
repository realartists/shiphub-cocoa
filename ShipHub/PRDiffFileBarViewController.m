//
//  PRDiffFileBarViewController.m
//  ShipHub
//
//  Created by James Howard on 3/29/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRDiffFileBarViewController.h"

#import "GitDiff.h"
#import "Extras.h"

@interface PRDiffFileBarViewController ()

@property IBOutlet NSView *path1View;
@property IBOutlet NSView *path2View;

@property IBOutlet NSPathControl *pathControl;

@property IBOutlet NSPathControl *previousPathControl;
@property IBOutlet NSPathControl *currentPathControl;

@property IBOutlet NSButton *path1SubmoduleButton;
@property IBOutlet NSButton *path2SubmoduleButton;
@property IBOutlet NSLayoutConstraint *path1ViewTrailingConstraint;
@property IBOutlet NSLayoutConstraint *path2ViewTrailingConstraint;

@end

@implementation PRDiffFileBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view setContentView:_path1View];
    
    _path1SubmoduleButton.hidden = YES;
    _path2SubmoduleButton.hidden = YES;
    _pathControl.pathItems = @[];
    _previousPathControl.pathItems = @[];
    _currentPathControl.pathItems = @[];
}

static NSArray *controlItemsForPath(NSString *path, DiffFileMode mode) {
    NSArray *components = [path pathComponents];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:components.count];
    for (NSUInteger i = 0; i+1 < components.count; i++) {
        NSPathControlItem *item = [NSPathControlItem new];
        item.title = components[i];
        item.image = [NSImage imageNamed:NSImageNameFolder];
        [items addObject:item];
    }
    
    NSPathControlItem *file = [NSPathControlItem new];
    NSString *lastComponent = [components lastObject];
    NSString *title = lastComponent;
    if (mode == DiffFileModeBlobExecutable) {
        title = [title stringByAppendingString:@" (+x)"];
    }
    file.title = title;
    file.image = [[NSWorkspace sharedWorkspace] iconForFileType:[lastComponent pathExtension]];
    
    [items addObject:file];
    
    return items;
}
    
static NSArray *componentCellsForPath(NSString *path, DiffFileMode mode) {
    NSArray *components = [path pathComponents];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:components.count];
    for (NSUInteger i = 0; i+1 < components.count; i++) {
        NSPathComponentCell *cell = [NSPathComponentCell new];
        cell.stringValue = components[i];
        cell.image = [NSImage imageNamed:NSImageNameFolder];
        [items addObject:cell];
    }
    
    NSPathComponentCell *file = [NSPathComponentCell new];
    NSString *lastComponent = [components lastObject];
    NSString *title = lastComponent;
    if (mode == DiffFileModeBlobExecutable) {
        title = [title stringByAppendingString:@" (+x)"];
    }
    file.stringValue = title;
    file.image = [[NSWorkspace sharedWorkspace] iconForFileType:[lastComponent pathExtension]];
    
    [items addObject:file];
    
    return items;
}

- (void)setFile:(GitDiffFile *)file {
    static BOOL useDeprecatedSetPathComponentCells;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSOperatingSystemVersion vers = [[NSProcessInfo processInfo] operatingSystemVersion];
        useDeprecatedSetPathComponentCells = vers.majorVersion == 10 && vers.minorVersion < 12;
    });
    
    if (_file != file) {
        _file = file;
        
        if (file.oldPath && ![file.oldPath isEqualToString:file.path]) {
            if (!_path2View.superview) {
                [self.view setContentView:_path2View];
            }
            _previousPathControl.toolTip = file.oldPath;
            if (!useDeprecatedSetPathComponentCells) {
                _previousPathControl.pathItems = controlItemsForPath(file.oldPath, file.oldMode);
                _currentPathControl.pathItems = controlItemsForPath(file.path, file.mode);
            } else {
                [_previousPathControl setPathComponentCells:componentCellsForPath(file.oldPath, file.oldMode)];
                [_currentPathControl setPathComponentCells:componentCellsForPath(file.path, file.mode)];
            }
            _currentPathControl.toolTip = file.path;
            
            if (file.submodule) {
                _path2ViewTrailingConstraint.constant = 32.0;
                _path2SubmoduleButton.hidden = NO;
            } else {
                _path2ViewTrailingConstraint.constant = 0.0;
                _path2SubmoduleButton.hidden = YES;
            }
        } else {
            if (!_path1View.superview) {
                [self.view setContentView:_path1View];
            }
            
            if (!useDeprecatedSetPathComponentCells) {
                _pathControl.pathItems = controlItemsForPath(file.path, file.mode);
            } else {
                [_pathControl setPathComponentCells:componentCellsForPath(file.path, file.mode)];
            }
            _pathControl.toolTip = file.path;
            
            if (file.submodule) {
                _path1ViewTrailingConstraint.constant = 32.0;
                _path1SubmoduleButton.hidden = NO;
            } else {
                _path1ViewTrailingConstraint.constant = 0.0;
                _path1SubmoduleButton.hidden = YES;
            }
        }
    }
}

- (IBAction)showSubmodule:(id)sender {
    [_file loadSubmoduleURL:^(NSURL *URL, NSString *oldOid, NSString *newOid, NSError *err) {
        if (URL) {
            NSURLComponents *comps = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
            comps.scheme = @"https";
            comps.user = nil;
            comps.password = nil;
            
            if ([comps.path hasSuffix:@".git"]) {
                comps.path = [comps.path substringToIndex:comps.path.length - 4];
            }
            
            if (oldOid && newOid) {
                NSString *pc = [NSString stringWithFormat:@"/compare/%@...%@", oldOid, newOid];
                comps.path = [comps.path stringByAppendingPathComponent:pc];
            } else if (oldOid || newOid) {
                NSString *pc = [NSString stringWithFormat:@"/commit/%@", newOid?:oldOid];
                comps.path = [comps.path stringByAppendingPathComponent:pc];
            }
            
            [[NSWorkspace sharedWorkspace] openURL:comps.URL];
        } else if (err) {
            [self presentError:err];
        }
    }];
}

@end
