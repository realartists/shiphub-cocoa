//
//  AttachmentManager.h
//  ShipHub
//
//  Created by James Howard on 5/2/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AttachmentManager : NSObject

+ (instancetype)sharedManager;

- (void)uploadAttachment:(NSFileWrapper *)attachment completion:(void (^)(NSURL *destinationURL, NSError *error))completion;

@end

extern NSString *const AttachmentManagerErrorDomain;

typedef NS_ENUM(NSInteger, AttachmentManagerError) {
    AttachmentManagerErrorIO = 1,
    AttachmentManagerErrorFileTooBig = 2
};

@interface NSError (AttachmentManager)

+ (NSError *)attachmentManagerErrorWithCode:(AttachmentManagerError)code;
+ (NSError *)attachmentManagerErrorWithCode:(AttachmentManagerError)code userInfo:(NSDictionary *)userInfo;

@end
