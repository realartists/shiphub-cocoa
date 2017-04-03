//
//  PRBinaryDiffViewController.m
//  ShipHub
//
//  Created by James Howard on 4/3/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRBinaryDiffViewController.h"

#import "Extras.h"
#import "GitDiff.h"

#import <Quartz/Quartz.h>

@interface GitPreviewItem : NSObject <QLPreviewItem>

+ (GitPreviewItem *)itemWithData:(NSData *)data name:(NSString *)name;

@end

@interface PRBinaryDiffViewController () {
    NSInteger _loadCount;
}

@property IBOutlet NSView *leftContainer;
@property IBOutlet NSView *rightContainer;

@property QLPreviewView *leftView;
@property QLPreviewView *rightView;

@end

@implementation PRBinaryDiffViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _leftView = [[QLPreviewView alloc] initWithFrame:_leftContainer.bounds style:QLPreviewViewStyleNormal];
    
    _rightView = [[QLPreviewView alloc] initWithFrame:_rightContainer.bounds style:QLPreviewViewStyleNormal];
    
    [_leftContainer setContentView:_leftView];
    [_rightContainer setContentView:_rightView];
}

- (NSSplitView *)splitView {
    return (NSSplitView *)(self.view);
}

- (void)setFile:(GitDiffFile *)file oldData:(NSData *)oldData newData:(NSData *)newData {
    _file = file;
    
    _leftView.previewItem = nil;
    _rightView.previewItem = nil;
    
    NSInteger loadCount = ++_loadCount;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        GitPreviewItem *left = [GitPreviewItem itemWithData:oldData name:[file.oldPath lastPathComponent]];
        GitPreviewItem *right = [GitPreviewItem itemWithData:newData name:[file.path lastPathComponent]];
        
        RunOnMain(^{
            if (loadCount == _loadCount) {
                [self updateWithLeftItem:left rightItem:right];
            }
        });
    });
}

- (void)updateWithLeftItem:(GitPreviewItem *)leftItem rightItem:(GitPreviewItem *)rightItem {
    _leftView.previewItem = leftItem;
    _rightView.previewItem = rightItem;
    
    NSSplitView *split = [self splitView];
    if (!leftItem && rightItem) {
        [split setPosition:0 ofDividerAtIndex:0];
    } else if (leftItem && !rightItem) {
        [split setPosition:split.bounds.size.width ofDividerAtIndex:0];
    } else {
        [split setPosition:split.bounds.size.width / 2.0 ofDividerAtIndex:0];
    }
}

@end

@interface GitPreviewItem ()

- (id)initWithFileURL:(NSURL *)URL name:(NSString *)name;

@property (readwrite) NSURL *previewItemURL;
@property (readwrite) NSString *previewItemTitle;

@end

@implementation GitPreviewItem

@synthesize previewItemURL;
@synthesize previewItemTitle;

+ (GitPreviewItem *)itemWithData:(NSData *)data name:(NSString *)name {
    if (!data) return nil;
    if (!name) return nil;
    
    NSString *ext = [name pathExtension];
    NSString *withoutExt = [name stringByDeletingPathExtension];
    
    NSString *templateStr = [NSString stringWithFormat:@"%@%@.XXXXXX", NSTemporaryDirectory(), withoutExt];
    NSInteger suffixLen = 0;
    
    if ([ext length]) {
        suffixLen = 1 + [ext length];
        templateStr = [templateStr stringByAppendingFormat:@".%@", ext];
    }
    
    char *buf = strdup([templateStr UTF8String]);
    if (-1 != mkstemps(buf, (int)suffixLen)) {
        
        NSString *path = [NSString stringWithUTF8String:buf];
        free(buf);
        
        [data writeToFile:path atomically:NO];
        
        return [[GitPreviewItem alloc] initWithFileURL:[NSURL fileURLWithPath:path] name:name];
    } else {
        ErrLog(@"Unable to create temporary file: %s", strerror(errno));
        free(buf);
        return nil;
    }
}

- (id)initWithFileURL:(NSURL *)URL name:(NSString *)name {
    if (self = [super init]) {
        self.previewItemURL = URL;
        self.previewItemTitle = name;
    }
    return self;
}

- (void)dealloc {
    if (self.previewItemURL) {
        NSURL *URL = self.previewItemURL;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            [[NSFileManager defaultManager] removeItemAtURL:URL error:NULL];
        });
    }
}

@end
