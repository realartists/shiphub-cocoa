//
//  SemiMixedButton.m
//  ShipHub
//
//  Created by James Howard on 8/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "SemiMixedButton.h"

@interface SemiMixedButtonCell : NSButtonCell

@property NSInteger nextStateAfterMixed;

@end

@implementation SemiMixedButton
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
    return [SemiMixedButtonCell class];
}

- (void)setNextStateAfterMixed:(NSInteger)nextStateAfterMixed {
    [(SemiMixedButtonCell *)[self cell] setNextStateAfterMixed:nextStateAfterMixed];
}

- (NSInteger)nextStateAfterMixed {
    return [(SemiMixedButtonCell *)[self cell] nextStateAfterMixed];
}

@end

@implementation SemiMixedButtonCell
- (NSInteger)nextState {
    NSInteger state = self.state;
    if (state == NSMixedState) {
        state = self.nextStateAfterMixed;
    } else if (state == NSOnState) {
        state = NSOffState;
    } else {
        state = NSOnState;
    }
    return state;
}
@end
