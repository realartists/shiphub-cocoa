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

#import "DataStore.h"
#import "Auth.h"

const uint64_t MaxFileSize = 4 * 1024 * 1024;
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
    
    NSString *b64Str = [attachment.regularFileContents base64EncodedStringWithOptions:0];
    
    NSString *token = [[[DataStore activeStore] auth] ghToken];
    
    NSMutableDictionary *body = [NSMutableDictionary new];
    body[@"token"] = token;
    body[@"filename"] = attachment.preferredFilename ?: @"attachment";
    body[@"fileMime"] = attachment.mimeType;
    body[@"file"] = b64Str;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:UploadEndpoint]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.HTTPMethod = @"PUT";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        DebugLog(@"Received upload response %@", response);
        
        NSHTTPURLResponse *http = (id)response;
        
        if (!error && (http.statusCode < 200 || http.statusCode >= 400 || data == nil)) {
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
        
        completion(URL, error);
        
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
