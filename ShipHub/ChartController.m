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

@interface ChartController () <WKNavigationDelegate, ChartConfigControllerDelegate, NSPopoverDelegate> {
    NSInteger _searchGeneration;
    NSString *_javaScriptToRun;
    NSMenu *_menu;
    BOOL _didFinishLoading;
}

@property WKWebView *web;

@property ChartConfigController *config;
@property NSPopover *popover;

@end

@implementation ChartController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    WKUserContentController *userContent = [WKUserContentController new];
    config.userContentController = userContent;
    
    __weak __typeof(self) weakSelf = self;
    [userContent addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf configure:nil];
    } name:@"configure"];
    
    [userContent addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf showContextMenu:nil];
    } name:@"context"];
    
    _web = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 600, 600) configuration:config];
    _web.navigationDelegate = self;
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
    [_web loadRequest:request];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataSourceUpdated:) name:DataStoreDidUpdateProblemsNotification object:nil];
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
        [self evaluateJavaScript:@"updateChart({intervals:[]})"];
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
    
    [[DataStore activeStore] timeSeriesMatchingPredicate:self.predicate startDate:start endDate:end completion:^(TimeSeries *series, NSError *error) {
        if (generation == _searchGeneration) {
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

- (NSString *)partitionLabelForKeyPath:(NSString *)keyPath representativeObject:(Issue *)obj {
    id val = [obj valueForKeyPath:keyPath];
    if (!val) {
        if ([keyPath isEqualToString:@"milestone.name"]) {
            val = NSLocalizedString(@"Backlog", nil);
        } else {
            val = NSLocalizedString(@"Not Set", nil);
        }
    }
    return val;
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
            NSArray *partitionedObjects = [timeSeries.records partitionByKeyPath:partitionPath];
            NSMutableArray *partitionedSeries = [NSMutableArray arrayWithCapacity:partitionedObjects.count];
            NSMutableArray *partitionedJSON = d[@"partitions"] = [NSMutableArray arrayWithCapacity:partitionedObjects.count];
            for (NSArray *partition in partitionedObjects) {
                TimeSeries *ts = [[TimeSeries alloc] initWithPredicate:timeSeries.predicate startDate:timeSeries.startDate endDate:timeSeries.endDate];
                [ts selectRecordsFrom:partition];
                [ts generateIntervalsWithCalendarUnit:NSCalendarUnitDay];
                [partitionedSeries addObject:ts];
                
                NSString *key = [self partitionLabelForKeyPath:partitionPath representativeObject:partition[0]];
                [partitionedJSON addObject:@{ @"key" : key,
                                              @"intervals" : [ts.intervals arrayByMappingObjects:^id(id obj) {
                    return @{ @"startDate" : @(dateToJSONTS([obj startDate])),
                              @"endDate" : @(dateToJSONTS([obj endDate])),
                              @"count" : @([[obj records] count]) };}] ?: @[]
                                              }];
            }
        }
        
        NSString *json = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:d options:0 error:NULL] encoding:NSUTF8StringEncoding];
        NSString *functionCall = [NSString stringWithFormat:@"updateChart(%@);", json];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(functionCall);
        });
    });
}

- (void)evaluateJavaScript:(NSString *)js {
    if (!_didFinishLoading) {
        _javaScriptToRun = js;
    } else {
        [_web evaluateJavaScript:js completionHandler:^(id o, NSError *e) {
            if (e) {
                ErrLog(@"%@", e);
            }
        }];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    _didFinishLoading = YES;
    if (_javaScriptToRun) {
        [self evaluateJavaScript:_javaScriptToRun];
        _javaScriptToRun = nil;
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
    }
    [_menu popUpMenuPositioningItem:[_menu itemAtIndex:0] atLocation:[NSEvent mouseLocation] inView:nil];
}


@end
