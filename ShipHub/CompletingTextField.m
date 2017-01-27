//
//  CompletingTextField.m
//  Ship
//
//  Created by James Howard on 7/27/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "CompletingTextField.h"

#import "ChevronButton.h"
#import "Extras.h"
#import <objc/runtime.h>

@interface CompletingTextController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

+ (instancetype)controllerForWindow:(NSWindow *)window;
+ (instancetype)controllerForWindow:(NSWindow *)window create:(BOOL)create;

@property (nonatomic, readonly) CompletingTextField *field;
@property (nonatomic, strong) NSTableView *table;

@property (nonatomic, assign) BOOL skipNext;

- (void)updateForTextField:(CompletingTextField *)parentTextField;
- (void)updateForTextField:(CompletingTextField *)parentTextField animateWindow:(BOOL)animateWindow;
- (void)cancelForTextField:(CompletingTextField *)parentTextField;

- (void)moveDown:(CompletingTextField *)sender;
- (void)moveUp:(CompletingTextField *)sender;

@end

@interface CompletingTextField () {
    BOOL my_editing;
}

@property (nonatomic, copy) NSString *stringValuePreCompletions;

@end

@interface CompletingTextFieldCell : NSTextFieldCell

@end

@interface CompletingTextFieldEditor : UndoManagerTextView

@end

@implementation CompletingTextField

// https://mikeash.com/pyblog/custom-nscells-done-right.html
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
    return [CompletingTextFieldCell class];
}

static NSString *titleForOption(id option) {
    if ([option isKindOfClass:[NSArray class]]) {
        return option[0];
    } else {
        return option;
    }
}

static NSString *valueForOption(id option) {
    if ([option isKindOfClass:[NSArray class]]) {
        return option[1];
    } else {
        return option;
    }
}

- (BOOL)textShouldEndEditing:(NSText *)textObject {
    if (!self.complete) return YES;
    
    NSString *text = [textObject string];
    
    if ([text length] == 0) {
        return YES;
    }
    
    NSArray *options = nil;
    if (_complete) {
        options = _complete(text);
    }
    
    if ([options count] == 0) {
        [textObject setString:@""];
        return YES;
    } else if ([options count] == 1 || [[options firstObject] compare:text options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        [textObject setString:titleForOption(options[0])];
        return YES;
    } else {
        CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
        [controller cancelForTextField:self];
        
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Options"];
        for (NSString *option in options) {
            NSMenuItem *item = [menu addItemWithTitle:titleForOption(option) action:@selector(chooseOption:) keyEquivalent:@""];
            item.target = self;
            item.representedObject = valueForOption(option);
        }
        [menu popUpMenuPositioningItem:[menu itemAtIndex:0] atLocation:CGPointZero inView:self];
        return NO;
    }
}

- (void)chooseOption:(id)sender {
    NSMenuItem *item = sender;
    NSString *option = item.representedObject;
    self.stringValue = option;
    [self sendAction:self.action to:self.target];
}

- (void)setStringValue:(NSString *)stringValue {
    UndoManagerTextView *fieldEditor = (UndoManagerTextView *)[self currentEditor];
    [super setStringValue:stringValue];
    [fieldEditor setSelectedRange:NSMakeRange([[fieldEditor string] length], 0)];
    [[CompletingTextController controllerForWindow:self.window] cancelForTextField:self];
}

- (void)setShowsChevron:(BOOL)showsChevron {
    _showsChevron = showsChevron;
}

- (void)setHideCompletions:(BOOL)hideCompletions {
    _hideCompletions = hideCompletions;
    if (_hideCompletions) {
        CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
        [controller cancelForTextField:self];
    } else {
        if ([self currentEditor]) {
            CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
            [controller updateForTextField:self animateWindow:YES];
        }
    }
}

- (BOOL)becomeFirstResponder {
    BOOL become = [super becomeFirstResponder];
    my_editing = become;
    if (become) {
        CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
        [controller updateForTextField:self];
    }
    return become;
}

- (void)textDidEndEditing:(NSNotification *)notification {
    [super textDidEndEditing:notification];
    CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
    [controller cancelForTextField:self];
    self.stringValuePreCompletions = nil;
    my_editing = NO;
}

- (void)textDidChange:(NSNotification *)notification {
    [super textDidChange:notification];
    CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
    [controller updateForTextField:self];
}

- (IBAction)cancelOperation:(id)sender {
    [self abortEditing];
}

- (BOOL)abortEditing {
    NSText *textObject = [self currentEditor];
    if (!textObject) {
        return NO;
    }
    
    if ([self.stringValuePreCompletions length] > 0) {
        [textObject setString:self.stringValuePreCompletions];
        self.stringValuePreCompletions = nil;
    } else if (self.abortValue) {
        [textObject setString:self.abortValue];
    } else if (self.complete) {
        NSString *text = [self textForCompletions];
        
        if ([text length] > 0) {
            NSArray *options = [self completions];
            
            if ([options count] == 0) {
                [textObject setString:@""];
            } else if ([options count] == 1 || [[options firstObject] compare:text options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                [textObject setString:titleForOption(options[0])];
            } else {
                [textObject setString:@""];
            }
        }
    }
    
    my_editing = NO;
    
    if ([self.delegate respondsToSelector:@selector(textDidEndEditing:)]) {
        NSNotification *note = [[NSNotification alloc] initWithName:NSTextDidEndEditingNotification object:self userInfo:nil];
        [(id)(self.delegate) textDidEndEditing:note];
    }
    
    CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
    [controller cancelForTextField:self];
    
    return YES;
}

- (IBAction)showCompletions:(id)sender {
    if (!_complete) return;
    
    CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
    [controller updateForTextField:self];
}

- (NSString *)textForCompletions {
    NSString *stringValue = nil;
    NSText *textObject = [self currentEditor];
    if (textObject) {
        // Only use the text up to the caret position
        NSRange selection = [textObject selectedRange];
        NSString *str = [textObject string];
        if (selection.length > 0) {
            NSString *text = [str substringToIndex:selection.location];
            stringValue = text ?: @"";
        } else {
            return str ?: @"";
        }
    } else {
        stringValue = [self stringValue];
    }
    return stringValue;
}

- (NSArray *)completions {
    if (!_complete) return nil;
    
    return _complete([self textForCompletions]);
}

- (void)mouseDown:(NSEvent *)theEvent {
    [[self currentEditor] selectAll:self];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSWindow *currentWindow = self.window;
    if (currentWindow) {
        CompletingTextController *controller = [CompletingTextController controllerForWindow:currentWindow create:NO];
        [controller cancelForTextField:self];
    }
}

@end

@implementation CompletingTextFieldCell

- (NSTextView *)fieldEditorForView:(NSView *)aControlView {
    NSWindow *window = [aControlView window];
    CompletingTextFieldEditor *view = objc_getAssociatedObject(window, @"CompletingTextFieldEditor");
    if (!view) {
        view = [[CompletingTextFieldEditor alloc] init];
        view.fieldEditor = YES;
        view.undoManager = [window undoManager];
        objc_setAssociatedObject(window, @"CompletingTextFieldEditor", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}

@end

@implementation CompletingTextFieldEditor

- (void)keyDown:(NSEvent *)theEvent {
    if ([theEvent isArrowDown]) {
        CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
        if (!controller.window.isVisible) {
            [controller updateForTextField:(CompletingTextField *)(self.delegate)];
        } else {
            [controller moveDown:(CompletingTextField *)(self.delegate)];
        }
    } else if ([theEvent isArrowUp]) {
        CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
        if (!controller.window.isVisible) {
            [controller updateForTextField:(CompletingTextField *)(self.delegate)];
        } else {
            [controller moveUp:(CompletingTextField *)(self.delegate)];
        }
    } else if ([theEvent modifierFlagsAreExclusively:NSControlKeyMask] && [theEvent isSpace]) {
        [self complete:nil];
    } else if ([theEvent isReturn]) {
        NSString *str = [self string];
        NSRange range = NSMakeRange(str.length, 0);
        [self setSelectedRange:range];
        [super keyDown:theEvent];
    } else {
        [super keyDown:theEvent];
    }
}

- (IBAction)complete:(id)sender {
    id delegate = self.delegate;
    [delegate showCompletions:self];
}

- (void)skipNext {
    CompletingTextController *controller = [CompletingTextController controllerForWindow:self.window];
    controller.skipNext = YES;
}

- (IBAction)deleteForward:(id)sender {
    [self skipNext];
    [super deleteForward:sender];
}

- (IBAction)deleteBackward:(id)sender {
    [self skipNext];
    [super deleteBackward:sender];
}

- (void)deleteBackwardByDecomposingPreviousCharacter:(nullable id)sender {
    [self skipNext];
    [super deleteBackwardByDecomposingPreviousCharacter:sender];
}

- (void)deleteWordForward:(nullable id)sender {
    [self skipNext];
    [super deleteWordForward:sender];
}

- (void)deleteWordBackward:(nullable id)sender {
    [self skipNext];
    [super deleteWordForward:sender];
}

- (void)deleteToBeginningOfLine:(nullable id)sender {
    [self skipNext];
    [super deleteToBeginningOfLine:sender];
}

- (void)deleteToEndOfLine:(nullable id)sender {
    [self skipNext];
    [super deleteToEndOfLine:sender];
}

- (void)deleteToBeginningOfParagraph:(nullable id)sender {
    [self skipNext];
    [super deleteToBeginningOfParagraph:sender];
}

- (void)deleteToEndOfParagraph:(nullable id)sender {
    [self skipNext];
    [super deleteToEndOfParagraph:sender];
}

- (void)yank:(nullable id)sender {
    [self skipNext];
    [super yank:sender];
}

- (void)deleteToMark:(nullable id)sender {
    [self skipNext];
    [super deleteToMark:sender];
}

- (void)setSelectedRange:(NSRange)selectedRange {
    [super setSelectedRange:selectedRange];
}

@end

@interface CompletionRowView : NSTableRowView

@end

@interface CompletionCellView : NSTableCellView

@end

@interface CompletingTableView : NSTableView

@end

@implementation CompletingTextController {
    id _localMouseDownEventMonitor;
    id _lostFocusObserver;
    NSArray *_completions;
    NSTimer *_nextTimer;
    NSInteger _lastHighlighted;
}


static const char *AssocKey = "SmartController";
    
+ (instancetype)controllerForWindow:(NSWindow *)window {
    return [self controllerForWindow:window create:YES];
}
    
+ (instancetype)controllerForWindow:(NSWindow *)window create:(BOOL)create {
    if (!window) {
        return nil;
    }
    if ([window.delegate isKindOfClass:[CompletingTextController class]]) {
        return (id)window.delegate;
    }
    CompletingTextController *c = objc_getAssociatedObject(window, AssocKey);
    if (!c && create) {
        c = [CompletingTextController new];
        objc_setAssociatedObject(window, AssocKey, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return c;
}

- (id)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:CGRectMake(0, 0, 200, 200) styleMask:0 backing:NSBackingStoreBuffered defer:YES];
    
    window.acceptsMouseMovedEvents = YES;
    window.opaque = NO;
    window.backgroundColor = [NSColor clearColor];
    
    //    NSColor *borderColor = [NSColor colorWithRed:0.663 green:0.663 blue:0.663 alpha:1.0];
    NSView *contentView = window.contentView;
    contentView.wantsLayer = YES;
    contentView.layer.opaque = NO;
    contentView.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
    contentView.layer.cornerRadius = 4.0;
    [contentView.layer setMasksToBounds:YES];
    
    [window setHasShadow:NO];
    [window setHasShadow:YES];
    
    if (self = [super initWithWindow:window]) {
        window.delegate = self;
        
        NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:CGRectZero];
        scroll.hasHorizontalScroller = NO;
        scroll.hasVerticalScroller = YES;
        scroll.borderType = NSNoBorder;
        scroll.scrollerStyle = NSScrollerStyleOverlay;
        scroll.verticalScroller.controlSize = NSSmallControlSize;
        scroll.autohidesScrollers = YES;
        scroll.drawsBackground = NO;
        
        NSTableView *table = [[CompletingTableView alloc] init];
        table.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
        table.allowsColumnReordering = NO;
        table.allowsColumnResizing = NO;
        table.allowsColumnSelection = NO;
        table.rowHeight = 17.0;
        table.gridStyleMask = NSTableViewGridNone;
        table.backgroundColor = [NSColor clearColor];
        NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"col"];
        col.minWidth = 1.0;
        col.maxWidth = 10000.0;
        col.title = @"Header";
        col.headerCell.alignment = NSTextAlignmentCenter;
        [table addTableColumn:col];
        [table setHeaderView:nil];
        [scroll setDocumentView:table];
        
        table.delegate = self;
        table.dataSource = self;
        
        self.table = table;
        
        scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [self.window.contentView addSubview:scroll];
    }
    return self;
}


- (void)updateForTextField:(CompletingTextField *)parentTextField {
    [self updateForTextField:parentTextField animateWindow:NO];
}

- (void)updateForTextField:(CompletingTextField *)parentTextField animateWindow:(BOOL)animateWindow {
    if (parentTextField.hideCompletions)
        return;
    
    if (_field != parentTextField) {
        [parentTextField setStringValuePreCompletions:parentTextField.stringValue];
        [self beginForTextField:parentTextField animateWindow:animateWindow];
    } else {
        [self updateSuggestions];
    }
}



- (void)cancelForTextField:(CompletingTextField *)parentTextField {
    if (_field == parentTextField) {
        [self cancelSuggestions];
    }
}

- (NSInteger)highlightedRow {
    return _lastHighlighted;
}

- (void)moveDown:(CompletingTextField *)sender {
    if (_field == sender && _completions.count > 0) {
        NSInteger current = [self highlightedRow];
        NSInteger next;
        if (current == -1) {
            next = 0;
        } else {
            next = MIN(current+1, (NSInteger)(_completions.count) - 1);
        }
        [self highlightRow:next forceUpdate:YES];
    }
}

- (void)moveUp:(CompletingTextField *)sender {
    if (_field == sender && _completions.count > 0) {
        NSInteger current = [self highlightedRow];
        NSInteger next;
        if (current == -1) {
            next = 0;
        } else {
            next = MAX(current-1, 0);
        }
        [self highlightRow:next forceUpdate:YES];
    }
}

- (void)beginForTextField:(CompletingTextField *)parentTextField animateWindow:(BOOL)animateWindow {
    NSWindow *suggestionWindow = self.window;
    NSWindow *parentWindow = parentTextField.window;
    NSRect parentFrame = parentTextField.frame;
    NSRect frame = suggestionWindow.frame;
    frame.size.width = parentFrame.size.width;
    
    // Place the suggestion window just underneath the text field and make it the same width as th text field.
    NSPoint location = [parentTextField.superview convertPoint:parentFrame.origin toView:nil];
    location = [parentWindow convertRectToScreen:CGRectMake(location.x, location.y, 0.0, 0.0)].origin;
    location.y -= 2.0f; // nudge the suggestion window down so it doesn't overlapp the parent view
    [suggestionWindow setFrame:frame display:NO];
    [suggestionWindow setFrameTopLeftPoint:location];
    
    // add the suggestion window as a child window so that it plays nice with Expose
    [parentWindow addChildWindow:suggestionWindow ordered:NSWindowAbove];
    
    // keep track of the parent text field in case we need to commit or abort editing.
    _field = parentTextField;
    
#if 0
    // The window must know its accessibility parent, the control must know the window one of its accessibility children
    // Note that views (controls especially) are often ignored, so we want the unignored descendant - usually a cell
    // Finally, post that we have created the unignored decendant of the suggestions window
    id unignoredAccessibilityDescendant = NSAccessibilityUnignoredDescendant(parentTextField);
    [(SuggestionsWindow *)suggestionWindow setParentElement:unignoredAccessibilityDescendant];
    if ([unignoredAccessibilityDescendant respondsToSelector:@selector(setSuggestionsWindow:)]) {
        [unignoredAccessibilityDescendant setSuggestionsWindow:suggestionWindow];
    }
    NSAccessibilityPostNotification(NSAccessibilityUnignoredDescendant(suggestionWindow),  NSAccessibilityCreatedNotification);
#endif

    if (_field.cancelsOnExternalClick) {
        // setup auto cancellation if the user clicks outside the suggestion window and parent text field. Note: this is a local event monitor and will only catch clicks in windows that belong to this application. We use another technique below to catch clicks in other application windows.
        __weak __typeof(self) weakSelf = self;

        _localMouseDownEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask|NSRightMouseDownMask|NSOtherMouseDown handler:^(NSEvent *event) {
            // If the mouse event is in the suggestion window, then there is nothing to do.
            if ([event window] != suggestionWindow) {
                if ([event window] == parentWindow) {
                    /* Clicks in the parent window should either be in the parent text field or dismiss the suggestions window. We want clicks to occur in the parent text field so that the user can move the caret or select the search text.
                     
                     Use hit testing to determine if the click is in the parent text field. Note: when editing an NSTextField, there is a field editor that covers the text field that is performing the actual editing. Therefore, we need to check for the field editor when doing hit testing.
                     */
                    NSView *contentView = [parentWindow contentView];
                    NSPoint locationTest = [contentView convertPoint:[event locationInWindow] fromView:nil];
                    NSView *hitView = [contentView hitTest:locationTest];
                    NSText *fieldEditor = [parentTextField currentEditor];
                    if (hitView != parentTextField && (fieldEditor && hitView != fieldEditor) ) {
                        [weakSelf cancelSuggestions];
                    }
                } else {
                    // Not in the suggestion window, and not in the parent window. This must be another window or palette for this application.
                    [weakSelf cancelSuggestions];
                }
            }
            
            return event;
        }];
        // as per the documentation, do not retain event monitors.
        
        // We also need to auto cancel when the window loses key status. This may be done via a mouse click in another window, or via the keyboard (cmd-~ or cmd-tab), or a notificaiton. Observing NSWindowDidResignKeyNotification catches all of these cases and the mouse down event monitor catches the other cases.
        _lostFocusObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidResignKeyNotification object:parentWindow queue:nil usingBlock:^(NSNotification *arg1) {
            // lost key status, cancel the suggestion window
            [weakSelf cancelSuggestions];
        }];
    }
    
    if (animateWindow) {
        [self.window setAlphaValue:0];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            [context setDuration:0.3];
            self.window.animator.alphaValue = 1.0;
        } completionHandler:nil];
    }
    
    _lastHighlighted = -1;
    [self updateSuggestions];
}

- (void)cancelSuggestions {
    NSWindow *suggestionWindow = self.window;
    if ([suggestionWindow isVisible]) {
        // Remove the suggestion window from parent window's child window collection before ordering out or the parent window will get ordered out with the suggestion window.
        [[suggestionWindow parentWindow] removeChildWindow:suggestionWindow];
        [suggestionWindow orderOut:nil];
        
#if 0
        // Disconnect the accessibility parent/child relationship
        [[(SuggestionsWindow *)suggestionWindow parentElement] setSuggestionsWindow:nil];
        [(SuggestionsWindow *)suggestionWindow setParentElement:nil];
#endif
    }
    
    // dismantle any observers for auto cancel
    if (_lostFocusObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_lostFocusObserver];
        _lostFocusObserver = nil;
    }
    
    if (_localMouseDownEventMonitor) {
        [NSEvent removeMonitor:_localMouseDownEventMonitor];
        _localMouseDownEventMonitor = nil;
    }
    
    _field = nil;
}

- (void)updateFieldEditor:(NSText *)editor withSuggestion:(NSString *)suggestion forceUpdate:(BOOL)forceUpdate {
    NSRange curSel = [editor selectedRange];
    NSString *text = [[editor string] substringToIndex:curSel.location] ?: @"";
    
    if ([[suggestion lowercaseString] hasPrefix:[text lowercaseString]]) {
        NSRange selection = NSMakeRange([editor selectedRange].location, [suggestion length]);
        [editor setString:suggestion];
        [editor setSelectedRange:selection];
    } else if (forceUpdate) {
        [editor setString:suggestion];
        [editor setSelectedRange:NSMakeRange(0, [suggestion length])];
    }
}

- (void)nextTimerFired:(NSTimer *)timer {
    CompletingTextField *field = timer.userInfo;
    if ([[field currentEditor] isFirstResponder]) {
        [self updateForTextField:field];
    }
    _nextTimer = nil;
}

- (void)updateSuggestions {
    _lastHighlighted = -1;
    [_nextTimer invalidate];
    
    if (_skipNext) {
        _nextTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(nextTimerFired:) userInfo:_field repeats:NO];

        [self cancelSuggestions];
        _skipNext = NO;
        
        return;
    }
    
    _completions = [_field completions];
    
    if ([_completions count] == 0) {
        [self cancelSuggestions];
        return;
    }
    
    CGFloat maxCompletionWidth = 0.0;
    NSDictionary *textAttrs = @{ NSFontAttributeName : [NSFont systemFontOfSize:13.0] };
    for (NSUInteger i = 0; i < _completions.count; i++) {
        NSString *label = _completions[i];
        NSSize size = [label sizeWithAttributes:textAttrs];
        maxCompletionWidth = MAX(maxCompletionWidth, size.width + 10.0);
    }
    
    CGFloat width = _field.frame.size.width;
    CGFloat maxHeight = 160.0;
    CGFloat minWidth = 100.0;
    CGFloat maxWidth = 300.0;
    
    width = MIN(width, maxWidth);
    width = MAX(width, minWidth);
    width = MAX(width, maxCompletionWidth);
    
    [_table reloadData];
    
    CGFloat tableHeight = [_table sizeThatFits:CGSizeMake(width, maxHeight)].height;
    tableHeight = MIN(tableHeight, maxHeight);
    
    CGRect frame = CGRectMake(0, 0, width, tableHeight);
    CGPoint origin = _field.frame.origin;
    CGPoint location = [_field.superview convertPoint:origin toView:nil];
    location = [_field.window convertRectToScreen:CGRectMake(location.x, location.y, 0.0, 0.0)].origin;
    location.y -= tableHeight + 2.0f; // nudge the suggestion window down so it doesn't overlap the parent view
    frame.origin = location;
    [self.window setFrame:frame display:YES];
    self.window.acceptsMouseMovedEvents = YES;
    _table.enclosingScrollView.frame = self.window.contentView.bounds;
    NSString *completable = [_field textForCompletions];
    NSString *first = [self completionForRow:0];
    if ([completable length] > 0 && [[first lowercaseString] hasPrefix:[completable lowercaseString]]) {
        [self highlightRow:0 forceUpdate:NO];
    }
    [_table.enclosingScrollView flashScrollers];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _completions.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cell = [[CompletionCellView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, tableView.rowHeight)];
    cell.textField.stringValue = [self labelForRow:row];
    return cell;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    return [CompletionRowView new];
}

- (NSString *)labelForRow:(NSInteger)row {
    if (!_completions || row >= _completions.count) {
        return @"";
    }
    
    id comp = _completions[row];
    if ([comp isKindOfClass:[NSArray class]]) {
        return [comp componentsJoinedByString:@" — "];
    } else {
        return comp;
    }
}

- (NSString *)completionForRow:(NSInteger)row {
    if (!_completions || row >= _completions.count) {
        return @"";
    }
    
    id comp = _completions[row];
    if ([comp isKindOfClass:[NSArray class]]) {
        return [comp firstObject];
    } else {
        return comp;
    }
}

- (void)highlightRow:(NSInteger)row forceUpdate:(BOOL)forceUpdate {
    if (row == _lastHighlighted) {
        return;
    }
    
    if (row >= 0 && row <= _completions.count) {
        _lastHighlighted = row;
        [_table scrollRowToVisible:row];
        [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [self updateFieldEditor:[_field currentEditor] withSuggestion:[self completionForRow:row] forceUpdate:forceUpdate];
    } else {
        _lastHighlighted = -1;
        [_table selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
    }
}

- (void)rowClicked:(NSInteger)row {
    NSText *editor = (id)[_field currentEditor];
    NSString *completion = [self completionForRow:row];
    [_table scrollRowToVisible:row];
    [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    [editor setString:completion];
    [editor setSelectedRange:NSMakeRange([completion length], 0)];
    [_field sendAction:_field.action to:_field.target];
    [self cancelSuggestions];
}

@end

@interface CompletionRowView ()

@property (nonatomic, strong) NSTrackingArea *trackingArea;

@end

@implementation CompletionRowView

@end

@implementation CompletionCellView {
    NSTextField *_field;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    if (!self.textField) {
        _field = [[NSTextField alloc] initWithFrame:self.bounds];
        _field.editable = NO;
        _field.drawsBackground = NO;
        _field.bordered = NO;
        _field.bezeled = NO;
        _field.selectable = NO;
        _field.font = [NSFont systemFontOfSize:13.0];
        _field.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.autoresizesSubviews = YES;
        [self addSubview:_field];
        self.textField = _field;
    }
}

@end

@implementation CompletingTableView

- (void)mouseDown:(NSEvent *)theEvent {
    CGPoint p = [theEvent locationInWindow];
    p = [self convertPoint:p fromView:nil];
    NSInteger row = [self rowAtPoint:p];
    if (row >= 0 && row < self.numberOfRows) {
        CompletingTextController *controller = (CompletingTextController *)self.delegate;
        [controller rowClicked:row];
    }
}

- (void)mouseMoved:(NSEvent *)theEvent {
    CGPoint p = [theEvent locationInWindow];
    p = [self convertPoint:p fromView:nil];
    NSInteger row = [self rowAtPoint:p];
    if (row >= 0 && row < self.numberOfRows) {
        CompletingTextController *controller = (CompletingTextController *)self.delegate;
        [controller highlightRow:row forceUpdate:YES];
    }
}

@end
