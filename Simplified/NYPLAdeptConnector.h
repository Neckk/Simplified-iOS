#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wauto-import"

#import <Foundation/Foundation.h>

#pragma clang diagnostic pop

@class NYPLAdeptConnector;

@protocol NYPLAdeptConnectorDelegate

- (void)adeptConnector:(NYPLAdeptConnector *)adeptConnector
didFinishDownloadingToURL:(NSURL *)URL
            rightsData:(NSData *)rightsData
                   tag:(NSString *)tag;

- (void)adeptConnector:(NYPLAdeptConnector *)adeptConnector
     didUpdateProgress:(double)progress
                   tag:(NSString *)tag;

@end

@interface NYPLAdeptConnector : NSObject

@property (atomic, weak) id<NYPLAdeptConnectorDelegate> delegate;
@property (atomic, readonly) BOOL deviceAuthorized;
@property (atomic, readonly) BOOL workflowsInProgress;

+ (NYPLAdeptConnector *)sharedAdeptConnector;

// This can only be called if no workflows are in progress and the device is not authorized. The
// authorization attempt is handled asynchronously and its success or failure is reported to the
// delegate.
- (void)authorizeWithVendorID:(NSString *)vendorID
                     username:(NSString *)username
                     password:(NSString *)password;

// This can only be called if no workflows are in progress. The device is deauthorized when this
// method returns.
- (void)deauthorize;

// Fulfillment requests will be ignored if the device is not presently authorized. The fulfillment
// attempt is handled asynchronously and its status is reported to the delegate.
- (void)fulfillWithACSMData:(NSData *)ACSMData tag:(NSString *)tag;

@end
