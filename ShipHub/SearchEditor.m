//
//  SearchEditor.m
//  Ship
//
//  Created by James Howard on 7/23/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "SearchEditor.h"

#import "NSPredicate+Extras.h"
#import "TimeLimitRowTemplate.h"
#import "UserRowTemplate.h"
#import "ToManyUserNotContainsTemplate.h"
#import "MilestoneRowTemplate.h"
#import "RepoRowTemplate.h"
#import "StateRowTemplate.h"
#import "LabelRowTemplate.h"
#import "NoneLabelTemplate.h"
#import "ReviewStateTemplate.h"

@implementation SearchEditor

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

- (void)addDefaultRows {
    [self insertRowAtIndex:0 withType:NSRuleEditorRowTypeCompound asSubrowOfRow:-1 animate:NO];
    [self insertRowAtIndex:0 withType:NSRuleEditorRowTypeSimple asSubrowOfRow:0 animate:NO];
}

- (void)commonInit {
    NSPredicateEditorRowTemplate *compounds = [[NSPredicateEditorRowTemplate alloc] initWithCompoundTypes:@[@(NSAndPredicateType), @(NSOrPredicateType), @(NSNotPredicateType)]];
    
    NSExpression *titleExpr = [NSExpression expressionForKeyPath:@"title"];
    NSPredicateEditorRowTemplate *titleTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[titleExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSContainsPredicateOperatorType), @(NSBeginsWithPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSDiacriticInsensitivePredicateOption|NSCaseInsensitivePredicateOption];
    
    NSExpression *bodyExpr = [NSExpression expressionForKeyPath:@"body"];
    NSPredicateEditorRowTemplate *bodyTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[bodyExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSContainsPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSDiacriticInsensitivePredicateOption|NSCaseInsensitivePredicateOption];
    
    NSExpression *commentsExpr = [NSExpression expressionForKeyPath:@"comments.body"];
    NSPredicateEditorRowTemplate *commentsTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[commentsExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSAnyPredicateModifier operators:@[@(NSContainsPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSDiacriticInsensitivePredicateOption|NSCaseInsensitivePredicateOption];
    
    NSExpression *commentsCountExpr = [NSExpression expressionWithFormat:@"comments.@count"];
    NSPredicateEditorRowTemplate *commentsCountTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[commentsCountExpr] rightExpressions:@[[NSExpression expressionForConstantValue:@0]] modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType)] options:0];
    
    NSExpression *creationExpr = [NSExpression expressionForKeyPath:@"createdAt"];
    NSExpression *modificationExpr = [NSExpression expressionForKeyPath:@"updatedAt"];
    NSExpression *resolveDateExpr = [NSExpression expressionForKeyPath:@"closedAt"];
    NSPredicateEditorRowTemplate *dateTemplate = [[TimeLimitRowTemplate alloc] initWithLeftExpressions:@[creationExpr, modificationExpr, resolveDateExpr]];
    
    NSExpression *assigneeExpr = [NSExpression expressionForKeyPath:@"assignees.login"];
    NSPredicateEditorRowTemplate *assigneeTemplate = [[UserRowTemplate alloc] initWithLeftExpressions:@[assigneeExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSAnyPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    NSPredicateEditorRowTemplate *assigneeNotTemplate = [[ToManyUserNotContainsTemplate alloc] initWithLoginKeyPath:@"assignees.login"];
    
    NSExpression *requestedReviewersExpr = [NSExpression expressionForKeyPath:@"pr.requestedReviewers.login"];
    NSPredicateEditorRowTemplate *requestedReviewersTemplate = [[UserRowTemplate alloc] initWithLeftExpressions:@[requestedReviewersExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSAnyPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    
    NSExpression *reviewersExpr = [NSExpression expressionForKeyPath:@"reviews.user.login"];
    NSPredicateEditorRowTemplate *reviewersTemplate = [[UserRowTemplate alloc] initWithLeftExpressions:@[reviewersExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSAnyPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    
    NSPredicateEditorRowTemplate *reviewerNotTemplate = [[ToManyUserNotContainsTemplate alloc] initWithLoginKeyPath:@"reviews.user.login"];
    
    ReviewStateTemplate *reviewState = [ReviewStateTemplate new];
    
    NSExpression *originatorExpr = [NSExpression expressionForKeyPath:@"originator.login"];
    NSExpression *resolverExpr = [NSExpression expressionForKeyPath:@"closedBy.login"];
    NSPredicateEditorRowTemplate *userTemplate = [[UserRowTemplate alloc] initWithLeftExpressions:@[originatorExpr, resolverExpr]];
    
    NSExpression *labelCountExpr = [NSExpression expressionForKeyPath:@"labels.@count"];
    NSPredicateEditorRowTemplate *labeledTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[labelCountExpr] rightExpressions:@[[NSExpression expressionForConstantValue:@0]] modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType)] options:0];
    
    LabelRowTemplate *hasLabelTemplate = [[LabelRowTemplate alloc] init];
    LabelRowTemplate *hasNotLabelTemplate = [[NoneLabelTemplate alloc] init];
    
    NSExpression *labelNameExpr = [NSExpression expressionForKeyPath:@"labels.name"];
    NSPredicateEditorRowTemplate *labelMatchTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[labelNameExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSAnyPredicateModifier operators:@[@(NSContainsPredicateOperatorType), @(NSBeginsWithPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSDiacriticInsensitiveSearch|NSCaseInsensitiveSearch];
    
    NSExpression *milestoneExpr = [NSExpression expressionForKeyPath:@"milestone.title"];
    NSPredicateEditorRowTemplate *milestoneTemplate = [[MilestoneRowTemplate alloc] initWithLeftExpressions:@[milestoneExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType)] options:NSDiacriticInsensitivePredicateOption|NSCaseInsensitivePredicateOption];
    NSPredicateEditorRowTemplate *milestoneSubstringTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[milestoneExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSContainsPredicateOperatorType), @(NSBeginsWithPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSDiacriticInsensitivePredicateOption|NSCaseInsensitivePredicateOption];
    
    NSExpression *repoExpr = [NSExpression expressionForKeyPath:@"repository.fullName"];
    NSPredicateEditorRowTemplate *repoTemplate = [[RepoRowTemplate alloc] initWithLeftExpressions:@[repoExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType)] options:NSDiacriticInsensitivePredicateOption|NSCaseInsensitivePredicateOption];
    
    NSPredicateEditorRowTemplate *repoSubstringTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[repoExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSContainsPredicateOperatorType), @(NSBeginsWithPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSDiacriticInsensitivePredicateOption|NSCaseInsensitivePredicateOption];
    
    NSPredicateEditorRowTemplate *stateTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"state"]] rightExpressions:@[[NSExpression expressionForConstantValue:@"open"], [NSExpression expressionForConstantValue:@"closed"]] modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
                                                   ;
    NSPredicateEditorRowTemplate *readTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"notification.unread"]] rightExpressions:@[[NSExpression expressionForConstantValue:@YES], [NSExpression expressionForConstantValue:@NO]] modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    
    NSExpression *mentionExpr = [NSExpression expressionForKeyPath:@"mentions.login"];
    NSPredicateEditorRowTemplate *mentionTemplate = [[UserRowTemplate alloc] initWithLeftExpressions:@[mentionExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSAnyPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    
    NSPredicateEditorRowTemplate *issueOrPRTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"pullRequest"]] rightExpressions:@[[NSExpression expressionForConstantValue:@YES], [NSExpression expressionForConstantValue:@NO]] modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    
    NSPredicateEditorRowTemplate *prBaseBranchTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"pr.baseBranch"]] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType), @(NSBeginsWithPredicateOperatorType), @(NSContainsPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch];
    NSPredicateEditorRowTemplate *prHeadBranchTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"pr.shipHeadBranch"]] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType), @(NSBeginsWithPredicateOperatorType), @(NSContainsPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch];
    NSPredicateEditorRowTemplate *prHeadRepoFullNameTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"pr.shipHeadRepoFullName"]] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType), @(NSBeginsWithPredicateOperatorType), @(NSContainsPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch];
    
    [self setRowTemplates:@[compounds, assigneeTemplate, assigneeNotTemplate, userTemplate, dateTemplate, repoTemplate, repoSubstringTemplate, hasLabelTemplate, hasNotLabelTemplate, labeledTemplate, labelMatchTemplate, milestoneTemplate, milestoneSubstringTemplate, stateTemplate, titleTemplate, bodyTemplate, commentsTemplate, commentsCountTemplate, readTemplate, mentionTemplate, issueOrPRTemplate, requestedReviewersTemplate, reviewersTemplate, reviewerNotTemplate, reviewState, prBaseBranchTemplate, prHeadBranchTemplate, prHeadRepoFullNameTemplate]];

    @try {
        [self setFormattingStringsFilename:@"SearchEditor"];
    } @catch (id exc) {
        ErrLog(@"Cannot parse strings file: %@", exc);
    }
    
    [self addDefaultRows];
}

- (void)reset {
    while ([self numberOfRows]) {
        [self removeRowAtIndex:0];
    }
    
    [self addDefaultRows];
}

- (void)assignPredicate:(NSPredicate *)predicate {
    if (![predicate isKindOfClass:[NSCompoundPredicate class]]) {
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate]];
    }
    predicate = [predicate predicateByRewriting:^NSPredicate *(NSPredicate *original) {
        if ([original isKindOfClass:[NSCompoundPredicate class]]) {
            NSCompoundPredicate *c0 = (id)original;
            if (c0.compoundPredicateType == NSNotPredicateType
                && c0.subpredicates.count == 1
                && ![[c0.subpredicates firstObject] isKindOfClass:[NSCompoundPredicate class]]) {
                NSCompoundPredicate *nor = [[NSCompoundPredicate alloc] initWithType:NSOrPredicateType subpredicates:c0.subpredicates];
                return [[NSCompoundPredicate alloc] initWithType:NSNotPredicateType subpredicates:@[nor]];
            }
        }
        return original;
    }];
    [self setObjectValue:predicate];
}

- (void)addCompoundPredicate {
    NSInteger rowCount = self.numberOfRows;
    [self insertRowAtIndex:rowCount withType:NSRuleEditorRowTypeCompound asSubrowOfRow:0 animate:YES];
    [self insertRowAtIndex:rowCount+1 withType:NSRuleEditorRowTypeSimple asSubrowOfRow:rowCount animate:YES];
}

@end
