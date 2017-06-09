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

@interface TextFindingTextFieldCell : NSTextFieldCell

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

@implementation TextFindingTextField

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
    return [TextFindingTextFieldCell class];
}

@end

@interface TextFindingFieldEditor : NSTextView

@end

@implementation TextFindingFieldEditor

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
    TextFindingFieldEditor *view = objc_getAssociatedObject(window, @"TextFindingFieldEditor");
    if (!view) {
        view = [[TextFindingFieldEditor alloc] init];
        view.fieldEditor = YES;
        objc_setAssociatedObject(window, @"TextFindingFieldEditor", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}

@end

@implementation TextFindingTextFieldCell

- (NSTextView *)fieldEditorForView:(NSView *)aControlView {
    NSWindow *window = [aControlView window];
    TextFindingFieldEditor *view = objc_getAssociatedObject(window, @"TextFindingFieldEditor");
    if (!view) {
        view = [[TextFindingFieldEditor alloc] init];
        view.fieldEditor = YES;
        objc_setAssociatedObject(window, @"TextFindingFieldEditor", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}

@end
