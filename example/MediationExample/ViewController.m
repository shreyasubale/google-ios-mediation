//
// Copyright (C) 2015 Google, Inc.
//
// ViewController.m
// Mediation Example
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "ViewController.h"

#import <GoogleMobileAds/GoogleMobileAds.h>
#import <SampleAdSDK/SampleAdSDK.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

#import "ExampleNativeAdView.h"
// Import MRAID custom event
#import "../CustomEvent/MRAIDCustomEvent.h"
#import "../CustomEvent/MRAIDCustomEventInterstitial.h"

@interface ViewController () <GADFullScreenContentDelegate,
                              GADNativeAdLoaderDelegate,
                              WKNavigationDelegate,
                              WKScriptMessageHandler>

@property(nonatomic, strong) AdSourceConfig *config;

@property(nonatomic, weak) IBOutlet GADBannerView *bannerAdView;

@property(nonatomic, weak) IBOutlet UIButton *interstitialButton;

@property(nonatomic, weak) IBOutlet UIButton *rewardedButton;

@property(nonatomic, weak) IBOutlet UIView *nativeAdPlaceholder;

@property(nonatomic, strong) GADInterstitialAd *interstitial;

@property(nonatomic, strong) GADRewardedAd *rewardedAd;

@property(nonatomic, strong) MRAIDCustomEventInterstitial *mraidInterstitial;

/// You must keep a strong reference to the GADAdLoader during the ad loading process.
@property(nonatomic, strong) GADAdLoader *adLoader;

/// Shows the most recently loaded interstitial in response to a button tap.
- (IBAction)showInterstitial:(UIButton *)sender;

- (IBAction)showRewarded:(UIButton *)sender;

@end

@implementation ViewController

+ (instancetype)controllerWithAdSourceConfig:(AdSourceConfig *)adSourceConfig {
  ViewController *controller = [[UIStoryboard storyboardWithName:@"Main" bundle:nil]
      instantiateViewControllerWithIdentifier:@"ViewController"];
  controller.config = adSourceConfig;
  return controller;
}

- (IBAction)refreshNativeAd:(id)sender {
  GADNativeAdViewAdOptions *adViewOptions = [[GADNativeAdViewAdOptions alloc] init];
  adViewOptions.preferredAdChoicesPosition = GADAdChoicesPositionTopRightCorner;

  self.adLoader = [[GADAdLoader alloc] initWithAdUnitID:self.config.nativeAdUnitID
                                     rootViewController:self
                                                adTypes:@[ GADAdLoaderAdTypeNative ]
                                                options:@[ adViewOptions ]];
  self.adLoader.delegate = self;
  [self.adLoader loadRequest:[GADRequest request]];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = self.config.title;

  self.bannerAdView.adUnitID = self.config.bannerAdUnitID;
  self.bannerAdView.rootViewController = self;
  [self.bannerAdView loadRequest:[GADRequest request]];

  [self requestInterstitial];
  [self requestRewarded];
  [self refreshNativeAd:nil];
}

- (void)requestInterstitial {
  [GADInterstitialAd loadWithAdUnitID:self.config.interstitialAdUnitID
                              request:[GADRequest request]
                    completionHandler:^(GADInterstitialAd *ad, NSError *error) {
    if (error) {
      NSLog(@"Failed to load an interstitial ad with error: %@", error.localizedDescription);
      return;
    }
    self.interstitial = ad;
    self.interstitial.fullScreenContentDelegate = self;
  }];
}

- (IBAction)showInterstitial:(UIButton *)sender {
  // If using MRAID custom event, test MRAID directly
  if (self.config.adSourceType == AdSourceTypeMRAIDCustomEvent) {
    [self showMRAIDInterstitial];
    return;
  }
  
  if (self.interstitial) {
    [self.interstitial presentFromRootViewController:self];
  } else {
    NSLog(@"Ad wasn't ready");
    [self requestInterstitial];
  }
}

- (void)requestRewarded {
  GADRequest *request = [GADRequest request];
  [GADRewardedAd
   loadWithAdUnitID:self.config.rewardedAdUnitID
   request:request
   completionHandler:^(GADRewardedAd *ad, NSError *error) {
    if (error) {
      // Handle ad failed to load case.
      NSLog(@"Rewarded ad failed to load with error: %@", error.localizedDescription);
      return;
    }
    // Ad successfully loaded.
    NSLog(@"Rewarded ad loaded.");
    self.rewardedAd = ad;
    self.rewardedAd.fullScreenContentDelegate = self;
  }];
}

- (IBAction)showRewarded:(UIButton *)sender {
  if (self.rewardedAd) {
    [self.rewardedAd presentFromRootViewController:self
                          userDidEarnRewardHandler:^{
      GADAdReward *reward = self.rewardedAd.adReward;
      NSString *rewardMessage =
          [NSString stringWithFormat:@"Reward received with currency %@ , amount %lf", reward.type,
                                     [reward.amount doubleValue]];
      NSLog(@"%@", rewardMessage);
    }];
  } else {
    NSLog(@"Ad wasn't ready");
    [self requestRewarded];
  }
}

- (void)replaceNativeAdView:(UIView *)nativeAdView inPlaceholder:(UIView *)placeholder {
  // Remove anything currently in the placeholder.
  NSArray *currentSubviews = [placeholder.subviews copy];
  for (UIView *subview in currentSubviews) {
    [subview removeFromSuperview];
  }

  if (!nativeAdView) {
    return;
  }

  // Add new ad view and set constraints to fill its container.
  [placeholder addSubview:nativeAdView];
  nativeAdView.translatesAutoresizingMaskIntoConstraints = NO;

  NSDictionary *viewDictionary = NSDictionaryOfVariableBindings(nativeAdView);
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[nativeAdView]|"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:viewDictionary]];
  [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[nativeAdView]|"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:viewDictionary]];
}

- (NSString *)getFullScreenAdType:(nonnull id<GADFullScreenPresentingAd>)ad {
  if ([ad isKindOfClass:[GADInterstitialAd class]]) {
    return @"Interstitial ad";
  }
  if ([ad isKindOfClass:[GADRewardedAd class]]) {
    return @"Rewarded ad";
  }
  return @"Full screen ad";
}

#pragma mark GADFullScreenContentDelegate implementation

- (void)ad:(nonnull id<GADFullScreenPresentingAd>)ad
didFailToPresentFullScreenContentWithError:(nonnull NSError *)error {
  NSString *fullScreenAdType = [self getFullScreenAdType:ad];
  NSLog(@"%@ failed to present full screen content with error: %@.",
        fullScreenAdType,
        error.localizedDescription);
}

/// Tells the delegate that the ad presented full screen content.
- (void)adDidPresentFullScreenContent:(nonnull id<GADFullScreenPresentingAd>)ad {
  NSString *fullScreenAdType = [self getFullScreenAdType:ad];
  NSLog(@"%@ did present full screen content.", fullScreenAdType);
}

/// Tells the delegate that the ad dismissed full screen content.
- (void)adDidDismissFullScreenContent:(nonnull id<GADFullScreenPresentingAd>)ad {
  NSString *fullScreenAdType = [self getFullScreenAdType:ad];
  NSLog(@"%@ did dismiss full screen content.", fullScreenAdType);
}

#pragma mark GADAdLoaderDelegate implementation

- (void)adLoader:(GADAdLoader *)adLoader didFailToReceiveAdWithError:(NSError *)error {
  NSLog(@"%@ failed with error: %@", adLoader, error.localizedDescription);
}

#pragma mark Utility Method

/// Gets an image representing the number of stars. Returns nil if rating is less than 3.5 stars.
- (UIImage *)imageForStars:(NSDecimalNumber *)numberOfStars {
  double starRating = numberOfStars.doubleValue;
  if (starRating >= 5) {
    return [UIImage imageNamed:@"stars_5"];
  } else if (starRating >= 4.5) {
    return [UIImage imageNamed:@"stars_4_5"];
  } else if (starRating >= 4) {
    return [UIImage imageNamed:@"stars_4"];
  } else if (starRating >= 3.5) {
    return [UIImage imageNamed:@"stars_3_5"];
  } else {
    return nil;
  }
}

#pragma mark GADNativeAdLoaderDelegate implementation

- (void)adLoader:(GADAdLoader *)adLoader didReceiveNativeAd:(GADNativeAd *)nativeAd {
  NSLog(@"%s, %@", __PRETTY_FUNCTION__, nativeAd);

  // Create and place ad in view hierarchy.
  ExampleNativeAdView *nativeAdView =
      [[NSBundle mainBundle] loadNibNamed:@"ExampleNativeAdView" owner:nil options:nil]
          .firstObject;

  nativeAdView.nativeAd = nativeAd;
  UIView *placeholder = self.nativeAdPlaceholder;
  ;
  NSString *awesomenessKey = self.config.awesomenessKey;

  [self replaceNativeAdView:nativeAdView inPlaceholder:placeholder];

  nativeAdView.mediaView.contentMode = UIViewContentModeScaleAspectFit;
  nativeAdView.mediaView.hidden = NO;
  [nativeAdView.mediaView setMediaContent:nativeAd.mediaContent];
  // Populate the native ad view with the native ad assets.
  // Some assets are guaranteed to be present in every native ad.
  ((UILabel *)nativeAdView.headlineView).text = nativeAd.headline;
  ((UILabel *)nativeAdView.bodyView).text = nativeAd.body;
  [((UIButton *)nativeAdView.callToActionView) setTitle:nativeAd.callToAction
                                               forState:UIControlStateNormal];

  // These assets are not guaranteed to be present, and should be checked first.
  ((UIImageView *)nativeAdView.iconView).image = nativeAd.icon.image;
  if (nativeAd.icon != nil) {
    nativeAdView.iconView.hidden = NO;
  } else {
    nativeAdView.iconView.hidden = YES;
  }
  ((UIImageView *)nativeAdView.starRatingView).image = [self imageForStars:nativeAd.starRating];
  if (nativeAd.starRating) {
    nativeAdView.starRatingView.hidden = NO;
  } else {
    nativeAdView.starRatingView.hidden = YES;
  }

  ((UILabel *)nativeAdView.storeView).text = nativeAd.store;
  if (nativeAd.store) {
    nativeAdView.storeView.hidden = NO;
  } else {
    nativeAdView.storeView.hidden = YES;
  }

  ((UILabel *)nativeAdView.priceView).text = nativeAd.price;
  if (nativeAd.price) {
    nativeAdView.priceView.hidden = NO;
  } else {
    nativeAdView.priceView.hidden = YES;
  }

  ((UILabel *)nativeAdView.advertiserView).text = nativeAd.advertiser;
  if (nativeAd.advertiser) {
    nativeAdView.advertiserView.hidden = NO;
  } else {
    nativeAdView.advertiserView.hidden = YES;
  }

  // If the ad came from the Sample SDK, it should contain an extra asset, which is retrieved here.
  NSString *degreeOfAwesomeness = nativeAd.extraAssets[awesomenessKey];

  if (degreeOfAwesomeness) {
    nativeAdView.degreeOfAwesomenessView.text = degreeOfAwesomeness;
    nativeAdView.degreeOfAwesomenessView.hidden = NO;
  } else {
    nativeAdView.degreeOfAwesomenessView.hidden = YES;
  }

  // In order for the SDK to process touch events properly, user interaction should be disabled.
  nativeAdView.callToActionView.userInteractionEnabled = NO;
}

#pragma mark - MRAID Testing

- (void)showMRAIDInterstitial {
  NSLog(@"Showing MRAID interstitial - bypassing mediation for testing");
  
  // Set the MRAID ad URL - using localhost for testing
  NSString *mraidURL = @"http://localhost:8080/MRAIDTestAd.html";
  
  // Directly show MRAID WebView for testing
  [self showDirectMRAIDWebView:mraidURL];
}

- (void)showDirectMRAIDWebView:(NSString *)urlString {
  NSLog(@"Showing MRAID WebView directly");
  
  // Create WebView configuration with MRAID support
  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  
  // Add MRAID JavaScript bridge
  WKUserContentController *contentController = [[WKUserContentController alloc] init];
  [contentController addScriptMessageHandler:self name:@"mraid"];
  
  // Inject MRAID JavaScript
  NSString *mraidJS = [self getMRAIDJavaScript];
  WKUserScript *mraidScript = [[WKUserScript alloc] initWithSource:mraidJS
                                                     injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                  forMainFrameOnly:YES];
  [contentController addUserScript:mraidScript];
  
  config.userContentController = contentController;
  config.allowsInlineMediaPlayback = YES;
  config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
  
  // Create WebView
  WKWebView *webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
  webView.navigationDelegate = self;
  
  // Create full-screen presentation controller
  UIViewController *presentationController = [[UIViewController alloc] init];
  presentationController.modalPresentationStyle = UIModalPresentationFullScreen;
  
  // Setup WebView for full-screen display
  webView.frame = presentationController.view.bounds;
  webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [presentationController.view addSubview:webView];
  
  // Add close button
  UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [closeButton setTitle:@"✕" forState:UIControlStateNormal];
  closeButton.frame = CGRectMake(20, 44, 44, 44);
  closeButton.titleLabel.font = [UIFont systemFontOfSize:24];
  [closeButton addTarget:self action:@selector(closeMRAIDWebView:) forControlEvents:UIControlEventTouchUpInside];
  [presentationController.view addSubview:closeButton];
  
  // Store reference for closing
  objc_setAssociatedObject(closeButton, "webViewController", presentationController, OBJC_ASSOCIATION_RETAIN);
  
  // Load the MRAID ad
  NSURL *url = [NSURL URLWithString:urlString];
  if (url) {
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [webView loadRequest:request];
    
    // Present the ad
    [self presentViewController:presentationController animated:YES completion:^{
      NSLog(@"MRAID WebView presented");
    }];
  } else {
    NSLog(@"Invalid MRAID URL: %@", urlString);
  }
}

- (void)closeMRAIDWebView:(UIButton *)sender {
  UIViewController *presentationController = objc_getAssociatedObject(sender, "webViewController");
  if (presentationController) {
    [presentationController dismissViewControllerAnimated:YES completion:^{
      NSLog(@"MRAID WebView dismissed");
    }];
  }
}

- (NSString *)getMRAIDJavaScript {
  // Same MRAID JavaScript as in MRAIDCustomEventInterstitial.m
  return @"var mraid = (function() {\n"
         @"  var state = 'loading';\n"
         @"  var isViewable = false;\n"
         @"  var listeners = {};\n"
         @"\n"
         @"  function callListeners(event, data) {\n"
         @"    if (listeners[event]) {\n"
         @"      listeners[event].forEach(function(listener) {\n"
         @"        listener(data);\n"
         @"      });\n"
         @"    }\n"
         @"  }\n"
         @"\n"
         @"  return {\n"
         @"    getVersion: function() { return '3.0'; },\n"
         @"    getState: function() { return state; },\n"
         @"    isViewable: function() { return isViewable; },\n"
         @"    \n"
         @"    addEventListener: function(event, listener) {\n"
         @"      if (!listeners[event]) listeners[event] = [];\n"
         @"      listeners[event].push(listener);\n"
         @"    },\n"
         @"    \n"
         @"    removeEventListener: function(event, listener) {\n"
         @"      if (listeners[event]) {\n"
         @"        var index = listeners[event].indexOf(listener);\n"
         @"        if (index > -1) listeners[event].splice(index, 1);\n"
         @"      }\n"
         @"    },\n"
         @"    \n"
         @"    close: function() {\n"
         @"      window.webkit.messageHandlers.mraid.postMessage({action: 'close'});\n"
         @"    },\n"
         @"    \n"
         @"    open: function(url) {\n"
         @"      window.webkit.messageHandlers.mraid.postMessage({action: 'open', url: url});\n"
         @"    },\n"
         @"    \n"
         @"    getScreenSize: function() {\n"
         @"      return { width: window.screen.width, height: window.screen.height };\n"
         @"    },\n"
         @"    \n"
         @"    getMaxSize: function() {\n"
         @"      return { width: window.innerWidth, height: window.innerHeight };\n"
         @"    },\n"
         @"    \n"
         @"    getCurrentPosition: function() {\n"
         @"      return { x: 0, y: 0, width: window.innerWidth, height: window.innerHeight };\n"
         @"    },\n"
         @"    \n"
         @"    _setState: function(newState) {\n"
         @"      if (state !== newState) {\n"
         @"        state = newState;\n"
         @"        callListeners('stateChange', state);\n"
         @"      }\n"
         @"    },\n"
         @"    \n"
         @"    _setIsViewable: function(viewable) {\n"
         @"      if (isViewable !== viewable) {\n"
         @"        isViewable = viewable;\n"
         @"        callListeners('viewableChange', isViewable);\n"
         @"      }\n"
         @"    },\n"
         @"    \n"
         @"    _fireReady: function() {\n"
         @"      callListeners('ready');\n"
         @"    }\n"
         @"  };\n"
         @"})();\n"
         @"\n"
         @"if (document.readyState === 'loading') {\n"
         @"  document.addEventListener('DOMContentLoaded', function() {\n"
         @"    mraid._setState('expanded');\n"
         @"    mraid._setIsViewable(true);\n"
         @"    mraid._fireReady();\n"
         @"  });\n"
         @"} else {\n"
         @"  setTimeout(function() {\n"
         @"    mraid._setState('expanded');\n"
         @"    mraid._setIsViewable(true);\n"
         @"    mraid._fireReady();\n"
         @"  }, 1);\n"
                   @"}\n";
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  NSLog(@"MRAID WebView finished loading");
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  NSLog(@"MRAID WebView failed to load: %@", error.localizedDescription);
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
  if ([message.name isEqualToString:@"mraid"]) {
    NSDictionary *data = message.body;
    NSString *action = data[@"action"];
    
    NSLog(@"MRAID action received: %@", action);
    
    if ([action isEqualToString:@"close"]) {
      // Find and dismiss the presented MRAID controller
      if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:^{
          NSLog(@"MRAID ad closed via JavaScript");
        }];
      }
    } else if ([action isEqualToString:@"open"]) {
      NSString *urlString = data[@"url"];
      if (urlString) {
        NSURL *url = [NSURL URLWithString:urlString];
        if (url) {
          NSLog(@"MRAID opening URL: %@", urlString);
          [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
      }
    }
  }
}

@end
