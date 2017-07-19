//
//  RepoSearchField.m
//  ShipHub
//
//  Created by James Howard on 7/19/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RepoSearchField.h"

#import "Auth.h"
#import "Extras.h"
#import "AvatarManager.h"
#import <objc/runtime.h>

@interface RepoCompletingTextController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

+ (instancetype)controllerForWindow:(NSWindow *)window;
+ (instancetype)controllerForWindow:(NSWindow *)window create:(BOOL)create;

@property (nonatomic, readonly) RepoSearchField *field;
@property (nonatomic, strong) NSTableView *table;

@property (nonatomic, assign) BOOL skipNext;

- (void)updateForTextField:(RepoSearchField *)parentTextField;
- (void)updateForTextField:(RepoSearchField *)parentTextField animateWindow:(BOOL)animateWindow;
- (void)cancelForTextField:(RepoSearchField *)parentTextField;

- (void)moveDown:(RepoSearchField *)sender;
- (void)moveUp:(RepoSearchField *)sender;

@end

@interface RepoSearchField () {
    BOOL my_editing;
    NSString *_lastCompletionsSearchValue;
    NSURLSessionDataTask *_dataTask;
    NSTimer *_fetchTimer;
}

@property (nonatomic, copy) NSString *stringValuePreCompletions;

@end

@interface RepoSearchFieldCell : NSTextFieldCell

@end

@interface RepoSearchFieldEditor : NSTextView

@end

@implementation RepoSearchField

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
    return [RepoSearchFieldCell class];
}

- (void)fetchTimerFired:(NSTimer *)timer {
    void (^resultHandler)(NSArray *) = timer.userInfo[@"handler"];
    NSString *val = timer.userInfo[@"val"];
    
    _fetchTimer = nil;
    
    [_dataTask cancel];
    _lastCompletionsSearchValue = val;
    
    DebugLog(@"Searching repos for %@", val);
    
    NSArray *repoNameParts = [val componentsSeparatedByString:@"/"];
    
    NSURLComponents *comps = [NSURLComponents new];
    comps.scheme = @"https";
    comps.host = _auth.account.ghHost;
    comps.path = @"/search/repositories";
    
    if (repoNameParts.count == 2) {
        NSString *repoPart = repoNameParts[1];
        if ([[repoPart trim] length]) {
            comps.queryItemsDictionary = @{ @"q" : [NSString stringWithFormat:@"%@ in:name user:%@", repoNameParts[1], repoNameParts[0]] };
        } else {
            comps.queryItemsDictionary = @{ @"q" : [NSString stringWithFormat:@"user:%@", repoNameParts[0]] };
        }
    } else {
        comps.queryItemsDictionary = @{ @"q" : [NSString stringWithFormat:@"%@ in:name", val] };
    }
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:comps.URL];
    [_auth addAuthHeadersToRequest:req];
    
    
    NSURLSessionDataTask *task = _dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *http = (id)response;
        if (data && !error && [http isSuccessStatusCode]) {
            NSDictionary *results = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if (results && [results isKindOfClass:[NSDictionary class]]) {
                RunOnMain(^{
                    resultHandler(results[@"items"]?:@[]);
                });
            }
        }
    }];
    
    [task resume];
}

- (void)fetchCompletions:(void (^)(NSArray *))resultHandler {
    NSString *val = [[self textForCompletions] trim];
    
    if ([val length] == 0) {
        resultHandler(@[]);
        return;
    }

    if ([val isEqualToString:_lastCompletionsSearchValue]) {
        return;
    }
    
    if (!_lastCompletionsSearchValue || ![val hasPrefix:_lastCompletionsSearchValue]) {
        resultHandler(@[]);
    }
    
    [_fetchTimer invalidate];
    _fetchTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 weakTarget:self selector:@selector(fetchTimerFired:) userInfo:@{@"handler":[resultHandler copy], @"val":val} repeats:NO];
}

- (NSImage *)avatarForCompletion:(NSDictionary *)completion {
    return [_avatarManager imageForAccountIdentifier:completion[@"owner"][@"id"] avatarURL:completion[@"owner"][@"avatar_url"]];
}

- (void)setStringValue:(NSString *)stringValue {
    NSText *fieldEditor = [self currentEditor];
    [super setStringValue:stringValue];
    [fieldEditor setSelectedRange:NSMakeRange([[fieldEditor string] length], 0)];
    [[RepoCompletingTextController controllerForWindow:self.window] cancelForTextField:self];
}

- (BOOL)becomeFirstResponder {
    BOOL become = [super becomeFirstResponder];
    my_editing = become;
    if (become) {
        RepoCompletingTextController *controller = [RepoCompletingTextController controllerForWindow:self.window];
        [controller updateForTextField:self];
    }
    return become;
}

- (void)textDidEndEditing:(NSNotification *)notification {
    [super textDidEndEditing:notification];
    RepoCompletingTextController *controller = [RepoCompletingTextController controllerForWindow:self.window];
    [controller cancelForTextField:self];
    self.stringValuePreCompletions = nil;
    my_editing = NO;
}

- (void)textDidChange:(NSNotification *)notification {
    [super textDidChange:notification];
    RepoCompletingTextController *controller = [RepoCompletingTextController controllerForWindow:self.window];
    [controller updateForTextField:self];
}

- (IBAction)cancelOperation:(id)sender {
    [super setStringValue:@""];
    [self abortEditing];
}

- (IBAction)showCompletions:(id)sender {
    RepoCompletingTextController *controller = [RepoCompletingTextController controllerForWindow:self.window];
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

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    NSWindow *currentWindow = self.window;
    if (currentWindow) {
        RepoCompletingTextController *controller = [RepoCompletingTextController controllerForWindow:currentWindow create:NO];
        [controller cancelForTextField:self];
    }
}

- (BOOL)abortEditing {
    RepoCompletingTextController *controller = [RepoCompletingTextController controllerForWindow:self.window];
    [controller cancelForTextField:self];
    return [super abortEditing];
}

@end

@implementation RepoSearchFieldCell

- (NSTextView *)fieldEditorForView:(NSView *)aControlView {
    NSWindow *window = [aControlView window];
    RepoSearchFieldEditor *view = objc_getAssociatedObject(window, @"RepoSearchFieldEditor");
    if (!view) {
        view = [[RepoSearchFieldEditor alloc] init];
        view.fieldEditor = YES;
        objc_setAssociatedObject(window, @"RepoSearchFieldEditor", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}

@end

@implementation RepoSearchFieldEditor

- (void)keyDown:(NSEvent *)theEvent {
    if ([theEvent isArrowDown]) {
        RepoCompletingTextController *controller = [RepoCompletingTextController controllerForWindow:self.window];
        if (!controller.window.isVisible) {
            [controller updateForTextField:(RepoSearchField *)(self.delegate)];
        } else {
            [controller moveDown:(RepoSearchField *)(self.delegate)];
        }
    } else if ([theEvent isArrowUp]) {
        RepoCompletingTextController *controller = [RepoCompletingTextController controllerForWindow:self.window];
        if (!controller.window.isVisible) {
            [controller updateForTextField:(RepoSearchField *)(self.delegate)];
        } else {
            [controller moveUp:(RepoSearchField *)(self.delegate)];
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
    RepoCompletingTextController *controller = [RepoCompletingTextController controllerForWindow:self.window];
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

@interface RepoCompletionRowView : NSTableRowView

@end

@interface RepoCompletionCellView : NSTableCellView

@property AvatarImageView *avatarImageView;

@end

@interface RepoCompletingTableView : NSTableView

@end

@implementation RepoCompletingTextController {
    id _localMouseDownEventMonitor;
    id _lostFocusObserver;
    NSArray *_completions;
    NSTimer *_nextTimer;
    NSInteger _lastHighlighted;
}


static const char *AssocKey = "RepoCompletingTextController";

+ (instancetype)controllerForWindow:(NSWindow *)window {
    return [self controllerForWindow:window create:YES];
}

+ (instancetype)controllerForWindow:(NSWindow *)window create:(BOOL)create {
    if (!window) {
        return nil;
    }
    if ([window.delegate isKindOfClass:[RepoCompletingTextController class]]) {
        return (id)window.delegate;
    }
    RepoCompletingTextController *c = objc_getAssociatedObject(window, AssocKey);
    if (!c && create) {
        c = [RepoCompletingTextController new];
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
        
        NSTableView *table = [[RepoCompletingTableView alloc] init];
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


- (void)updateForTextField:(RepoSearchField *)parentTextField {
    [self updateForTextField:parentTextField animateWindow:NO];
}

- (void)updateForTextField:(RepoSearchField *)parentTextField animateWindow:(BOOL)animateWindow {
    [self updateSuggestionsForTextField:parentTextField];
}

- (void)cancelForTextField:(RepoSearchField *)parentTextField {
    if (_field == parentTextField) {
        [self cancelSuggestions];
    }
}

- (NSInteger)highlightedRow {
    return _lastHighlighted;
}

- (void)moveDown:(RepoSearchField *)sender {
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

- (void)moveUp:(RepoSearchField *)sender {
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

- (void)beginForTextField:(RepoSearchField *)parentTextField animateWindow:(BOOL)animateWindow {
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
    
    if (YES /*_field.cancelsOnExternalClick*/) {
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
    RepoSearchField *field = timer.userInfo;
    if ([[field currentEditor] isFirstResponder]) {
        [self updateForTextField:field];
    }
    _nextTimer = nil;
}

- (void)updateSuggestionsForTextField:(RepoSearchField *)field {
    _lastHighlighted = -1;
    [_nextTimer invalidate];
    
    if (_skipNext) {
        _nextTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(nextTimerFired:) userInfo:_field repeats:NO];
        
        [self cancelSuggestions];
        _skipNext = NO;
        
        return;
    }
    
    [field fetchCompletions:^(NSArray *results) {
        _completions = results;
        
        if ([_completions count] == 0) {
            [_table reloadData];
            [self cancelSuggestions];
            return;
        }
        
        if (_field != field) {
            [self beginForTextField:field animateWindow:YES];
        }
        
        CGFloat maxCompletionWidth = 0.0;
        NSDictionary *textAttrs = @{ NSFontAttributeName : [NSFont systemFontOfSize:13.0] };
        for (NSUInteger i = 0; i < _completions.count; i++) {
            NSString *label = [self labelForRow:i];
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
    }];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _completions.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    RepoCompletionCellView *cell = [[RepoCompletionCellView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, tableView.rowHeight)];
    cell.textField.stringValue = [self labelForRow:row];
    cell.avatarImageView.image = [_field avatarForCompletion:_completions[row]];
    return cell;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    return [RepoCompletionRowView new];
}

- (NSString *)labelForRow:(NSInteger)row {
    if (!_completions || row >= _completions.count) {
        return @"";
    }
    
    NSDictionary *comp = _completions[row];
    return comp[@"full_name"];
}

- (NSString *)completionForRow:(NSInteger)row {
    return [self labelForRow:row];
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

@interface RepoCompletionRowView ()

@property (nonatomic, strong) NSTrackingArea *trackingArea;

@end

@implementation RepoCompletionRowView

@end

@implementation RepoCompletionCellView {
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
        CGRect bounds = self.bounds;
        
        _field = [[NSTextField alloc] initWithFrame:CGRectMake(bounds.size.height, 0, bounds.size.width - bounds.size.height, bounds.size.height)];
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
        
        self.imageView = self.avatarImageView = [[AvatarImageView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.height, bounds.size.height)];
        [self addSubview:self.imageView];
    }
}

@end

@implementation RepoCompletingTableView

- (void)mouseDown:(NSEvent *)theEvent {
    CGPoint p = [theEvent locationInWindow];
    p = [self convertPoint:p fromView:nil];
    NSInteger row = [self rowAtPoint:p];
    if (row >= 0 && row < self.numberOfRows) {
        RepoCompletingTextController *controller = (RepoCompletingTextController *)self.delegate;
        [controller rowClicked:row];
    }
}

- (void)mouseMoved:(NSEvent *)theEvent {
    CGPoint p = [theEvent locationInWindow];
    p = [self convertPoint:p fromView:nil];
    NSInteger row = [self rowAtPoint:p];
    if (row >= 0 && row < self.numberOfRows) {
        RepoCompletingTextController *controller = (RepoCompletingTextController *)self.delegate;
        [controller highlightRow:row forceUpdate:YES];
    }
}

@end


