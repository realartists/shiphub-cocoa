//
//  Issue3PaneTableController.h
//  ShipHub
//
//  Created by James Howard on 5/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueTableController.h"

@class Issue3PaneTableController;

@protocol Issue3PaneTableControllerDelegate <IssueTableControllerDelegate>

- (void)issueTableController:(Issue3PaneTableController *)table pageAuxiliaryViewBy:(NSInteger)direction;

@end

@interface Issue3PaneTableController : IssueTableController

@property (weak) IBOutlet id<Issue3PaneTableControllerDelegate> delegate;

@end
