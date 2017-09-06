#import "RCTVideoResourceLoaderDelegate.h"

static NSString *customKeyScheme = @"skd";
static NSString *httpScheme = @"https";

static NSString *certificateURL = @"https://fp-keyos.licensekeyserver.com/cert/05a33a58a0f40bc0ba0e037144dd8fc3.der";
static NSString *licenseURL = @"https://fp-keyos.licensekeyserver.com/getkey";

 static NSString *authXMLURL = @"https://staging.fandor.com/api/2/drm";
//static NSString *authXMLURL = @"https://www.fandor.com/api/2/drm";

static NSString *apiSecret = @"ezr2type4dev";
//static NSString *apiSecret = @""; // change to production secret from S3.

static int badRequestErrorCode = 400;

@interface RCTVideoResourceLoaderDelegate ()
{
    NSString* authXML;
}
- (BOOL) isSchemeSupported:(NSString*) scheme;
- (void) reportError:(AVAssetResourceLoadingRequest *) loadingRequest withErrorCode:(int) error;
@end

@interface RCTVideoResourceLoaderDelegate (CustomKey)
- (BOOL) isCustomKeySchemeValid:(NSString*) scheme;
- (NSData*) getKey:(NSURL*) url;
- (NSData*) getCertificate;

- (BOOL) handleCustomKeyRequest:(AVAssetResourceLoadingRequest*) loadingRequest;
@end

#pragma mark - RCTVideoResourceLoaderDelegate

@implementation RCTVideoResourceLoaderDelegate

- (BOOL) isSchemeSupported:(NSString *)scheme
{
  if ( [self isCustomKeySchemeValid:scheme] )
    return YES;
  
  return NO;
}

-(RCTVideoResourceLoaderDelegate *) init
{
    self = [super init];
    return self;
}

- (void) reportError:(AVAssetResourceLoadingRequest *) loadingRequest withErrorCode:(int) error
{
    [loadingRequest finishLoadingWithError:[NSError errorWithDomain: NSURLErrorDomain code:error userInfo: nil]];
}

- (BOOL) resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSLog(@"%@ was called in AssetLoaderDelegate with loadingRequest: %@", NSStringFromSelector(_cmd), [[loadingRequest request] URL]);
  
    NSString* scheme = [[[loadingRequest request] URL] scheme];
  
    if ([customKeyScheme isEqualToString:scheme]) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self handleCustomKeyRequest:loadingRequest];
        });
        return YES;
    }
    
    return NO;
}

@end

#pragma mark - RCTVideoResourceLoaderDelegate CustomKey

@implementation RCTVideoResourceLoaderDelegate (CustomKey)
- (BOOL) isCustomKeySchemeValid:(NSString*) scheme
{
    return ([customKeyScheme isEqualToString:scheme]);
}

- (NSData*) getKey:(NSURL*) url
{
    NSURL *newURL = [NSURL URLWithString:[[url absoluteString] stringByReplacingOccurrencesOfString:customKeyScheme withString:httpScheme]];
    return [[NSData alloc] initWithContentsOfURL:newURL];
}

- (NSData*) getCertificate
{
    return [[NSData alloc] initWithContentsOfURL: [NSURL URLWithString: certificateURL]];

}

-(BOOL) getAuthXML:(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL: [NSURL URLWithString: authXMLURL]];
    [request setHTTPMethod: @"GET"];
    [request setValue:[NSString stringWithFormat: @"Fandor Handshake=%@", apiSecret] forHTTPHeaderField:@"Authorization"];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    [[session dataTaskWithRequest:request completionHandler:handler] resume];
    
    
    return YES;
}

- (BOOL) getLicense:(NSData*) requestBody :(void (^)(NSData *data, NSURLResponse *response, NSError *error))handler
{
    // [[NSString alloc] initWithData: spc ] encoding:NSUTF8StringEncoding]]
    // Make request to keyos for contentKey and set it.
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL: [NSURL URLWithString:@"https://fp-keyos.licensekeyserver.com/getkey"]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody: requestBody];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setValue:authXML forHTTPHeaderField:@"customdata"];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

    
    [[session dataTaskWithRequest:request completionHandler:handler] resume];
    
    return YES;
}

- (BOOL) handleCustomKeyRequest:(AVAssetResourceLoadingRequest*) loadingRequest
{
    [self getAuthXML:^(NSData *data, NSURLResponse *response, NSError *error){
        authXML = [data base64EncodedStringWithOptions:0];
       
        NSString* host = [[[loadingRequest request] URL] host];
        NSData* contentID = [NSData dataWithBytes: [host cStringUsingEncoding: NSUTF8StringEncoding]
                                           length: [host lengthOfBytesUsingEncoding: NSUTF8StringEncoding]];
        NSData* certificate = [self getCertificate];
        
        NSError* spcError;
        NSData* spcData = [loadingRequest streamingContentKeyRequestDataForApp: certificate
                                                             contentIdentifier: contentID
                                                                       options: 0
                                                                         error: &spcError];
        NSString* base64SPCString = [spcData base64EncodedStringWithOptions:0];
        
        
        // create a url string: spc=spcData&assetId=assetIdData
        NSString* requestBody = [NSString stringWithFormat:@"spc=%@&assetId=%@", base64SPCString, host];

        [self getLicense:[requestBody dataUsingEncoding:NSUTF8StringEncoding] :^(NSData *data, NSURLResponse *response, NSError *error) {
            
            NSString* base64String = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:base64String options:0];
            
            if (data)
            {
                [loadingRequest.dataRequest respondWithData: decodedData];
                
                [loadingRequest finishLoading];
            } else
            {
                [self reportError:loadingRequest withErrorCode:badRequestErrorCode];
            }
        }];
    }];
    
    return YES;
}
@end
