//
//  SearchEditor.m
//  Ship
//
//  Created by James Howard on 7/23/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "SearchEditor.h"

#import "TimeLimitRowTemplate.h"
#import "UserRowTemplate.h"
#import "AssigneeNotContainsTemplate.h"
#import "MilestoneRowTemplate.h"
#import "RepoRowTemplate.h"
#import "StateRowTemplate.h"
#import "LabelRowTemplate.h"
#import "NoneLabelTemplate.h"

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
    
    NSExpression *creationExpr = [NSExpression expressionForKeyPath:@"createdAt"];
    NSExpression *modificationExpr = [NSExpression expressionForKeyPath:@"updatedAt"];
    NSExpression *resolveDateExpr = [NSExpression expressionForKeyPath:@"closedAt"];
    NSPredicateEditorRowTemplate *dateTemplate = [[TimeLimitRowTemplate alloc] initWithLeftExpressions:@[creationExpr, modificationExpr, resolveDateExpr]];
    
    NSExpression *assigneeExpr = [NSExpression expressionForKeyPath:@"assignees.login"];
    NSPredicateEditorRowTemplate *assigneeTemplate = [[UserRowTemplate alloc] initWithLeftExpressions:@[assigneeExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSAnyPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    NSPredicateEditorRowTemplate *assigneeNotTemplate = [AssigneeNotContainsTemplate new];
    
    NSExpression *requestedReviewersExpr = [NSExpression expressionForKeyPath:@"pr.requestedReviewers.login"];
    NSPredicateEditorRowTemplate *requestedReviewersTemplate = [[UserRowTemplate alloc] initWithLeftExpressions:@[requestedReviewersExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSAnyPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    
    NSExpression *originatorExpr = [NSExpression expressionForKeyPath:@"originator.login"];
    NSExpression *resolverExpr = [NSExpression expressionForKeyPath:@"closedBy.login"];
    NSPredicateEditorRowTemplate *userTemplate = [[UserRowTemplate alloc] initWithLeftExpressions:@[originatorExpr, resolverExpr]];
    
    NSExpression *labelCountExpr = [NSExpression expressionForKeyPath:@"labels.@count"];
    NSPredicateEditorRowTemplate *labeledTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[labelCountExpr] rightExpressions:@[[NSExpression expressionForConstantValue:@0]] modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType)] options:0];
    
    LabelRowTemplate *hasLabelTemplate = [[LabelRowTemplate alloc] init];
    LabelRowTemplate *hasNotLabelTemplate = [[NoneLabelTemplate alloc] init];
    
    NSExpression *milestoneExpr = [NSExpression expressionForKeyPath:@"milestone.title"];
    NSPredicateEditorRowTemplate *milestoneTemplate = [[MilestoneRowTemplate alloc] initWithLeftExpressions:@[milestoneExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType), @(NSContainsPredicateOperatorType), @(NSBeginsWithPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSDiacriticInsensitivePredicateOption|NSCaseInsensitivePredicateOption];
    
    NSExpression *repoExpr = [NSExpression expressionForKeyPath:@"repository.fullName"];
    NSPredicateEditorRowTemplate *repoTemplate = [[RepoRowTemplate alloc] initWithLeftExpressions:@[repoExpr] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType), @(NSContainsPredicateOperatorType), @(NSBeginsWithPredicateOperatorType), @(NSMatchesPredicateOperatorType)] options:NSDiacriticInsensitivePredicateOption|NSCaseInsensitivePredicateOption];
    
    NSPredicateEditorRowTemplate *stateTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"state"]] rightExpressions:@[[NSExpression expressionForConstantValue:@"open"], [NSExpression expressionForConstantValue:@"closed"]] modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
                                                   ;
    NSPredicateEditorRowTemplate *readTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"notification.unread"]] rightExpressions:@[[NSExpression expressionForConstantValue:@YES], [NSExpression expressionForConstantValue:@NO]] modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    
    NSPredicateEditorRowTemplate *mentionTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"notification.reason"]] rightExpressions:@[[NSExpression expressionForConstantValue:@"mention"]] modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    
    NSPredicateEditorRowTemplate *issueOrPRTemplate = [[NSPredicateEditorRowTemplate alloc] initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"pullRequest"]] rightExpressions:@[[NSExpression expressionForConstantValue:@YES], [NSExpression expressionForConstantValue:@NO]] modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    
    [self setRowTemplates:@[compounds, assigneeTemplate, assigneeNotTemplate, userTemplate, dateTemplate, repoTemplate, hasLabelTemplate, hasNotLabelTemplate, labeledTemplate, milestoneTemplate, stateTemplate, titleTemplate, bodyTemplate, commentsTemplate, readTemplate, mentionTemplate, issueOrPRTemplate, requestedReviewersTemplate]];

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
    [self setObjectValue:predicate];
}

@end
