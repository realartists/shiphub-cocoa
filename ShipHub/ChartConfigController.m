//
//  ChartConfigController.m
//  Ship
//
//  Created by James Howard on 8/14/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "ChartConfigController.h"
#import "Extras.h"

@interface ChartConfigController ()

@property IBOutlet NSButton *relativeRadio;
@property IBOutlet NSButton *absoluteRadio;

@property IBOutlet NSSlider *daysBackSlider;
@property IBOutlet NSTextField *daysBackLabel;

@property IBOutlet NSDatePicker *startDatePicker;
@property IBOutlet NSDatePicker *endDatePicker;

@property IBOutlet NSButton *partitionCheck;
@property IBOutlet NSPopUpButton *partitionPopUp;

@property IBOutlet NSButton *rememberCheck;

@end

@implementation ChartConfigController

- (id)init {
    if (self = [super init]) {
        _chartConfig = [ChartConfig defaultConfig];
    }
    return self;
}

- (NSString *)nibName {
    return @"ChartConfigController";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [_partitionPopUp removeAllItems];
    
    [_partitionPopUp addItemWithTitle:NSLocalizedString(@"Assignee", nil)];
    [[_partitionPopUp.itemArray lastObject] setRepresentedObject:@"assignee.login"];
    
    [_partitionPopUp addItemWithTitle:NSLocalizedString(@"Originator", nil)];
    [[_partitionPopUp.itemArray lastObject] setRepresentedObject:@"originator.login"];
    
    [_partitionPopUp addItemWithTitle:NSLocalizedString(@"Closed By", nil)];
    [[_partitionPopUp.itemArray lastObject] setRepresentedObject:@"closedBy.login"];
    
    [_partitionPopUp addItemWithTitle:NSLocalizedString(@"Repo", nil)];
    [[_partitionPopUp.itemArray lastObject] setRepresentedObject:@"repository.fullName"];
    
    [_partitionPopUp addItemWithTitle:NSLocalizedString(@"Milestone", nil)];
    [[_partitionPopUp.itemArray lastObject] setRepresentedObject:@"milestone.title"];
    
    [_partitionPopUp addItemWithTitle:NSLocalizedString(@"State", nil)];
    [[_partitionPopUp.itemArray lastObject] setRepresentedObject:@"state"];
    
    [self prepare];
    [self updateUI];
}

- (void)setChartConfig:(ChartConfig *)chartConfig {
    _chartConfig = [chartConfig copy] ?: [ChartConfig defaultConfig];
    [self updateUI];
}

- (void)updateUI {
    if (_chartConfig.dateRangeType == ChartDateRangeTypeRelative) {
        _relativeRadio.state = NSOnState;
        _absoluteRadio.state = NSOffState;
        
        _daysBackSlider.enabled = YES;
        _startDatePicker.enabled = NO;
        _endDatePicker.enabled = NO;
        
        NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        _chartConfig.endDate = [cal dateByAddingUnit:NSCalendarUnitDay value:1 toDate:[NSDate date] options:0];
        _chartConfig.startDate = [cal dateByAddingUnit:NSCalendarUnitDay value:-(_chartConfig.daysBack) toDate:[NSDate date] options:0];
    } else {
        _relativeRadio.state = NSOffState;
        _absoluteRadio.state = NSOnState;
        
        _daysBackSlider.enabled = NO;
        _startDatePicker.enabled = YES;
        _endDatePicker.enabled = YES;
    }
    
    if (_chartConfig.daysBack <= 7) {
        _daysBackSlider.integerValue = 4;
    } else if (_chartConfig.daysBack <= 14) {
        _daysBackSlider.integerValue = 3;
    } else if (_chartConfig.daysBack <= 30) {
        _daysBackSlider.integerValue = 2;
    } else if (_chartConfig.daysBack <= 90) {
        _daysBackSlider.integerValue = 1;
    } else {
        _daysBackSlider.integerValue = 0;
    }
    
    _daysBackLabel.stringValue = [NSString localizedStringWithFormat:NSLocalizedString(@"%td days back", nil), _chartConfig.daysBack];
    
    _startDatePicker.dateValue = _chartConfig.startDate ?: [NSDate date];
    _endDatePicker.dateValue = _chartConfig.endDate ?: [NSDate date];
    
    if (_chartConfig.partitionKeyPath) {
        _partitionCheck.state = NSOnState;
        _partitionPopUp.enabled = YES;
        [_partitionPopUp selectItemMatchingPredicate:[NSPredicate predicateWithFormat:@"representedObject = %@", _chartConfig.partitionKeyPath]];
    } else {
        _partitionCheck.state = NSOffState;
        _partitionPopUp.enabled = NO;
    }
}

- (void)prepare {
    _rememberCheck.state = NSOffState;
}

- (void)save {
    if (_rememberCheck.state == NSOnState) {
        [_chartConfig saveToDefaults];
    }
}

- (void)didChangeConfig {
    [self updateUI];
    [_delegate chartConfigController:self configChanged:_chartConfig];
}

- (IBAction)daysBackSliderChanged:(id)sender {
    switch (_daysBackSlider.integerValue) {
        case 4:
            _chartConfig.daysBack = 7;
            break;
        case 3:
            _chartConfig.daysBack = 14;
            break;
        case 2:
            _chartConfig.daysBack = 30;
            break;
        case 1:
            _chartConfig.daysBack = 90;
            break;
        case 0:
            _chartConfig.daysBack = 365;
            break;
    }
    [self didChangeConfig];
}

- (IBAction)startDatePickerChanged:(id)sender {
    _chartConfig.startDate = [_startDatePicker dateValue];
    [self didChangeConfig];
}

- (IBAction)endDatePickerChanged:(id)sender {
    _chartConfig.endDate = [_endDatePicker dateValue];
    [self didChangeConfig];
}

- (IBAction)relativeRadioChanged:(id)sender {
    if (_relativeRadio.state == NSOnState) {
        _chartConfig.dateRangeType = ChartDateRangeTypeRelative;
        [self didChangeConfig];
    }
}

- (IBAction)absoluteRadioChanged:(id)sender {
    if (_absoluteRadio.state == NSOnState) {
        _chartConfig.dateRangeType = ChartDateRangeTypeAbsolute;
        [self didChangeConfig];
    }
}

- (IBAction)partitionCheckChanged:(id)sender {
    if (_partitionCheck.state == NSOnState) {
        NSMenuItem *item = [_partitionPopUp selectedItem];
        _chartConfig.partitionKeyPath = item.representedObject;
    } else {
        _chartConfig.partitionKeyPath = nil;
    }
    [self didChangeConfig];
}

- (IBAction)partitionPopUpChanged:(id)sender {
    NSMenuItem *item = [_partitionPopUp selectedItem];
    _chartConfig.partitionKeyPath = item.representedObject;
    [self didChangeConfig];
}

- (IBAction)rememberChanged:(id)sender {
    
}

- (IBAction)resetToDefaults:(id)sender {
    [ChartConfig clearDefaults];
    _chartConfig = [ChartConfig defaultConfig];
    [self didChangeConfig];
}

- (IBAction)close:(id)sender {
    [self save];
    [_delegate chartConfigControllerDismiss:self];
}

- (IBAction)cancel:(id)sender {
    _rememberCheck.state = NSOffState;
    [self close:sender];
}

@end
