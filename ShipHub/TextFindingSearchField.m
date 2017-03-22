//
//  TextFindingSearchField.m
//  ShipHub
//
//  Created by James Howard on 3/22/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "TextFindingSearchField.h"

#import <objc/runtime.h>

@interface TextFindingSearchFieldCell : NSSearchFieldCell

@end

@implementation TextFindingSearchField

- (id)initWithCoder:(NSCoder *)aCoder {
    NSKeyedUnarchiver *coder = (id)aCoder;
    
    // gather info about the superclass's cell and save the archiver's old mapping
    Class superCell = [[self superclass] cellClass];
    NSString *oldClassName = NSStringFromClass( superCell );
    Class oldClass = [coder classForClassName: oldClassName];
    if( !oldClass )
        oldClass = superCell;
    
    // override what comes out of the unarchiver
    [coder setClass: [[self class] cellClass] forClassName: oldClassName];
    
    // unarchive
    self = [super initWithCoder: coder];
    
    // set it back
    [coder setClass: oldClass forClassName: oldClassName];
    
    return self;
}

+ (Class)cellClass {
    return [TextFindingSearchFieldCell class];
}

@end

@interface TextFindingSearchFieldEditor : NSTextView

@end

@implementation TextFindingSearchFieldEditor

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(performFindPanelAction:)
        || menuItem.action == @selector(performTextFinderAction:))
    {
        return YES;
    }
    return [super validateMenuItem:menuItem];
}

- (IBAction)performFindPanelAction:(id)sender {
    id delegate = self.delegate;
    [delegate tryToPerform:@selector(performFindPanelAction:) with:sender];
}

- (IBAction)performTextFinderAction:(id)sender {
    id delegate = self.delegate;
    [delegate tryToPerform:@selector(performTextFinderAction:) with:sender];
}

@end

@implementation TextFindingSearchFieldCell

- (NSTextView *)fieldEditorForView:(NSView *)aControlView {
    NSWindow *window = [aControlView window];
    TextFindingSearchFieldEditor *view = objc_getAssociatedObject(window, @"TextFindingSearchFieldEditor");
    if (!view) {
        view = [[TextFindingSearchFieldEditor alloc] init];
        view.fieldEditor = YES;
        objc_setAssociatedObject(window, @"TextFindingSearchFieldEditor", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}


@end
