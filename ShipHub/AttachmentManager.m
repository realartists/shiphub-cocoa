//
//  AttachmentManager.m
//  ShipHub
//
//  Created by James Howard on 5/2/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "AttachmentManager.h"

#import "Error.h"
#import "Extras.h"
#import "Auth.h"
#import "AppAdapter.h"

// small attachments we can base64 encode and upload all in one go.
// larger ones, we will ask for a signed S3 URL and upload to that.
const uint64_t MaxFileSize = 20 * 1024 * 1024;
const uint64_t MaxBase64FileSize = 10 * 1024;
static NSString *const UploadEndpoint = @"https://86qvuywske.execute-api.us-east-1.amazonaws.com/prod/shiphub-attachments";

@implementation AttachmentManager

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static AttachmentManager *man = nil;
    dispatch_once(&onceToken, ^{
        man = [AttachmentManager new];
    });
    return man;
}

- (void)tryZipAttachment:(NSFileWrapper *)attachment completion:(void (^)(NSURL *, NSError *))completion
{
#if !TARGET_OS_IPHONE
    // Zip it up.
    
    NSString *directoryFilename = attachment.filename;
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *tmpTemplate = [NSString stringWithFormat:@"%@%@XXXXXX", tmpDir, directoryFilename];
    
    char *templateChars = strdup([tmpTemplate UTF8String]);
    
#if __clang_analyzer__
    mkstemp(templateChars); // unfortunately, zip doesn't want to operate on an existing file, so we have to actually use mktemp
#else
    mktemp(templateChars);
#endif
    
    NSString *temporaryContainer = [NSString stringWithUTF8String:templateChars];
    NSString *temporaryPath = [temporaryContainer stringByAppendingPathComponent:directoryFilename];
    free(templateChars);
    
    NSString *zipFilename = [temporaryPath stringByAppendingPathExtension:@"zip"];
    
    dispatch_block_t cleanup = ^{
        [[NSFileManager defaultManager] removeItemAtPath:temporaryContainer error:NULL];
    };
    
    NSError *error = nil;
    
    [[NSFileManager defaultManager] createDirectoryAtPath:temporaryContainer withIntermediateDirectories:NO attributes:nil error:&error];
    
    if (error) {
        cleanup();
        completion(nil, error);
        return;
    }
    
    [attachment writeToURL:[NSURL fileURLWithPath:temporaryPath] options:0 originalContentsURL:nil error:&error];
    
    if (error) {
        cleanup();
        completion(nil, error);
        return;
    }
    
    NSTask *zipTask = [[NSTask alloc] init];
    zipTask.launchPath = @"/usr/bin/zip";
    zipTask.currentDirectoryPath = temporaryContainer;
    zipTask.arguments = @[@"-r", [zipFilename lastPathComponent], [temporaryPath lastPathComponent]];
    zipTask.qualityOfService = NSQualityOfServiceUserInitiated;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    zipTask.terminationHandler = ^(NSTask *t) {
        dispatch_semaphore_signal(sema);
    };
    
    [zipTask launch];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    if ([zipTask terminationStatus] != 0) {
        cleanup();
        ErrLog(@"zip terminated with status %d", [zipTask terminationStatus]);
        error = [NSError attachmentManagerErrorWithCode:AttachmentManagerErrorIO];
        completion(nil, error);
        return;
    }
    
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:zipFilename error:&error];
    
    if (error) {
        cleanup();
        ErrLog(@"Unable to stat path: %@", zipFilename);
        completion(nil, error);
        return;
    }
    
    if ([attrs[NSFileSize] unsignedLongLongValue] > MaxFileSize) {
        cleanup();
        completion(nil, [NSError attachmentManagerErrorWithCode:AttachmentManagerErrorFileTooBig]);
        return;
    }
    
    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:zipFilename] options:NSFileWrapperReadingImmediate error:&error];
    
    if (error) {
        cleanup();
        completion(nil, error);
        return;
    }
    
    wrapper.preferredFilename = [attachment.preferredFilename stringByAppendingPathExtension:@"zip"] ?: @"attachment.zip";
    
    cleanup();
    
    [self _uploadAttachment:wrapper completion:completion];
    
#else
    completion(nil, [NSError attachmentManagerErrorWithCode:AttachmentManagerErrorIO userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Attaching folders is not supported on iOS", nil)}]);
#endif
}

- (void)_uploadAttachment:(NSFileWrapper *)attachment completion:(void (^)(NSURL *, NSError *))completion
{
    if (attachment.isDirectory) {
        [self tryZipAttachment:attachment completion:completion];
        return;
    }
    
    NSDictionary *fileAttributes = attachment.fileAttributes;
    uint64_t fileSize = 0;
    if ([fileAttributes objectForKey:NSFileSize]) {
        fileSize = [fileAttributes fileSize];
    } else {
        // This can happen for certain pasted NSFileWrappers. We really do need to know the size.
        if (attachment.isRegularFile) {
            fileSize = [attachment.regularFileContents length];
        }
    }
    
    if (fileSize > MaxFileSize) {
        int maxMB = MaxFileSize / (1024 * 1024);
        NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"%@ is too big to upload. Maximum file upload size is %dMB.", nil), attachment.preferredFilename, maxMB];
        
        completion(nil, [NSError attachmentManagerErrorWithCode:AttachmentManagerErrorFileTooBig userInfo:@{NSLocalizedDescriptionKey : reason}]);
        return;
    }
    
    NSString *token = [[SharedAppAdapter() auth] ghToken];
    
    NSMutableDictionary *body = [NSMutableDictionary new];
    body[@"token"] = token;
    body[@"filename"] = attachment.preferredFilename ?: @"attachment";
    body[@"fileMime"] = attachment.mimeType;
    
    BOOL presign;
    if (fileSize <= MaxBase64FileSize) {
        presign = NO;
        NSString *b64Str = [attachment.regularFileContents base64EncodedStringWithOptions:0];
        body[@"file"] = b64Str;
    } else {
        presign = YES;
        body[@"presign"] = @YES;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:UploadEndpoint]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod = @"PUT";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        DebugLog(@"Received upload response %@", response);
        
        NSHTTPURLResponse *http = (id)response;
        
        if (!error && (![http isSuccessStatusCode] || data == nil)) {
            error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        
        NSDictionary *respDict = nil;
        if (!error) {
            NSError *err = nil;
            respDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
            if (err) {
                error = err;
            }
        }
        
        if (!error && ![respDict[@"url"] isKindOfClass:[NSString class]]) {
            error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        
        NSURL *URL = nil;
        if (!error) {
            URL = [NSURL URLWithString:respDict[@"url"]];
            if (!URL) {
                error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
        }
        
        if (!error && presign) {
            NSString *presignURLStr = respDict[@"upload"];
            NSURL *presignURL = nil;
            
            if (![presignURLStr isKindOfClass:[NSString class]]) {
                error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            
            if (!error) {
                presignURL = [NSURL URLWithString:presignURLStr];
                
                if (!presignURL) {
                    error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
                }
            }
            
            if (!error) {
                // actually perform the S3 upload
                DebugLog(@"Performing upload to S3 signed URL %@", presignURL);
                NSMutableURLRequest *s3Req = [NSMutableURLRequest requestWithURL:presignURL];
                NSDictionary *headers = @{ @"content-type" : attachment.mimeType,
                                           @"Content-Length" : [NSString stringWithFormat:@"%llu", fileSize] };
                s3Req.allHTTPHeaderFields = headers;
                s3Req.HTTPMethod = @"PUT";
                s3Req.HTTPBody = attachment.regularFileContents;
                [[[NSURLSession sharedSession] dataTaskWithRequest:s3Req completionHandler:^(NSData * _Nullable s3Data, NSURLResponse * _Nullable s3Response, NSError * _Nullable s3Error) {
                    
                    NSHTTPURLResponse *s3Http = (id)s3Response;
                    
#if DEBUG
                    if (data) {
                        NSString *dataStr = [[NSString alloc] initWithData:s3Data encoding:NSUTF8StringEncoding];
                        DebugLog(@"%@ %@", s3Http, dataStr);
                    }
#endif
                    
                    if ([s3Http isSuccessStatusCode] && !s3Error) {
                        completion(URL, nil);
                    } else {
                        if (!s3Error) {
                            s3Error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
                        }
                        completion(nil, s3Error);
                    }
                    
                }] resume];
            } else {
                completion(nil, error);
            }
            
        } else {
            completion(URL, error);
        }
    }] resume];
}

- (void)uploadAttachment:(NSFileWrapper *)attachment completion:(void (^)(NSURL *, NSError *))completion
{
    NSParameterAssert(attachment);
    NSParameterAssert(completion);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self _uploadAttachment:attachment completion:^(NSURL *URL, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(URL, err);
            });
        }];
    });
}

@end

NSString *const AttachmentManagerErrorDomain = @"AttachmentManager";

@implementation NSError (AttachmentManager)

static NSString *AttachmentManagerLocalizedDescriptionForErrorCode(AttachmentManagerError code)
{
    switch (code) {
        case AttachmentManagerErrorFileTooBig: {
            int maxMB = MaxFileSize / (1024 * 1024);
            NSString *reason = [NSString stringWithFormat:NSLocalizedString(@"Maximum file upload size is %dMB.", nil), maxMB];
            return reason;
        }
        case AttachmentManagerErrorIO: return NSLocalizedString(@"I/O Error", nil);
    }
}

+ (NSError *)attachmentManagerErrorWithCode:(AttachmentManagerError)code {
    return [self attachmentManagerErrorWithCode:code userInfo:nil];
}

+ (NSError *)attachmentManagerErrorWithCode:(AttachmentManagerError)code userInfo:(NSDictionary *)info {
    NSMutableDictionary *userInfo = info ? [info mutableCopy] : [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = userInfo[NSLocalizedDescriptionKey] ?: AttachmentManagerLocalizedDescriptionForErrorCode(code);
    return [NSError errorWithDomain:AttachmentManagerErrorDomain code:code userInfo:userInfo];
}

@end
