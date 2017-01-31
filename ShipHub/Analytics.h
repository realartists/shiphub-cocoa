#import <Foundation/Foundation.h>

@interface Analytics : NSObject

@property NSString *shipHost;

+ (instancetype)sharedInstance;

- (void)flush;
- (void)setShipHost:(NSString *)host;
- (void)track:(NSString *)event;
- (void)track:(NSString *)event properties:(NSDictionary *)properties;

@end
