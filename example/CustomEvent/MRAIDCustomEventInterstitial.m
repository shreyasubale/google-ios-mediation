//
//  MRAIDCustomEventInterstitial.m
//  MRAID Custom Event
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "MRAIDCustomEventInterstitial.h"
#include <stdatomic.h>
#import "SampleCustomEventConstants.h"
#import "SampleCustomEventUtils.h"

@interface MRAIDCustomEventInterstitial () <WKNavigationDelegate, WKScriptMessageHandler, GADMediationInterstitialAd> {
  /// The MRAID WebView for displaying the ad
  WKWebView *_webView;
  
  /// The full-screen presentation controller
  UIViewController *_presentationController;
  
  /// The completion handler to call when the ad loading succeeds or fails.
  GADMediationInterstitialLoadCompletionHandler _loadCompletionHandler;

  /// The ad event delegate to forward ad rendering events to the Google Mobile Ads SDK.
  id<GADMediationInterstitialAdEventDelegate> _adEventDelegate;
  
  /// The ad URL to load
  NSString *_adURL;
  
  /// MRAID state tracking
  BOOL _isLoaded;
  BOOL _isViewable;
  NSString *_mraidState;
}

@end

@implementation MRAIDCustomEventInterstitial

- (void)loadInterstitialForAdConfiguration:
            (GADMediationInterstitialAdConfiguration *)adConfiguration
                         completionHandler:
                             (GADMediationInterstitialLoadCompletionHandler)completionHandler {
  __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
  __block GADMediationInterstitialLoadCompletionHandler originalCompletionHandler =
      [completionHandler copy];

  _loadCompletionHandler = ^id<GADMediationInterstitialAdEventDelegate>(
      _Nullable id<GADMediationInterstitialAd> ad, NSError *_Nullable error) {
    // Only allow completion handler to be called once.
    if (atomic_flag_test_and_set(&completionHandlerCalled)) {
      return nil;
    }

    id<GADMediationInterstitialAdEventDelegate> delegate = nil;
    if (originalCompletionHandler) {
      // Call original handler and hold on to its return value.
      delegate = originalCompletionHandler(ad, error);
    }

    // Release reference to handler. Objects retained by the handler will also be released.
    originalCompletionHandler = nil;

    return delegate;
  };

  // Get the ad URL from configuration
  _adURL = adConfiguration.credentials.settings[@"url"];
  if (!_adURL || _adURL.length == 0) {
    NSError *error = SampleCustomEventErrorWithCodeAndDescription(
        SampleCustomEventErrorAdLoadFailureCallback,
        @"MRAID ad URL is missing from configuration");
    _adEventDelegate = _loadCompletionHandler(nil, error);
    return;
  }
  
  [self setupWebView];
  [self loadAdFromURL:_adURL];
}

- (void)setupWebView {
  // Configure WKWebView with MRAID support
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
  
  _webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
  _webView.navigationDelegate = self;
  
  // Initialize MRAID state
  _isLoaded = NO;
  _isViewable = NO;
  _mraidState = @"loading";
}

- (void)loadAdFromURL:(NSString *)urlString {
  NSURL *url = [NSURL URLWithString:urlString];
  if (!url) {
    NSError *error = SampleCustomEventErrorWithCodeAndDescription(
        SampleCustomEventErrorAdLoadFailureCallback,
        @"Invalid MRAID ad URL");
    _adEventDelegate = _loadCompletionHandler(nil, error);
    return;
  }
  
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  [_webView loadRequest:request];
}

- (NSString *)getMRAIDJavaScript {
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
         @"    expand: function(url) {\n"
         @"      window.webkit.messageHandlers.mraid.postMessage({action: 'expand', url: url});\n"
         @"    },\n"
         @"    \n"
         @"    resize: function() {\n"
         @"      // Not supported for interstitials\n"
         @"      console.log('MRAID: resize() is not supported for interstitial ads');\n"
         @"    },\n"
         @"    \n"
         @"    setResizeProperties: function(properties) {\n"
         @"      // Not supported for interstitials\n"
         @"      console.log('MRAID: setResizeProperties() is not supported for interstitial ads');\n"
         @"    },\n"
         @"    \n"
         @"    getResizeProperties: function() {\n"
         @"      return null; // Not supported for interstitials\n"
         @"    },\n"
         @"    \n"
         @"    getPlacementType: function() {\n"
         @"      return 'interstitial';\n"
         @"    },\n"
         @"    \n"
         @"    supports: function(feature) {\n"
         @"      var supportedFeatures = {\n"
         @"        'sms': false,\n"
         @"        'tel': false,\n"
         @"        'calendar': false,\n"
         @"        'storePicture': false,\n"
         @"        'inlineVideo': true,\n"
         @"        'vpaid': false,\n"
         @"        'location': false\n"
         @"      };\n"
         @"      return supportedFeatures[feature] || false;\n"
         @"    },\n"
         @"    \n"
         @"    getScreenSize: function() {\n"
         @"      return {\n"
         @"        width: window.screen.width,\n"
         @"        height: window.screen.height\n"
         @"      };\n"
         @"    },\n"
         @"    \n"
         @"    getMaxSize: function() {\n"
         @"      return {\n"
         @"        width: window.innerWidth,\n"
         @"        height: window.innerHeight\n"
         @"      };\n"
         @"    },\n"
         @"    \n"
         @"    getCurrentPosition: function() {\n"
         @"      return {\n"
         @"        x: 0,\n"
         @"        y: 0,\n"
         @"        width: window.innerWidth,\n"
         @"        height: window.innerHeight\n"
         @"      };\n"
         @"    },\n"
         @"    \n"
         @"    setExpandProperties: function(properties) {\n"
         @"      // For interstitials, we're already full-screen, so we just acknowledge the call\n"
         @"      // Properties typically include: width, height, useCustomClose, isModal\n"
         @"      console.log('MRAID: setExpandProperties called with', properties);\n"
         @"    },\n"
         @"    \n"
         @"    getExpandProperties: function() {\n"
         @"      // Return default expand properties for interstitials\n"
         @"      return {\n"
         @"        width: window.screen.width,\n"
         @"        height: window.screen.height,\n"
         @"        useCustomClose: false,\n"
         @"        isModal: true\n"
         @"      };\n"
         @"    },\n"
         @"    \n"
         @"    getDefaultPosition: function() {\n"
         @"      // For interstitials, default position is full screen\n"
         @"      return {\n"
         @"        x: 0,\n"
         @"        y: 0,\n"
         @"        width: window.innerWidth,\n"
         @"        height: window.innerHeight\n"
         @"      };\n"
         @"    },\n"
         @"    \n"
         @"    useCustomClose: function(shouldUseCustomClose) {\n"
         @"      // Store the preference but for interstitials we always show close button\n"
         @"      console.log('MRAID: useCustomClose called with', shouldUseCustomClose);\n"
         @"    },\n"
         @"    \n"
         @"    // Internal methods for native bridge\n"
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
         @"// Fire ready event when DOM is loaded\n"
         @"if (document.readyState === 'loading') {\n"
         @"  document.addEventListener('DOMContentLoaded', function() {\n"
         @"    mraid._setState('default');\n"
         @"    mraid._setIsViewable(true);\n"
         @"    mraid._fireReady();\n"
         @"  });\n"
         @"} else {\n"
         @"  setTimeout(function() {\n"
         @"    mraid._setState('default');\n"
         @"    mraid._setIsViewable(true);\n"
         @"    mraid._fireReady();\n"
         @"  }, 1);\n"
         @"}\n";
}

#pragma mark - GADMediationInterstitialAd implementation

- (void)presentFromViewController:(UIViewController *)viewController {
  if (!_isLoaded) {
    NSError *error = SampleCustomEventErrorWithCodeAndDescription(
        SampleCustomEventErrorAdNotLoaded,
        @"The MRAID interstitial ad failed to present because the ad was not loaded.");
    [_adEventDelegate didFailToPresentWithError:error];
    return;
  }
  
  // Create full-screen presentation controller
  _presentationController = [[UIViewController alloc] init];
  _presentationController.modalPresentationStyle = UIModalPresentationFullScreen;
  
  // Setup WebView for full-screen display
  _webView.frame = _presentationController.view.bounds;
  _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [_presentationController.view addSubview:_webView];
  
  // Add close button
  UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [closeButton setTitle:@"✕" forState:UIControlStateNormal];
  closeButton.frame = CGRectMake(20, 44, 44, 44);
  closeButton.titleLabel.font = [UIFont systemFontOfSize:24];
  [closeButton addTarget:self action:@selector(closeAd) forControlEvents:UIControlEventTouchUpInside];
  [_presentationController.view addSubview:closeButton];
  
  // Present the ad
  [viewController presentViewController:_presentationController animated:YES completion:^{
    [self->_adEventDelegate willPresentFullScreenView];
    [self->_adEventDelegate reportImpression];
    
    // Update MRAID state
    [self executeJavaScript:@"mraid._setState('expanded');"];
    [self executeJavaScript:@"mraid._setIsViewable(true);"];
  }];
}

- (void)closeAd {
  if (_presentationController) {
    [_adEventDelegate willDismissFullScreenView];
    
    [_presentationController dismissViewControllerAnimated:YES completion:^{
      [self->_adEventDelegate didDismissFullScreenView];
      self->_presentationController = nil;
    }];
    
    // Update MRAID state
    [self executeJavaScript:@"mraid._setState('default');"];
  }
}

- (void)executeJavaScript:(NSString *)javascript {
  [_webView evaluateJavaScript:javascript completionHandler:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  _isLoaded = YES;
  _isViewable = YES;
  _mraidState = @"default";
  
  // Notify AdMob that the ad is loaded
  _adEventDelegate = _loadCompletionHandler(self, nil);
  
  // Update MRAID state
  [self executeJavaScript:@"mraid._setState('default');"];
  [self executeJavaScript:@"mraid._setIsViewable(true);"];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
  NSError *loadError = SampleCustomEventErrorWithCodeAndDescription(
      SampleCustomEventErrorAdLoadFailureCallback,
      [NSString stringWithFormat:@"MRAID ad failed to load: %@", error.localizedDescription]);
  _adEventDelegate = _loadCompletionHandler(nil, loadError);
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  NSURL *url = navigationAction.request.URL;
  
  // Handle external links
  if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
    if ([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
      // Report click and open in external browser
      [_adEventDelegate reportClick];
      [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
      decisionHandler(WKNavigationActionPolicyCancel);
      return;
    }
  }
  
  decisionHandler(WKNavigationActionPolicyAllow);
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
  if ([message.name isEqualToString:@"mraid"]) {
    NSDictionary *data = message.body;
    NSString *action = data[@"action"];
    
    if ([action isEqualToString:@"close"]) {
      [self closeAd];
    } else if ([action isEqualToString:@"open"]) {
      NSString *urlString = data[@"url"];
      if (urlString) {
        NSURL *url = [NSURL URLWithString:urlString];
        if (url) {
          [_adEventDelegate reportClick];
          [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
      }
    } else if ([action isEqualToString:@"expand"]) {
      // Already expanded for interstitial, ignore
    }
  }
}

@end 