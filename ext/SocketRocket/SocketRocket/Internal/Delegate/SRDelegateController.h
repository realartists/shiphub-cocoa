//
// Copyright (c) 2016-present, Facebook, Inc.
// All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

#import <SocketRocket/SRWebSocket.h>

NS_ASSUME_NONNULL_BEGIN

struct SRDelegateAvailableMethods {
    unsigned int didReceiveMessage : 1;
    unsigned int didReceiveMessageWithString : 1;
    unsigned int didReceiveMessageWithData : 1;
    unsigned int didOpen : 1;
    unsigned int didFailWithError : 1;
    unsigned int didCloseWithCode : 1;
    unsigned int didReceivePing : 1;
    unsigned int didReceivePong : 1;
    unsigned int shouldConvertTextFrameToString : 1;
};
typedef struct SRDelegateAvailableMethods SRDelegateAvailableMethods;

typedef void(^SRDelegateBlock)(id<SRWebSocketDelegate> _Nullable delegate, SRDelegateAvailableMethods availableMethods);

@interface SRDelegateController : NSObject

@property (nonatomic, weak) id<SRWebSocketDelegate> delegate;
@property (atomic, readonly) SRDelegateAvailableMethods availableDelegateMethods;

@property (nullable, nonatomic, strong) dispatch_queue_t dispatchQueue;
@property (nullable, nonatomic, strong) NSOperationQueue *operationQueue;

///--------------------------------------
#pragma mark - Perform
///--------------------------------------

- (void)performDelegateBlock:(SRDelegateBlock)block;
- (void)performDelegateQueueBlock:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
