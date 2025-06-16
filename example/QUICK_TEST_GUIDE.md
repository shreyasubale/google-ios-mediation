# Quick MRAID Test Guide

## 🚀 Immediate Testing Steps

### 1. **Start the Local Server**
```bash
# In your project directory
python3 LocalMRAIDServer.py
```
You should see:
```
Starting MRAID test server on port 8080
Access your MRAID test ad at: http://localhost:8080/MRAIDTestAd.html
```

### 2. **Test the HTML File** (Optional)
Open in browser to verify:
```bash
open http://localhost:8080/MRAIDTestAd.html
```

### 3. **Build and Run the App**
1. **Clean Build:** In Xcode: Product → Clean Build Folder
2. **Build and Run:** ⌘+R
3. **Select MRAID Option:** You should now see 3 options:
   - Objective-C Custom Event
   - Swift Custom Event
   - **MRAID Custom Event** ← Select this one

### 4. **Test MRAID Interstitial**
1. Tap "MRAID Custom Event"
2. Tap "Show Interstitial"
3. **Expected Result:** Full-screen MRAID ad with:
   - 🚀 Animated logo
   - Modern gradient background
   - MRAID version info (3.0)
   - Interactive buttons

### 5. **What to Test**
✅ **MRAID Functionality:**
- "Learn More" button → Opens external URL
- "Close" button → Closes the ad
- Check console logs for MRAID events

✅ **Expected Console Output:**
```
Showing MRAID interstitial - bypassing mediation for testing
Showing MRAID WebView directly
MRAID WebView finished loading
MRAID WebView presented
```

## 🐛 Troubleshooting

### Issue: Still seeing old alert dialog
**Solution:** Clean build + restart app
```bash
# In Xcode
Product → Clean Build Folder
Product → Run
```

### Issue: "MRAID Custom Event" option not showing
**Verify these files were modified:**
- `MediationExample/StartViewController.m` 
- `MediationExample/AdSourceConfig.h/.m`

### Issue: MRAID ad not loading
1. **Check server is running:**
   ```bash
   curl http://localhost:8080/MRAIDTestAd.html
   ```

2. **Check simulator/device network:**
   - iOS Simulator: Should work with localhost
   - Physical device: Use your computer's IP address

### Issue: Network connection on device
If testing on physical device, update the URL:
```objective-c
// In ViewController.m, change:
NSString *mraidURL = @"http://YOUR_COMPUTER_IP:8080/MRAIDTestAd.html";
```

Find your IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`

## 🎯 Expected Behavior

### Successful Test Flow:
1. **App Launch** → Shows 3 menu options
2. **Select MRAID** → Navigates to ad testing screen
3. **Show Interstitial** → Immediately displays MRAID WebView
4. **MRAID Ad Loads** → Shows animated ad with MRAID info panel
5. **Test Interactions:**
   - Close button works
   - Learn More opens Safari
   - Console shows MRAID events

### Console Logs (Success):
```
Showing MRAID interstitial - bypassing mediation for testing
Showing MRAID WebView directly
GET request for: /MRAIDTestAd.html
MRAID WebView finished loading
MRAID WebView presented
MRAID action received: open (when tapping Learn More)
MRAID action received: close (when tapping Close)
```

## 🎉 Success Indicators

✅ **You'll know it's working when:**
1. Third menu option appears: "MRAID Custom Event"
2. No alert dialogs when tapping "Show Interstitial"
3. Full-screen MRAID ad appears with animations
4. MRAID info panel shows "Version: 3.0"
5. Buttons work and console shows MRAID events

## 🔄 Next Steps

Once basic testing works:
1. **Host online** for real device testing
2. **Configure AdMob** with real ad units  
3. **Test production flow** with mediation
4. **Add your own MRAID creatives**

---

**Need help?** Check the console logs and verify each step above! 🚀 