# MRAID Custom Event for Google AdMob iOS

This implementation provides a custom event adapter for Google AdMob iOS SDK that supports MRAID (Mobile Rich Media Ad Interface Definitions) ads displayed in a full-screen WebView.

## Overview

The MRAID Custom Event allows you to:
- Display HTML/JavaScript-based ads in a full-screen interstitial format
- Provide full MRAID 3.0 JavaScript bridge functionality
- Handle ad interactions (clicks, close, expand)
- Track impressions and events through the AdMob SDK

## Files

### Core Implementation
- `MRAIDCustomEvent.h/.m` - Main adapter conforming to `GADMediationAdapter`
- `MRAIDCustomEventInterstitial.h/.m` - Interstitial ad implementation with WKWebView

### Testing
- `MRAIDTestAd.html` - Sample MRAID ad for testing
- `MRAID_README.md` - This documentation

## Setup

1. **Add the files to your project:**
   - Copy `MRAIDCustomEvent.h/.m` and `MRAIDCustomEventInterstitial.h/.m` to your CustomEvent directory
   - Ensure WebKit framework is linked to your project

2. **Configure in AdMob:**
   - Create a new Custom Event in your AdMob dashboard
   - Set the class name to `MRAIDCustomEvent`
   - Configure parameters (see Configuration section below)

## Configuration

### AdMob Dashboard Configuration

In your AdMob custom event configuration, set the following parameters:

```json
{
  "url": "https://your-domain.com/path/to/your-mraid-ad.html"
}
```

### Required Parameters
- `url` (string): The URL of the MRAID-compliant HTML ad to display

## MRAID Support

This implementation supports MRAID 3.0 with the following features:

### Core Methods
- `mraid.getVersion()` - Returns "3.0"
- `mraid.getState()` - Returns current state ("loading", "default", "expanded")
- `mraid.isViewable()` - Returns viewability status
- `mraid.close()` - Closes the ad
- `mraid.open(url)` - Opens external URL

### Event Handling
- `ready` - Fired when MRAID is ready
- `stateChange` - Fired when ad state changes
- `viewableChange` - Fired when viewability changes

### Utility Methods
- `mraid.getScreenSize()` - Returns device screen dimensions
- `mraid.getMaxSize()` - Returns maximum ad size
- `mraid.getCurrentPosition()` - Returns current ad position

### Example MRAID Ad HTML

```html
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My MRAID Ad</title>
</head>
<body>
    <div id="ad-content">
        <h1>My Awesome Ad</h1>
        <button onclick="mraid.open('https://example.com')">Learn More</button>
        <button onclick="mraid.close()">Close</button>
    </div>
    
    <script>
        function onMraidReady() {
            console.log('MRAID Version:', mraid.getVersion());
            console.log('State:', mraid.getState());
        }
        
        if (mraid.getState() === 'loading') {
            mraid.addEventListener('ready', onMraidReady);
        } else {
            onMraidReady();
        }
    </script>
</body>
</html>
```

## Usage Example

### In your iOS app:

```objective-c
// Configure ad request
GADRequest *request = [GADRequest request];

// Load interstitial
GADInterstitialAd *interstitial;
[GADInterstitialAd loadWithAdUnitID:@"your-ad-unit-id"
                             request:request
                   completionHandler:^(GADInterstitialAd *ad, NSError *error) {
    if (error) {
        NSLog(@"Failed to load interstitial ad: %@", error.localizedDescription);
        return;
    }
    interstitial = ad;
    
    // Present the ad
    [interstitial presentFromRootViewController:self];
}];
```

## Testing

1. **Use the included test file:**
   - Host `MRAIDTestAd.html` on a web server
   - Configure your custom event to use the hosted URL
   - Test in your app

2. **Verify MRAID functionality:**
   - Check that MRAID version displays as "3.0"
   - Test close button functionality
   - Test external link opening
   - Verify state changes are tracked

## Features

### ✅ Implemented
- Full-screen interstitial display
- MRAID 3.0 JavaScript bridge
- WKWebView with proper configuration
- Click tracking and external URL handling
- Impression reporting
- State management (loading → default → expanded)
- Close button with native styling
- Error handling for invalid URLs

### 🔄 Future Enhancements
- Banner ad support
- Expandable banner ads  
- Video ad support
- Advanced MRAID features (resize, etc.)
- Custom close button positioning

## Troubleshooting

### Common Issues

1. **Ad not loading:**
   - Verify the URL is accessible and returns valid HTML
   - Check network connectivity
   - Ensure URL parameter is correctly configured

2. **MRAID methods not working:**
   - Verify your HTML includes proper MRAID event listeners
   - Check browser console for JavaScript errors
   - Ensure DOM is loaded before calling MRAID methods

3. **Links not opening:**
   - Verify URLs are properly formatted (include http:// or https://)
   - Check that URLs are reachable

### Debug Logging

Enable debug logging to troubleshoot issues:

```objective-c
// Add to your app delegate
[[GADMobileAds sharedInstance] startWithCompletionHandler:nil];
// Enable debug logging in Xcode console
```

## Requirements

- iOS 11.0+
- Google Mobile Ads SDK 8.0+
- WebKit framework
- ARC enabled

## License

Licensed under the Apache License, Version 2.0. See the individual source files for complete license information. 