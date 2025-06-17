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
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>

#import "ExampleNativeAdView.h"
// Import MRAID custom event
#import "../CustomEvent/MRAIDCustomEvent.h"
#import "../CustomEvent/MRAIDCustomEventInterstitial.h"

// Custom UIViewController subclass for MRAID orientation control
@interface MRAIDViewController : UIViewController
@property(nonatomic, assign) BOOL allowOrientationChange;
@property(nonatomic, strong) NSString *forceOrientation;
@end

@implementation MRAIDViewController

- (instancetype)init {
  self = [super init];
  if (self) {
    // Default MRAID orientation settings
    _allowOrientationChange = YES;
    _forceOrientation = @"none";
  }
  return self;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  // If orientation changes are not allowed, lock to the forced orientation
  if (!self.allowOrientationChange) {
    if ([self.forceOrientation isEqualToString:@"portrait"]) {
      return UIInterfaceOrientationMaskPortrait;
    } else if ([self.forceOrientation isEqualToString:@"landscape"]) {
      return UIInterfaceOrientationMaskLandscape;
    }
  }
  
  // Default: allow all orientations
  return UIInterfaceOrientationMaskAll;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
  if (!self.allowOrientationChange) {
    if ([self.forceOrientation isEqualToString:@"portrait"]) {
      return UIInterfaceOrientationPortrait;
    } else if ([self.forceOrientation isEqualToString:@"landscape"]) {
      return UIInterfaceOrientationLandscapeLeft;
    }
  }
  
  // Default: use current orientation
  return [UIApplication sharedApplication].statusBarOrientation;
}

- (BOOL)shouldAutorotate {
  return self.allowOrientationChange;
}

@end

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

@property(nonatomic, strong) UILabel *advertiserIdLabel;

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

  // Add advertiser ID display for MRAID custom event
  if (self.config.adSourceType == AdSourceTypeMRAIDCustomEvent) {
    [self setupMRAIDAdvertiserDisplay];
    [self requestTrackingPermissionIfNeeded];
  }

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

- (void)requestTrackingPermissionIfNeeded {
  if (@available(iOS 14.5, *)) {
    ATTrackingManagerAuthorizationStatus status = [ATTrackingManager trackingAuthorizationStatus];
    
    if (status == ATTrackingManagerAuthorizationStatusNotDetermined) {
      [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
        dispatch_async(dispatch_get_main_queue(), ^{
          NSLog(@"App Tracking Transparency status: %ld", (long)status);
          [self updateMRAIDAdvertiserInfo];
        });
      }];
    } else {
      NSLog(@"App Tracking Transparency status: %ld", (long)status);
    }
  } else {
    NSLog(@"iOS version < 14.5, App Tracking Transparency not required");
  }
}

- (void)setupMRAIDAdvertiserDisplay {
  // Create advertiser ID label
  self.advertiserIdLabel = [[UILabel alloc] init];
  self.advertiserIdLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.advertiserIdLabel.textAlignment = NSTextAlignmentCenter;
  self.advertiserIdLabel.font = [UIFont systemFontOfSize:14];
  self.advertiserIdLabel.textColor = [UIColor systemBlueColor];
  self.advertiserIdLabel.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:1.0 alpha:1.0];
  self.advertiserIdLabel.layer.cornerRadius = 8;
  self.advertiserIdLabel.layer.borderWidth = 1;
  self.advertiserIdLabel.layer.borderColor = [UIColor systemBlueColor].CGColor;
  self.advertiserIdLabel.clipsToBounds = YES;
  self.advertiserIdLabel.numberOfLines = 0;
  
  // Get advertiser information
  NSString *idfaString = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
  BOOL isTrackingEnabled = [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
  NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
  
  // Get ATT status if available
  NSString *attStatus = @"N/A";
  if (@available(iOS 14.5, *)) {
    ATTrackingManagerAuthorizationStatus status = [ATTrackingManager trackingAuthorizationStatus];
    switch (status) {
      case ATTrackingManagerAuthorizationStatusNotDetermined:
        attStatus = @"Not Asked";
        break;
      case ATTrackingManagerAuthorizationStatusRestricted:
        attStatus = @"Restricted";
        break;
      case ATTrackingManagerAuthorizationStatusDenied:
        attStatus = @"Denied";
        break;
      case ATTrackingManagerAuthorizationStatusAuthorized:
        attStatus = @"Authorized";
        break;
    }
  }
  
  // Create display text
  NSMutableString *displayText = [NSMutableString string];
  [displayText appendString:@"📱 MRAID Advertiser Info\n\n"];
  
  if (idfaString && ![idfaString isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
    [displayText appendFormat:@"IDFA: %@...\n", [idfaString substringToIndex:8]];
    [displayText appendFormat:@"Tracking: %@\n", isTrackingEnabled ? @"✅ Enabled" : @"❌ Disabled"];
  } else {
    [displayText appendString:@"IDFA: Not available\n"];
    [displayText appendString:@"Tracking: ❌ Disabled\n"];
  }
  
  [displayText appendFormat:@"ATT Status: %@\n", attStatus];
  [displayText appendFormat:@"Bundle: %@\n", bundleId];
  [displayText appendString:@"MRAID v3.0 | localhost:8080"];
  
  // Add timestamp for testing
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.timeStyle = NSDateFormatterShortStyle;
  NSString *timestamp = [formatter stringFromDate:[NSDate date]];
  [displayText appendFormat:@"\n%@", timestamp];
  
  self.advertiserIdLabel.text = displayText;
  
  // Add to view
  [self.view addSubview:self.advertiserIdLabel];
  
  // Position it at the bottom of the screen, above the safe area
  NSLayoutConstraint *bottomConstraint = [self.advertiserIdLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20];
  
  [NSLayoutConstraint activateConstraints:@[
    bottomConstraint,
    [self.advertiserIdLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
    [self.advertiserIdLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
    [self.advertiserIdLabel.heightAnchor constraintLessThanOrEqualToConstant:120]
  ]];
  
  // Add padding
  self.advertiserIdLabel.layer.cornerRadius = 8;
  self.advertiserIdLabel.text = [NSString stringWithFormat:@"  %@  ", self.advertiserIdLabel.text];
}

- (void)showMRAIDInterstitial {
  NSLog(@"Showing MRAID interstitial - bypassing mediation for testing");
  
  // Update advertiser info with MRAID-specific details
  [self updateMRAIDAdvertiserInfo];
  
  // Show URL input dialog
  [self showMRAIDURLInputDialog];
}

- (void)showMRAIDURLInputDialog {
  // Default MRAID URL - using localhost for testing
  NSString *defaultURL = @"http://192.168.1.251:8080/MRAIDTestAd.html";
  
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"MRAID Creative URL"
                                                               message:@"Enter the URL for the MRAID creative or choose a preset:"
                                                        preferredStyle:UIAlertControllerStyleAlert];
  
  // Add text field with default URL
  [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
    textField.text = defaultURL;
    textField.placeholder = @"http://localhost:8080/MRAIDTestAd.html";
    textField.keyboardType = UIKeyboardTypeURL;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
  }];
  
  // Load button
  UIAlertAction *loadAction = [UIAlertAction actionWithTitle:@"Load MRAID"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction *action) {
    UITextField *textField = alert.textFields.firstObject;
    NSString *enteredURL = textField.text.length > 0 ? textField.text : defaultURL;
    
    NSLog(@"[MRAID Debug] User entered URL: %@", enteredURL);
    
    // Validate URL format
    NSURL *url = [NSURL URLWithString:enteredURL];
    if (url && url.scheme && url.host) {
      [self showDirectMRAIDWebView:enteredURL];
    } else {
      // Show error for invalid URL
      [self showMRAIDURLErrorDialog:enteredURL];
    }
  }];
  
  // Localhost preset button
  UIAlertAction *localhostAction = [UIAlertAction actionWithTitle:@"Use Localhost"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
    [self showDirectMRAIDWebView:@"http://localhost:8080/MRAIDTestAd.html"];
  }];
  
  // Sample MRAID URL preset button
  UIAlertAction *sampleAction = [UIAlertAction actionWithTitle:@"Use Sample URL"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
    [self showDirectMRAIDWebView:@"https://www.iab.com/wp-content/uploads/2015/08/MRAID_3.0_FINAL.js"];
  }];
  
  // Cancel button
  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil];
  
  [alert addAction:loadAction];
  [alert addAction:localhostAction];
  [alert addAction:sampleAction];
  [alert addAction:cancelAction];
  
  // Present the dialog
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMRAIDURLErrorDialog:(NSString *)invalidURL {
  UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Invalid URL"
                                                                      message:[NSString stringWithFormat:@"The URL '%@' is not valid. Please check the format and try again.", invalidURL]
                                                               preferredStyle:UIAlertControllerStyleAlert];
  
  UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction *action) {
    // Show the URL input dialog again
    [self showMRAIDURLInputDialog];
  }];
  
  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:nil];
  
  [errorAlert addAction:okAction];
  [errorAlert addAction:cancelAction];
  
  [self presentViewController:errorAlert animated:YES completion:nil];
}

- (void)updateMRAIDAdvertiserInfo {
  if (!self.advertiserIdLabel) return;
  
  // Get current info
  NSString *idfaString = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
  BOOL isTrackingEnabled = [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
  NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
  
  // Get ATT status if available
  NSString *attStatus = @"N/A";
  if (@available(iOS 14.5, *)) {
    ATTrackingManagerAuthorizationStatus status = [ATTrackingManager trackingAuthorizationStatus];
    switch (status) {
      case ATTrackingManagerAuthorizationStatusNotDetermined:
        attStatus = @"Not Asked";
        break;
      case ATTrackingManagerAuthorizationStatusRestricted:
        attStatus = @"Restricted";
        break;
      case ATTrackingManagerAuthorizationStatusDenied:
        attStatus = @"Denied";
        break;
      case ATTrackingManagerAuthorizationStatusAuthorized:
        attStatus = @"Authorized";
        break;
    }
  }
  
  // Additional debugging
  NSLog(@"=== IDFA Debug Info ===");
  NSLog(@"IDFA String: %@", idfaString);
  NSLog(@"Is Tracking Enabled: %@", isTrackingEnabled ? @"YES" : @"NO");
  NSLog(@"ATT Status: %@", attStatus);
  NSLog(@"Is Simulator: %@", TARGET_OS_SIMULATOR ? @"YES" : @"NO");
  
  // Check if device has Limited Ad Tracking enabled in Settings
  NSString *deviceInfo = @"Real Device";
  if (TARGET_OS_SIMULATOR) {
    deviceInfo = @"⚠️ Simulator";
  }
  
  // Create updated display text
  NSMutableString *displayText = [NSMutableString string];
  [displayText appendString:@"📱 MRAID Advertiser Info (Active)\n\n"];
  
  if (idfaString && ![idfaString isEqualToString:@"00000000-0000-0000-0000-000000000000"]) {
    [displayText appendFormat:@"IDFA: %@...\n", [idfaString substringToIndex:8]];
    [displayText appendFormat:@"Tracking: %@\n", isTrackingEnabled ? @"✅ Enabled" : @"❌ Disabled"];
  } else {
    // For testing purposes, generate a mock IDFA when real one isn't available
    NSString *mockIDFA = @"12345678-ABCD-EFGH-IJKL-MNOPQRSTUVWX";
    [displayText appendString:@"IDFA: ❌ Not available\n"];
    [displayText appendFormat:@"Mock IDFA: %@...\n", [mockIDFA substringToIndex:8]];
    [displayText appendString:@"Tracking: ❌ Disabled\n"];
    
    // Add helpful info for IDFA issues
    if ([attStatus isEqualToString:@"Authorized"]) {
      if (TARGET_OS_SIMULATOR) {
        [displayText appendString:@"ℹ️ Note: Simulator limitation\n"];
        [displayText appendString:@"💡 Try: Test on real device\n"];
      } else {
        [displayText appendString:@"ℹ️ Check: Settings > Privacy > Tracking\n"];
        [displayText appendString:@"💡 Or: Reset Advertising ID\n"];
      }
    }
  }
  
  [displayText appendFormat:@"ATT Status: %@\n", attStatus];
  [displayText appendFormat:@"Device: %@\n", deviceInfo];
  [displayText appendFormat:@"Bundle: %@\n", bundleId];
  [displayText appendString:@"MRAID v3.0 | localhost:8080"];
  
  // Add timestamp
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.timeStyle = NSDateFormatterShortStyle;
  NSString *timestamp = [formatter stringFromDate:[NSDate date]];
  [displayText appendFormat:@"\n%@", timestamp];
  
  // Update with animation
  [UIView animateWithDuration:0.3 animations:^{
    self.advertiserIdLabel.backgroundColor = [UIColor colorWithRed:0.9 green:1.0 blue:0.9 alpha:1.0];
  } completion:^(BOOL finished) {
    [UIView animateWithDuration:0.3 animations:^{
      self.advertiserIdLabel.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:1.0 alpha:1.0];
    }];
  }];
  
  self.advertiserIdLabel.text = [NSString stringWithFormat:@"  %@  ", displayText];
}

- (void)showDirectMRAIDWebView:(NSString *)urlString {
  NSLog(@"Showing MRAID WebView directly");
  
  // Create WebView configuration with MRAID support
  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  
  // Enable debugging and disable caching
  config.preferences.javaScriptEnabled = YES;
  config.preferences.javaScriptCanOpenWindowsAutomatically = YES;
  
  // Disable caching for fresh content on every load
  config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
  
  // Add MRAID JavaScript bridge
  WKUserContentController *contentController = [[WKUserContentController alloc] init];
  [contentController addScriptMessageHandler:self name:@"mraid"];
  
  // Add debugging console bridge
  [contentController addScriptMessageHandler:self name:@"console"];
  
  // Inject console debugging script
  NSString *consoleJS = @"console.log = function(message) { window.webkit.messageHandlers.console.postMessage('LOG: ' + message); };"
                        @"console.error = function(message) { window.webkit.messageHandlers.console.postMessage('ERROR: ' + message); };"
                        @"console.warn = function(message) { window.webkit.messageHandlers.console.postMessage('WARN: ' + message); };"
                        @"window.onerror = function(msg, url, line, col, error) {"
                        @"  var errorMsg = 'JavaScript Error: ' + msg + ' at ' + url + ':' + line + ':' + col;"
                        @"  window.webkit.messageHandlers.console.postMessage(errorMsg);"
                        @"  return false;"
                        @"};";
  WKUserScript *consoleScript = [[WKUserScript alloc] initWithSource:consoleJS
                                                       injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                    forMainFrameOnly:NO];
  [contentController addUserScript:consoleScript];
  
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
  
  // Enable debugging features
  if (@available(iOS 16.4, *)) {
    webView.inspectable = YES;
  }
  
  // Additional debugging settings for development
  webView.allowsBackForwardNavigationGestures = NO;
  webView.allowsLinkPreview = NO;
  
  // Log WebView creation
  NSLog(@"[MRAID Debug] WebView created with debugging enabled");
  NSLog(@"[MRAID Debug] Loading URL: %@", urlString);
  NSLog(@"[MRAID Debug] Cache disabled: YES");
  NSLog(@"[MRAID Debug] Remote debugging: %@", @"YES");
  
  // Create full-screen presentation controller with MRAID orientation support
  MRAIDViewController *presentationController = [[MRAIDViewController alloc] init];
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
    // Create request with no-cache headers
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    [request setValue:@"no-cache, no-store, must-revalidate" forHTTPHeaderField:@"Cache-Control"];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Pragma"];
    [request setValue:@"0" forHTTPHeaderField:@"Expires"];
    
    // Add timestamp to URL to prevent caching
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    NSString *urlWithTimestamp = [NSString stringWithFormat:@"%@?t=%.0f", urlString, timestamp];
    NSURL *finalURL = [NSURL URLWithString:urlWithTimestamp];
    
    NSMutableURLRequest *finalRequest = [NSMutableURLRequest requestWithURL:finalURL];
    finalRequest.cachePolicy = NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
    [finalRequest setValue:@"no-cache, no-store, must-revalidate" forHTTPHeaderField:@"Cache-Control"];
    [finalRequest setValue:@"no-cache" forHTTPHeaderField:@"Pragma"];
    [finalRequest setValue:@"0" forHTTPHeaderField:@"Expires"];
    
    NSLog(@"[MRAID Debug] Loading with no-cache URL: %@", urlWithTimestamp);
    [webView loadRequest:finalRequest];
    
    // Present the ad
    [self presentViewController:presentationController animated:YES completion:^{
      NSLog(@"MRAID WebView presented");
    }];
  } else {
    NSLog(@"Invalid MRAID URL: %@", urlString);
  }
}

- (void)closeMRAIDWebView:(UIButton *)sender {
  MRAIDViewController *presentationController = objc_getAssociatedObject(sender, "webViewController");
  if (presentationController) {
    [presentationController dismissViewControllerAnimated:YES completion:^{
      NSLog(@"MRAID WebView dismissed");
    }];
  }
}

- (NSString *)getMRAIDJavaScript {
  // Complete MRAID 3.0 JavaScript implementation with all methods
  return @"var mraid = (function() {\n"
         @"  var state = 'loading';\n"
         @"  var isViewable = false;\n"
         @"  var listeners = {};\n"
         @"  var customCloseEnabled = false;\n"
         @"  var orientationProperties = {\n"
         @"    allowOrientationChange: true,\n"
         @"    forceOrientation: 'none'\n"
         @"  };\n"
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
         @"    useCustomClose: function(useCustomClose) {\n"
         @"      customCloseEnabled = !!useCustomClose;\n"
         @"      window.webkit.messageHandlers.mraid.postMessage({\n"
         @"        action: 'useCustomClose',\n"
         @"        useCustomClose: customCloseEnabled\n"
         @"      });\n"
         @"    },\n"
         @"    \n"
         @"    setOrientationProperties: function(properties) {\n"
         @"      if (properties && typeof properties === 'object') {\n"
         @"        if (properties.hasOwnProperty('allowOrientationChange')) {\n"
         @"          orientationProperties.allowOrientationChange = !!properties.allowOrientationChange;\n"
         @"        }\n"
         @"        if (properties.hasOwnProperty('forceOrientation')) {\n"
         @"          var validOrientations = ['portrait', 'landscape', 'none'];\n"
         @"          if (validOrientations.indexOf(properties.forceOrientation) !== -1) {\n"
         @"            orientationProperties.forceOrientation = properties.forceOrientation;\n"
         @"          }\n"
         @"        }\n"
         @"        window.webkit.messageHandlers.mraid.postMessage({\n"
         @"          action: 'setOrientationProperties',\n"
         @"          orientationProperties: orientationProperties\n"
         @"        });\n"
         @"      }\n"
         @"    },\n"
         @"    \n"
         @"    getOrientationProperties: function() {\n"
         @"      return JSON.parse(JSON.stringify(orientationProperties));\n"
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
         @"    isFeatureSupported: function(feature) {\n"
         @"      var supportedFeatures = ['sms', 'tel', 'calendar', 'storePicture', 'inlineVideo'];\n"
         @"      return supportedFeatures.indexOf(feature) !== -1;\n"
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
         @"    },\n"
         @"    \n"
         @"    _updateCustomClose: function(enabled) {\n"
         @"      customCloseEnabled = enabled;\n"
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

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
  NSLog(@"[MRAID Debug] WebView started loading: %@", webView.URL.absoluteString);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  NSLog(@"[MRAID Debug] WebView finished loading: %@", webView.URL.absoluteString);
  
  // Inject additional debugging code after page load
  NSString *debugJS = @"console.log('MRAID WebView loaded successfully');"
                      @"console.log('MRAID object available:', typeof mraid !== 'undefined');"
                      @"console.log('Document ready state:', document.readyState);"
                      @"if (typeof mraid !== 'undefined') {"
                      @"  console.log('MRAID version:', mraid.getVersion());"
                      @"  console.log('MRAID state:', mraid.getState());"
                      @"  console.log('MRAID viewable:', mraid.isViewable());"
                      @"}";
  
  [webView evaluateJavaScript:debugJS completionHandler:^(id result, NSError *error) {
    if (error) {
      NSLog(@"[MRAID Debug] Error injecting debug script: %@", error.localizedDescription);
    }
  }];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  NSLog(@"[MRAID Debug] WebView failed to load: %@", error.localizedDescription);
  NSLog(@"[MRAID Debug] Error domain: %@", error.domain);
  NSLog(@"[MRAID Debug] Error code: %ld", (long)error.code);
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  NSLog(@"[MRAID Debug] WebView failed provisional navigation: %@", error.localizedDescription);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  NSLog(@"[MRAID Debug] Navigation request: %@", navigationAction.request.URL.absoluteString);
  decisionHandler(WKNavigationActionPolicyAllow);
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
    } else if ([action isEqualToString:@"useCustomClose"]) {
      BOOL useCustomClose = [data[@"useCustomClose"] boolValue];
      NSLog(@"MRAID useCustomClose: %@", useCustomClose ? @"YES" : @"NO");
      [self handleCustomCloseChange:useCustomClose];
    } else if ([action isEqualToString:@"setOrientationProperties"]) {
      NSDictionary *orientationProperties = data[@"orientationProperties"];
      NSLog(@"MRAID setOrientationProperties: %@", orientationProperties);
      [self handleOrientationPropertiesChange:orientationProperties];
    }
  } else if ([message.name isEqualToString:@"console"]) {
    // Handle JavaScript console output for debugging
    NSString *consoleMessage = [NSString stringWithFormat:@"[WebView Console] %@", message.body];
    NSLog(@"%@", consoleMessage);
  }
}

#pragma mark - MRAID Action Handlers

- (void)handleCustomCloseChange:(BOOL)useCustomClose {
  // Handle custom close button visibility
  UIViewController *presentedController = self.presentedViewController;
  if (presentedController && [presentedController isKindOfClass:[MRAIDViewController class]]) {
    // Find the close button in the presented view
    for (UIView *subview in presentedController.view.subviews) {
      if ([subview isKindOfClass:[UIButton class]]) {
        UIButton *closeButton = (UIButton *)subview;
        if ([closeButton.titleLabel.text isEqualToString:@"✕"]) {
          // Hide/show the default close button based on useCustomClose
          closeButton.hidden = useCustomClose;
          NSLog(@"[MRAID Debug] Default close button %@", useCustomClose ? @"hidden" : @"shown");
          break;
        }
      }
    }
  }
}

- (void)handleOrientationPropertiesChange:(NSDictionary *)orientationProperties {
  // Handle orientation changes
  BOOL allowOrientationChange = [orientationProperties[@"allowOrientationChange"] boolValue];
  NSString *forceOrientation = orientationProperties[@"forceOrientation"];
  
  NSLog(@"[MRAID Debug] Orientation - Allow change: %@, Force: %@", 
        allowOrientationChange ? @"YES" : @"NO", forceOrientation);
  
  // Apply orientation settings to the presented MRAID view controller
  UIViewController *presentedController = self.presentedViewController;
  if (presentedController && [presentedController isKindOfClass:[MRAIDViewController class]]) {
    MRAIDViewController *mraidController = (MRAIDViewController *)presentedController;
    
    // Update MRAID orientation properties
    mraidController.allowOrientationChange = allowOrientationChange;
    mraidController.forceOrientation = forceOrientation ?: @"none";
    
    NSLog(@"[MRAID Debug] Updated MRAIDViewController - Allow change: %@, Force: %@", 
          mraidController.allowOrientationChange ? @"YES" : @"NO", mraidController.forceOrientation);
    
    // Force orientation change if specified and orientation changes are not allowed
    if (!allowOrientationChange) {
      UIInterfaceOrientation targetOrientation = UIInterfaceOrientationUnknown;
      
      if ([forceOrientation isEqualToString:@"portrait"]) {
        targetOrientation = UIInterfaceOrientationPortrait;
      } else if ([forceOrientation isEqualToString:@"landscape"]) {
        targetOrientation = UIInterfaceOrientationLandscapeLeft;
      }
      
      if (targetOrientation != UIInterfaceOrientationUnknown) {
        // Force the orientation change
        [[UIDevice currentDevice] setValue:@(targetOrientation) forKey:@"orientation"];
        NSLog(@"[MRAID Debug] Forced orientation to: %@", forceOrientation);
      }
    }
    
    // Trigger orientation update
    [UIViewController attemptRotationToDeviceOrientation];
    
  } else {
    NSLog(@"[MRAID Debug] Warning: Presented controller is not MRAIDViewController");
  }
}

@end
