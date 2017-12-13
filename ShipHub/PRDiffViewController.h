//
//  PRDiffViewController.h
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IssueWeb2Controller.h"
#import "DiffViewMode.h"

@class Account;
@class GitDiff;
@class GitDiffFile;
@class PRComment;
@class PendingPRComment;
@class PullRequest;
@protocol PRAdapter;

@protocol PRDiffViewControllerDelegate;

@interface PRDiffViewController : IssueWeb2Controller

@property (nonatomic, strong) id<PRAdapter> adapter;

@property (weak) id<PRDiffViewControllerDelegate> delegate;

- (void)setPR:(PullRequest *)pr diffFile:(GitDiffFile *)diffFile diff:(GitDiff *)diff comments:(NSArray<PRComment *> *)comments mentionable:(NSArray<Account *> *)mentionable inReview:(BOOL)inReview scrollInfo:(NSDictionary *)scrollInfo;

- (void)scrollToComment:(PRComment *)comment;
- (void)navigate:(NSDictionary *)options; // See diff.js: App.scrollTo() docstring for options

- (void)setComments:(NSArray<PRComment *> *)comments inReview:(BOOL)inReview;

- (void)focus;

- (void)hideFindController;

@property (nonatomic, readonly) PullRequest *pr;
@property (nonatomic, readonly) GitDiffFile *diffFile;
@property (nonatomic, readonly) GitDiff *diff;
@property (readonly, getter=isInReview) BOOL inReview;
@property (nonatomic, readonly) NSArray<PRComment *> *comments;
@property (nonatomic, readonly) NSArray<Account *> *mentionable;

@property (nonatomic, assign) DiffViewMode mode;

@end

@protocol PRDiffViewControllerDelegate <NSObject>

- (void)diffViewController:(PRDiffViewController *)vc
        queueReviewComment:(PendingPRComment *)comment;

- (void)diffViewController:(PRDiffViewController *)vc
          addReviewComment:(PendingPRComment *)comment;

- (void)diffViewController:(PRDiffViewController *)vc
         editReviewComment:(PRComment *)comment;

- (void)diffViewController:(PRDiffViewController *)vc
       deleteReviewComment:(PRComment *)comment;

- (void)diffViewController:(PRDiffViewController *)vc
               addReaction:(NSString *)reaction
   toCommentWithIdentifier:(NSNumber *)commentIdentifier;

- (void)diffViewController:(PRDiffViewController *)vc
    deleteReactionWithIdentifier:(NSNumber *)reactionIdentifier
       fromCommentWithIdentifier:(NSNumber *)commentIdentifier;

- (void)diffViewController:(PRDiffViewController *)vc
        continueNavigation:(NSDictionary *)options;

@end
