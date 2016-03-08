//
//  NSURLSession+PinnedSession.m
//  ShipHub
//
//  Created by James Howard on 3/7/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "NSURLSession+PinnedSession.h"

@interface SessionPinner : NSObject <NSURLSessionDelegate>

@end

@implementation NSURLSession (PinnedSession)

+ (NSURLSession *)pinnedSession {
    static NSURLSession *pinned;
    static SessionPinner *pinner;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pinner = [SessionPinner new];
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        pinned = [NSURLSession sessionWithConfiguration:config delegate:pinner delegateQueue:nil];
    });
    return pinned;
}

@end

@implementation SessionPinner

#if 0
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {

    NSString *host = [[challenge protectionSpace] host];
    if ([[[challenge protectionSpace] authenticationMethod] isEqualToString: NSURLAuthenticationMethodServerTrust]
        && [host hasSuffix:@"github.com"])
    {
        SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
        SecTrustSetAnchorCertificates(<#SecTrustRef  _Nonnull trust#>, <#CFArrayRef  _Nonnull anchorCertificates#>)
        OSStatus err = SecTrustEvaluate(serverTrust, NULL);
        if (err != S_OK) {
            completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace,nil);
        } else {
        }
        
        NSData *localCertificateData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle]
                                                                        pathForResource: SSL_CERT_NAME
                                                                        ofType: @"crt"]];
        SecCertificateRef remoteVersionOfServerCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0);
        CFDataRef remoteCertificateData = SecCertificateCopyData(remoteVersionOfServerCertificate);
        BOOL certificatesAreTheSame = [localCertificateData isEqualToData: (__bridge NSData *)remoteCertificateData];
        CFRelease(remoteCertificateData);
        NSURLCredential* cred  = [NSURLCredential credentialForTrust: serverTrust];
#ifdef DEBUG
        certificatesAreTheSame = YES;
#endif
        
        if (certificatesAreTheSame) {
            completionHandler(NSURLSessionAuthChallengeUseCredential,cred);		}
        else {
            completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace,nil);
            [self.delegate connectionFailure:ServerConnectionManagerStatusWrongSSLCert];
        }
        
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
    
}
#endif

@end
