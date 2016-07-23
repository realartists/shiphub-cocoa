//
//  RepoRowTemplate.m
//  ShipHub
//
//  Created by James Howard on 7/23/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "RepoRowTemplate.h"

#import "CompletingTextField.h"

#import "DataStore.h"
#import "MetadataStore.h"
#import "Extras.h"

@implementation RepoRowTemplate

- (NSArray *)complete:(NSString *)text {
    MetadataStore *metadata = [[DataStore activeStore] metadataStore];
    NSArray *repos = [[metadata activeRepos] arrayByMappingObjects:^id(id obj) {
        return [obj fullName];
    }];
    if ([text length] == 0) {
        return repos;
    } else {
        return [repos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[cd] %@", text]];
    }
}

- (CompletingTextField *)textField {
    CompletingTextField *field = [super textField];
    CGRect frame = field.frame;
    frame.size.width = 270.0;
    field.frame = frame;
    return field;
}

@end
