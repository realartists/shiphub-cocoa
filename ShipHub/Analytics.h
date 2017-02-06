#import <Foundation/Foundation.h>

@interface Analytics : NSObject

+ (instancetype)sharedInstance;

- (void)flush;
- (void)track:(NSString *)event;
- (void)track:(NSString *)event properties:(NSDictionary *)properties;

@end
