//
//  ChartController.m
//  Ship
//
//  Created by James Howard on 8/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "ChartController.h"

#import "ChartConfigController.h"
#import "DataStore.h"
#import "TimeSeries.h"
#import "Extras.h"
#import "Issue.h"
#import "WebKitExtras.h"

@interface ChartController () <WebFrameLoadDelegate, WebUIDelegate, WebPolicyDelegate, ChartConfigControllerDelegate, NSPopoverDelegate> {
    NSInteger _searchGeneration;
    NSString *_javaScriptToRun;
    NSMenu *_menu;
    NSInteger _resultsCount;
    BOOL _didFinishLoading;
}

@property WebView *web;

@property ChartConfigController *config;
@property NSPopover *popover;

@end

@implementation ChartController

- (void)dealloc {
    _web.UIDelegate = nil;
    _web.frameLoadDelegate = nil;
    _web.policyDelegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    _web = [[WebView alloc] initWithFrame:CGRectMake(0, 0, 600, 600) frameName:nil groupName:nil];
    _web.UIDelegate = self;
    _web.frameLoadDelegate = self;
    _web.policyDelegate = self;
    
    self.view = _web;
    
    _config = [ChartConfigController new];
    _config.delegate = self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //_partitionPath = @"assignee.name";
    
    self.title = NSLocalizedString(@"Progress Chart", nil);
    
    NSString *indexPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"ChartWeb"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:indexPath]];
    [_web.mainFrame loadRequest:request];
    
    [[[_web mainFrame] frameView] setAllowsScrolling:NO];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataSourceUpdated:) name:DataStoreDidUpdateProblemsNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataSourceUpdated:) name:DataStoreDidUpdateMetadataNotification object:nil];
}

- (void)chartConfigControllerDismiss:(ChartConfigController *)controller {
    [_popover performClose:nil];
}

- (void)chartConfigController:(ChartConfigController *)controller configChanged:(ChartConfig *)config {
    [self refresh:nil];
}

- (void)popoverDidClose:(NSNotification *)notification {
    [_config save];
}

- (void)dataSourceUpdated:(NSNotification *)note {
    [self refresh:nil];
}

- (IBAction)refresh:(id)sender {
    _searchGeneration++;
    
    if (!self.predicate) {
        self.inProgress = NO;
        [self evaluateJavaScript:@"window.updateChart({intervals:[]})"];
        return;
    }
    
    NSInteger generation = _searchGeneration;
    self.inProgress = YES;
    
    NSDate *start, *end;
    
    ChartConfig *config = _config.chartConfig;
    
    if (config.dateRangeType == ChartDateRangeTypeAbsolute) {
        start = config.startDate;
        end = config.endDate;
    } else {
        NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        start = [calendar dateByAddingUnit:NSCalendarUnitDay value:-(config.daysBack) toDate:[NSDate date] options:0];
        end = [NSDate date];
    }
    
    NSPredicate *basePredicate = self.predicate;
    if ([config.partitionKeyPath isEqualToString:@"state"]) {
        // if we're partitioning on state, don't also filter on it, it doesn't make sense to do so
        basePredicate = [TimeSeries predicateWithoutState:basePredicate];
    }
    
    [[DataStore activeStore] timeSeriesMatchingPredicate:basePredicate startDate:start endDate:end completion:^(TimeSeries *series, NSError *error) {
        if (generation == _searchGeneration) {
            _resultsCount = series.records.count;
            [self timeSeriesToJSON:series partition:config.partitionKeyPath completion:^(NSString *js) {
                if (generation == _searchGeneration) {
                    [self evaluateJavaScript:js];
                    self.inProgress = NO;
                }
            }];
        }
    }];
}

- (void)setPredicate:(NSPredicate *)predicate {
    [super setPredicate:predicate];
    [self refresh:nil];
}

static NSInteger dateToJSONTS(NSDate *d) {
    return (NSInteger)([d timeIntervalSince1970] * 1000.0);
}

- (NSString *)partitionLabelForKeyPath:(NSString *)keyPath value:(id)val {
    if (!val) {
        if ([keyPath isEqualToString:@"milestone.name"]) {
            val = NSLocalizedString(@"Backlog", nil);
        } else {
            val = NSLocalizedString(@"Not Set", nil);
        }
    }
    return val;
}

static NSSet *uniqueKeyPathsInRecords(NSArray *records, NSString *keyPath) {
    NSMutableSet *s = [NSMutableSet new];
    for (id record in records) {
        id val = [record valueForKeyPath:keyPath];
        if (!val) val = [NSNull null];
        [s addObject:val];
    }
    return s;
}

- (void)timeSeriesToJSON:(TimeSeries *)timeSeries partition:(NSString *)partitionPath completion:(void (^)(NSString *js))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [timeSeries generateIntervalsWithCalendarUnit:NSCalendarUnitDay];
        
        NSMutableDictionary *d = [NSMutableDictionary new];
        d[@"startDate"] = @(dateToJSONTS(timeSeries.startDate));
        d[@"endDate"] = @(dateToJSONTS(timeSeries.endDate));
        d[@"count"] = @(timeSeries.records.count);
        
        d[@"intervals"] = [timeSeries.intervals arrayByMappingObjects:^id(id obj) {
            return @{ @"startDate" : @(dateToJSONTS([obj startDate])),
                      @"endDate" : @(dateToJSONTS([obj endDate])),
                      @"count" : @([[obj records] count]) };
        }] ?: @[];
        
        if (partitionPath) {
            NSPredicate *basePredicate = timeSeries.predicate;
            NSSet *partitionValues;
            
            // realartists/shiphub-cocoa#243 State partition chart can be wrong if all matching issues are currently closed
            // Treat state partition specially as even though all the issues in timeSeries might be closed
            // right now, that wasn't always true, so be sure to check the full set of states.
            if ([partitionPath isEqualToString:@"state"]) {
                partitionValues = [NSSet setWithObjects:@"open", @"closed", nil];
            } else {
                partitionValues = uniqueKeyPathsInRecords(timeSeries.records, partitionPath);
            }
            
            NSMutableArray *partitionedSeries = [NSMutableArray arrayWithCapacity:partitionValues.count];
            NSMutableArray *partitionedJSON = d[@"partitions"] = [NSMutableArray arrayWithCapacity:partitionValues.count];
            for (id partitionValue in partitionValues) {
                id val = partitionValue == [NSNull null] ? nil : partitionValue;
                NSPredicate *partitionPredicate = [basePredicate and:[NSPredicate predicateWithFormat:@"%K = %@", partitionPath, val]];
                TimeSeries *ts = [[TimeSeries alloc] initWithPredicate:partitionPredicate startDate:timeSeries.startDate endDate:timeSeries.endDate];
                [ts selectRecordsFrom:timeSeries.records];
                [ts generateIntervalsWithCalendarUnit:NSCalendarUnitDay];
                [partitionedSeries addObject:ts];
                
                NSString *key = [self partitionLabelForKeyPath:partitionPath value:val];
                [partitionedJSON addObject:@{ @"key" : key,
                                              @"intervals" : [ts.intervals arrayByMappingObjects:^id(id obj) {
                    return @{ @"startDate" : @(dateToJSONTS([obj startDate])),
                              @"endDate" : @(dateToJSONTS([obj endDate])),
                              @"count" : @([[obj records] count]) };}] ?: @[]
                                              }];
            }
        }
        
        NSString *json = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:d options:0 error:NULL] encoding:NSUTF8StringEncoding];
        NSString *functionCall = [NSString stringWithFormat:@"window.updateChart(%@);", json];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(functionCall);
        });
    });
}

- (void)evaluateJavaScript:(NSString *)js {
    if (!_didFinishLoading) {
        _javaScriptToRun = js;
    } else {
        [_web stringByEvaluatingJavaScriptFromString:js];
    }
}

- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame {
    __weak __typeof(self) weakSelf = self;
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf configure:nil];
    } name:@"configure"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf showContextMenu:nil];
    } name:@"context"];
    
    NSString *setupJS =
    @"if (!window.webkit) window.webkit = {};\n"
    @"if (!window.webkit.messageHandlers) window.webkit.messageHandlers = {};\n"
    @"window.webkit.messageHandlers.configure = window.configure;\n"
    @"window.webkit.messageHandlers.context = window.context;\n";
    
    [windowObject evaluateWebScript:setupJS];
}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    _didFinishLoading = YES;
    if (_javaScriptToRun) {
        [self evaluateJavaScript:_javaScriptToRun];
        _javaScriptToRun = nil;
    }
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
    //DebugLog(@"%@", actionInformation);
    
    WebNavigationType navigationType = [actionInformation[WebActionNavigationTypeKey] integerValue];
    
    if (navigationType == WebNavigationTypeReload) {
        [listener ignore];
    } else if (navigationType == WebNavigationTypeOther) {
        NSURL *URL = actionInformation[WebActionOriginalURLKey];
        if (![URL isFileURL]) {
            [listener ignore];
        } else {
            [listener use];
        }
    } else {
        [listener ignore];
    }
}

- (IBAction)configure:(id)sender {
    Trace();
    
    if (!_popover) {
        _popover = [[NSPopover alloc] init];
        _popover.delegate = self;
        _popover.behavior = NSPopoverBehaviorApplicationDefined;
        _popover.contentViewController = _config;
        _popover.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    }
    
    [_config prepare];
    [_popover showRelativeToRect:CGRectMake(0, 30.0, self.view.bounds.size.width, 10.0) ofView:self.view preferredEdge:NSMaxYEdge];
}

- (IBAction)showContextMenu:(id)sender {
    if (!_menu) {
        _menu = [NSMenu new];
        NSMenuItem *item = [_menu addItemWithTitle:NSLocalizedString(@"Configure Chart ...", nil) action:@selector(configure:) keyEquivalent:@""];
        item.target = self;
        item = [_menu addItemWithTitle:NSLocalizedString(@"Copy Chart Image", nil) action:@selector(copy:) keyEquivalent:@""];
        item.target = self;
    }
    [_menu popUpMenuPositioningItem:[_menu itemAtIndex:0] atLocation:[NSEvent mouseLocation] inView:nil];
}

- (IBAction)copy:(id)sender {
    NSView *webFrameViewDocView = [[[_web mainFrame] frameView] documentView];
    NSRect cacheRect = [webFrameViewDocView bounds];
    
    NSBitmapImageRep *bitmapRep = [webFrameViewDocView bitmapImageRepForCachingDisplayInRect:cacheRect];
    [webFrameViewDocView cacheDisplayInRect:cacheRect toBitmapImageRep:bitmapRep];
    
    NSSize imgSize = cacheRect.size;
    
    NSRect srcRect = NSZeroRect;
    srcRect.size = imgSize;
    NSRect destRect = NSZeroRect;
    destRect.size = imgSize;
    
    NSImage *image = [[NSImage alloc] initWithSize:imgSize];
    [image lockFocus];
    [bitmapRep drawInRect:destRect
                 fromRect:srcRect
                operation:NSCompositeCopy
                 fraction:1.0
           respectFlipped:YES
                    hints:nil];
    [image unlockFocus];
    
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard clearContents];
    [pboard writeObjects:@[image]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(copy:)) {
        return _resultsCount > 0;
    }
    return YES;
}

@end
