//
//  MRAIDCustomEvent.m
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

#import "MRAIDCustomEvent.h"
#import "MRAIDCustomEventInterstitial.h"

@implementation MRAIDCustomEvent {
  MRAIDCustomEventInterstitial *mraidInterstitial;
}

#pragma mark GADMediationAdapter implementation

+ (GADVersionNumber)adSDKVersion {
  GADVersionNumber version = {0};
  version.majorVersion = 1;
  version.minorVersion = 0;
  version.patchVersion = 0;
  return version;
}

+ (GADVersionNumber)adapterVersion {
  GADVersionNumber version = {0};
  version.majorVersion = 1;
  version.minorVersion = 0;
  version.patchVersion = 0;
  return version;
}

+ (nullable Class<GADAdNetworkExtras>)networkExtrasClass {
  return Nil;
}

+ (void)setUpWithConfiguration:(GADMediationServerConfiguration *)configuration
             completionHandler:(GADMediationAdapterSetUpCompletionBlock)completionHandler {
  // MRAID adapter setup - no specific SDK initialization needed for WebView-based ads
  completionHandler(nil);
}

- (void)loadInterstitialForAdConfiguration:
            (GADMediationInterstitialAdConfiguration *)adConfiguration
                         completionHandler:
                             (GADMediationInterstitialLoadCompletionHandler)completionHandler {
  mraidInterstitial = [[MRAIDCustomEventInterstitial alloc] init];
  [mraidInterstitial loadInterstitialForAdConfiguration:adConfiguration
                                      completionHandler:completionHandler];
}

// Banner and other ad types can be implemented later if needed
- (void)loadBannerForAdConfiguration:(GADMediationBannerAdConfiguration *)adConfiguration
                   completionHandler:(GADMediationBannerLoadCompletionHandler)completionHandler {
  NSError *error = [NSError errorWithDomain:@"MRAIDCustomEvent" 
                                       code:1001 
                                   userInfo:@{NSLocalizedDescriptionKey: @"Banner ads not implemented for MRAID custom event"}];
  completionHandler(nil, error);
}

- (void)loadRewardedAdForAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
                       completionHandler:
                           (GADMediationRewardedLoadCompletionHandler)completionHandler {
  NSError *error = [NSError errorWithDomain:@"MRAIDCustomEvent" 
                                       code:1002 
                                   userInfo:@{NSLocalizedDescriptionKey: @"Rewarded ads not implemented for MRAID custom event"}];
  completionHandler(nil, error);
}

- (void)loadNativeAdForAdConfiguration:(GADMediationNativeAdConfiguration *)adConfiguration
                     completionHandler:(GADMediationNativeLoadCompletionHandler)completionHandler {
  NSError *error = [NSError errorWithDomain:@"MRAIDCustomEvent" 
                                       code:1003 
                                   userInfo:@{NSLocalizedDescriptionKey: @"Native ads not implemented for MRAID custom event"}];
  completionHandler(nil, error);
}

@end 