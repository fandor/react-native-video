#import "RCTVideoResourceLoaderDelegate.h"

static NSString *redirectScheme = @"rdtp";
static NSString *customPlaylistScheme = @"cplp";
static NSString *customKeyScheme = @"ckey";
static NSString *httpScheme = @"http";

static NSString *customPlayListFormatPrefix = @"#EXTM3U\n"
"#EXT-X-PLAYLIST-TYPE:EVENT\n"
"#EXT-X-TARGETDURATION:10\n"
"#EXT-X-VERSION:3\n"
"#EXT-X-MEDIA-SEQUENCE:0\n";

static NSString *customPlayListFormatElementInfo = @"#EXTINF:10, no desc\n";
static NSString *customPlaylistFormatElementSegment = @"%@/fileSequence%d.ts\n";

static NSString *customEncryptionKeyInfo = @"#EXT-X-KEY:METHOD=AES-128,URI=\"%@/crypt0.key\", IV=0x3ff5be47e1cdbaec0a81051bcc894d63\n";
static NSString *customPlayListFormatEnd = @"#EXT-X-ENDLIST";
static int redirectErrorCode = 302;
static int badRequestErrorCode = 400;



@interface RCTVideoResourceLoaderDelegate ()
- (BOOL) schemeSupported:(NSString*) scheme;
- (void) reportError:(AVAssetResourceLoadingRequest *) loadingRequest withErrorCode:(int) error;
@end


@interface RCTVideoResourceLoaderDelegate (Redirect)
- (BOOL) isRedirectSchemeValid:(NSString*) scheme;
- (BOOL) handleRedirectRequest:(AVAssetResourceLoadingRequest*) loadingRequest;
- (NSURLRequest* ) generateRedirectURL:(NSURLRequest *)sourceURL;
@end

@interface RCTVideoResourceLoaderDelegate (CustomPlaylist)
- (BOOL) isCustomPlaylistSchemeValid:(NSString*) scheme;
- (NSString*) getCustomPlaylist:(NSString *) urlPrefix andKeyPrefix:(NSString*) keyPrefix totalElements:(NSInteger) elements;
- (BOOL) handleCustomPlaylistRequest:(AVAssetResourceLoadingRequest*) loadingRequest;
@end

@interface RCTVideoResourceLoaderDelegate (CustomKey)
- (BOOL) isCustomKeySchemeValid:(NSString*) scheme;
- (NSData*) getKey:(NSURL*) url;
- (BOOL) handleCustomKeyRequest:(AVAssetResourceLoadingRequest*) loadingRequest;
@end

#pragma mark - RCTVideoResourceLoaderDelegate

@implementation RCTVideoResourceLoaderDelegate
/*!
 *  is scheme supported
 */
- (BOOL) schemeSupported:(NSString *)scheme
{
    if ( [self isRedirectSchemeValid:scheme] ||
        [self isCustomKeySchemeValid:scheme] ||
        [self isCustomPlaylistSchemeValid:scheme])
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
/*!
 *  AVARLDelegateDemo's implementation of the protocol.
 *  Check the given request for valid schemes:
 *
 * 1) Redirect 2) Custom Play list 3) Custom key
 */
- (BOOL) resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSLog(@"LOGGING");
    NSString* scheme = [[[loadingRequest request] URL] scheme];
    
    if ([self isRedirectSchemeValid:scheme])
        return [self handleRedirectRequest:loadingRequest];
    
    if ([self isCustomPlaylistSchemeValid:scheme]) {
        dispatch_async (dispatch_get_main_queue(),  ^ {
            [self handleCustomPlaylistRequest:loadingRequest];
        });
        return YES;
    }
    
    if ([self isCustomKeySchemeValid:scheme]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleCustomKeyRequest:loadingRequest];
        });
        return YES;
    }
    
    return NO;
}

@end

#pragma mark - RCTVideoResourceLoaderDelegate Redirect

@implementation RCTVideoResourceLoaderDelegate (Redirect)
/*!
 * Validates the given redirect schme.
 */
- (BOOL) isRedirectSchemeValid:(NSString *)scheme
{
    return ([redirectScheme isEqualToString:scheme]);
}

-(NSURLRequest* ) generateRedirectURL:(NSURLRequest *)sourceURL
{
    NSURLRequest *redirect = [NSURLRequest requestWithURL:[NSURL URLWithString:[[[sourceURL URL] absoluteString] stringByReplacingOccurrencesOfString:redirectScheme withString:httpScheme]]];
    return redirect;
}
/*!
 *  The delegate handler, handles the received request:
 *
 *  1) Verifies its a redirect request, otherwise report an error.
 *  2) Generates the new URL
 *  3) Create a reponse with the new URL and report success.
 */
- (BOOL) handleRedirectRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSURLRequest *redirect = nil;
    
    redirect = [self generateRedirectURL:(NSURLRequest *)[loadingRequest request]];
    if (redirect)
    {
        [loadingRequest setRedirect:redirect];
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[redirect URL] statusCode:redirectErrorCode HTTPVersion:nil headerFields:nil];
        [loadingRequest setResponse:response];
        [loadingRequest finishLoading];
    } else
    {
        [self reportError:loadingRequest withErrorCode:badRequestErrorCode];
    }
    return YES;
}

@end

#pragma mark - RCTVideoResourceLoaderDelegate CustomPlaylist

@implementation RCTVideoResourceLoaderDelegate (CustomPlaylist)

- (BOOL) isCustomPlaylistSchemeValid:(NSString *)scheme
{
    return ([customPlaylistScheme isEqualToString:scheme]);
}
/*!
 * create a play list based on the given prefix and total elements
 */
- (NSString*) getCustomPlaylist:(NSString *) urlPrefix andKeyPrefix:(NSString *) keyPrefix totalElements:(NSInteger) elements
{
    static NSMutableString  *customPlaylist = nil;
    
    if (customPlaylist)
        return customPlaylist;
    
    customPlaylist = [[NSMutableString alloc] init];
    [customPlaylist appendString:customPlayListFormatPrefix];
    for (int i = 0; i < elements; ++i)
    {
        [customPlaylist appendString:customPlayListFormatElementInfo];
        //We are using single key for all the segments but different IV, every 50 segments
        if (0 == i)
            [customPlaylist appendFormat:customEncryptionKeyInfo, keyPrefix];
        [customPlaylist appendFormat:customPlaylistFormatElementSegment, urlPrefix, i];
    }
    [customPlaylist appendString:customPlayListFormatEnd];
    return customPlaylist;
}
/*!
 *  Handles the custom play list scheme:
 *
 *  1) Verifies its a custom playlist request, otherwise report an error.
 *  2) Generates the play list.
 *  3) Create a reponse with the new URL and report success.
 */
- (BOOL) handleCustomPlaylistRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    //Prepare the playlist with redirect scheme.
    NSString *prefix = [[[[loadingRequest request] URL] absoluteString] stringByReplacingOccurrencesOfString:customPlaylistScheme withString:redirectScheme];// stringByDeletingLastPathComponent];
    NSRange range = [prefix rangeOfString:@"/" options:NSBackwardsSearch];
    prefix = [prefix substringToIndex:range.location];
    NSString *keyPrefix = [prefix stringByReplacingOccurrencesOfString:redirectScheme withString:customKeyScheme];
    NSData *data = [[self getCustomPlaylist:prefix andKeyPrefix:keyPrefix totalElements:150] dataUsingEncoding:NSUTF8StringEncoding];
    
    if (data)
    {
        [loadingRequest.dataRequest respondWithData:data];
        [loadingRequest finishLoading];
    } else
    {
        [self reportError:loadingRequest withErrorCode:badRequestErrorCode];
    }
    
    return YES;
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
/*!
 *  Handles the custom key scheme:
 *
 *  1) Verifies its a custom key request, otherwise report an error.
 *  2) Creates the URL for the key
 *  3) Create a response with the new URL and report success.
 */
- (BOOL) handleCustomKeyRequest:(AVAssetResourceLoadingRequest*) loadingRequest
{
    NSData* data = [self getKey:[[loadingRequest request] URL]];
    if (data)
    {
        [loadingRequest.dataRequest respondWithData:data];
        [loadingRequest finishLoading];
    } else
    {
        [self reportError:loadingRequest withErrorCode:badRequestErrorCode];
    }
    return YES;
    
}
@end
