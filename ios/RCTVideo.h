#import "RCTView.h"
#import <AVFoundation/AVFoundation.h>
#import <AVFoundation/AVAssetResourceLoader.h>
#import "AVKit/AVKit.h"
#import "UIView+FindUIViewController.h"
#import "RCTVideoPlayerViewController.h"
#import "RCTVideoPlayerViewControllerDelegate.h"

@class RCTEventDispatcher;

@interface RCTVideo : UIView <RCTVideoPlayerViewControllerDelegate, AVAssetResourceLoaderDelegate>

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher NS_DESIGNATED_INITIALIZER;

- (AVPlayerViewController*)createPlayerViewController:(AVPlayer*)player withPlayerItem:(AVPlayerItem*)playerItem;

@end
