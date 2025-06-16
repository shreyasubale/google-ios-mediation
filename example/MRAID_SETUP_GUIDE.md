# MRAID Custom Event Setup Guide

## Quick Start

I've successfully implemented a MRAID custom event for your Google AdMob iOS example app. Here's how to test it:

### 1. Files Added

✅ **MRAID Implementation Files:**
- `CustomEvent/MRAIDCustomEvent.h/.m` - Main adapter
- `CustomEvent/MRAIDCustomEventInterstitial.h/.m` - Interstitial implementation
- `MRAIDTestAd.html` - Sample MRAID ad
- `LocalMRAIDServer.py` - Local test server

✅ **Modified Files:**
- Updated `MediationExample/AdSourceConfig.h/.m` - Added MRAID option
- Updated `MediationExample/StartViewController.m` - Added MRAID menu option 
- Updated `MediationExample/ViewController.m` - Added MRAID test functionality

### 2. Testing the MRAID Implementation

#### Option A: Using the Modified Example App

1. **Start the local server:**
   ```bash
   cd /path/to/your/project
   python3 LocalMRAIDServer.py
   ```
   
2. **Build and run the app:**
   - Open `MediationExample.xcodeproj` in Xcode
   - Build and run the app
   - You should see "MRAID Custom Event" option in the main menu

3. **Test MRAID interstitial:**
   - Tap "MRAID Custom Event" from the main menu
   - Tap "Show Interstitial" button
   - The MRAID ad should load in full-screen WebView

#### Option B: Direct Testing (Recommended)

The app is set up to automatically test MRAID when you select the MRAID option:

1. **Start local server:**
   ```bash
   python3 LocalMRAIDServer.py
   ```

2. **In the app:**
   - Select "MRAID Custom Event" from main menu
   - Tap "Show Interstitial" - it will directly load the MRAID test ad

### 3. What You'll See

The MRAID test ad includes:
- 🚀 Animated logo and modern UI
- **MRAID Info Panel** showing:
  - MRAID Version: 3.0
  - State: default → expanded
  - Viewable: true
  - Screen size dimensions
- **Interactive buttons:**
  - "Learn More" - opens external URL (reports click)
  - "Close" - closes the ad using MRAID

### 4. MRAID Features Implemented

#### Core MRAID 3.0 Methods:
- ✅ `mraid.getVersion()` - Returns "3.0"
- ✅ `mraid.getState()` - State management
- ✅ `mraid.isViewable()` - Viewability tracking
- ✅ `mraid.close()` - Close functionality
- ✅ `mraid.open(url)` - External URL opening
- ✅ `mraid.getScreenSize()` - Device dimensions
- ✅ `mraid.getCurrentPosition()` - Ad position
- ✅ `mraid.getMaxSize()` - Maximum ad size

#### Event Handling:
- ✅ `ready` event - Fired when MRAID is ready
- ✅ `stateChange` event - State transitions
- ✅ `viewableChange` event - Viewability changes

#### Native Integration:
- ✅ Full-screen presentation with proper view hierarchy
- ✅ Close button with native styling
- ✅ Click tracking and impression reporting
- ✅ External URL handling with Safari integration
- ✅ Proper lifecycle management

### 5. Using Your Own MRAID Ads

To use your own MRAID ads instead of the test ad:

1. **Host your MRAID ad online** (must be HTTPS for production)

2. **Update the URL in the test method:**
   ```objective-c
   // In ViewController.m, change this line:
   NSString *mraidURL = @"https://your-domain.com/your-mraid-ad.html";
   ```

3. **Or configure via AdMob dashboard:**
   - Set up a real custom event in AdMob
   - Use class name: `MRAIDCustomEvent`
   - Set parameter: `{"url": "https://your-domain.com/your-ad.html"}`

### 6. Production Setup

For production use:

1. **Upload MRAID files to your project**
2. **Configure in AdMob dashboard:**
   - Custom Event Class: `MRAIDCustomEvent`
   - Parameter: `{"url": "https://your-mraid-ad-url.html"}`
3. **Ensure WebKit framework is linked**
4. **Test with real ad units**

### 7. Troubleshooting

#### Ad not loading:
- ✅ Check that `LocalMRAIDServer.py` is running
- ✅ Verify `MRAIDTestAd.html` is in the same directory
- ✅ Check console logs for errors

#### MRAID methods not working:
- ✅ Verify HTML includes MRAID event listeners
- ✅ Check that `mraid` object is available
- ✅ Ensure proper DOM loading sequence

#### Links not opening:
- ✅ URLs must include `http://` or `https://`
- ✅ Check device/simulator Safari access

### 8. Next Steps

You now have a fully functional MRAID custom event! You can:

1. **Customize the MRAID JavaScript bridge** for additional features
2. **Add banner ad support** using the same pattern
3. **Implement advanced MRAID features** like resize, expand, etc.
4. **Add your own creative templates** and host them online

The implementation follows Google's mediation best practices and provides a solid foundation for rich media advertising in your iOS app.

---

## Quick Command Reference

```bash
# Start test server
python3 LocalMRAIDServer.py

# View test ad in browser
open http://localhost:8080/MRAIDTestAd.html

# Build and run in Xcode
# Select MRAID Custom Event → Show Interstitial
```

🎉 **Your MRAID custom event is ready to use!** 