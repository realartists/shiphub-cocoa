//
//  Logging.h
//  Ship
//
//  Created by James Howard on 5/21/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define ErrLog(format, ...) do { NSLog(@"ERROR: %s:%s:%d " format, __PRETTY_FUNCTION__, __FILE__, __LINE__, ##__VA_ARGS__); } while (0)
#define AlwaysLog(format, ...) do { NSLog(@"INFO: %s:%s:%d " format, __PRETTY_FUNCTION__, __FILE__, __LINE__, ##__VA_ARGS__); } while (0)

#if DEBUG
#define DebugLog(format, ...) do { NSLog(@"DEBUG: %s:%s:%d " format, __PRETTY_FUNCTION__, __FILE__, __LINE__, ##__VA_ARGS__); } while (0)
#define Trace() do { NSLog(@"TRACE: %s:%s:%d", __PRETTY_FUNCTION__, __FILE__, __LINE__); } while (0)
#define Backtrace() do { NSLog(@"TRACE: %@", [NSThread callStackSymbols]); } while (0)
#else
#define DebugLog(format, ...) do { } while (0)
#define Trace() do { } while (0)
#define Backtrace() do { } while (0)
#endif

