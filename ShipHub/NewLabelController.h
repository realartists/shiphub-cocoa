
#import <Cocoa/Cocoa.h>

@interface NewLabelController : NSWindowController

@property (nonatomic, readonly) NSDictionary *createdLabel;

- (instancetype)initWithPrefilledName:(NSString *)prefilledName
                            allLabels:(NSArray *)allLabels
                                owner:(NSString *)owner
                                 repo:(NSString *)repo;

@end
