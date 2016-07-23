//
//  MilestoneRowTemplate.m
//  Ship
//
//  Created by James Howard on 7/27/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "MilestoneRowTemplate.h"

#import "CompletingTextField.h"

#import "DataStore.h"
#import "MetadataStore.h"
#import "Extras.h"

@implementation MilestoneRowTemplate

- (NSArray *)complete:(NSString *)text {
    MetadataStore *metadata = [[DataStore activeStore] metadataStore];
    NSArray *milestones = [metadata mergedMilestoneNames];
    if ([text length] == 0) {
        return milestones;
    } else {
        milestones = [milestones filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[cd] %@", text]];
    }
    return milestones;
}

- (NSString *)valueWithIdentifier:(NSString *)identifier {
    return identifier;
}

- (NSString *)identifierWithValue:(NSString *)value {
    return [value length] > 0 ? value : nil;
}

- (CompletingTextField *)textField {
    CompletingTextField *textField = [super textField];
    textField.placeholderString = NSLocalizedString(@"Backlog", nil);
    return textField;
}

@end
