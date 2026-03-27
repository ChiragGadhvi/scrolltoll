# 🕰️ ScrollToll - The Anti-Scrolling Tracker

**Turn your wasted time into a visible cost. Stop mindlessly scrolling and start saving your day.**

---

## 📝 Play Store Listing Details

### 🏷️ Top Details
- **App Title:** ScrollToll: Stop Mindless Scrolling
- **Short Description:** Your time is money. Track exactly how much you're wasting today. 💸
- **Category:** Productivity / Health & Fitness
- **Target Audience:** Everyone (PEGI 3 / ESRB Everyone)

---

### 📖 Full Description
**Did you know you waste hours every day just... scrolling?**

ScrollToll is the app that treats your screen time like your bank account. Every minute you spend on addictive social media apps is "toll" deducted from your daily savings jar. When the jar hits zero, your day's value is gone!

**Why Use ScrollToll?**
Unlike boring screen time trackers, ScrollToll uses a unique **"Time ↔ Money"** logic (1:1 pts) to make you feel the weight of every wasted minute. It's built to be simple, fun, and highly visual.

**Key Features:**
- 🏺 **The Savings Jar:** Watch your digital value drain in real-time. A visual jar that changes from full and glowing to empty and cracked as you scroll.
- 📱 **Track Specific Apps:** You choose only the time-wasting apps you want to limit (Instagram, TikTok, YouTube). 
- 📊 **Beautiful Analytics:** Switch between Daily and Weekly views. See exactly how many points you saved each day over the last week.
- 🏺 **Daywise History:** View your progress across the week with specialized jars for every single day.
- 🏠 **Home Screen Widget:** Keep your jar on your home screen for constant accountability.
- 🔒 **Privacy First:** 100% Offline. We don't collect data, sell usage info, or even use the internet for tracking. Everything happens on your device.

**Take back your day. Download ScrollToll and start saving time today.**

---

### 🎨 Visual Assets Checklist
1. **App Icon:** (Already generated and applied).
2. **Feature Graphic:** 1024 x 500 image showing the Savings Jar.
3. **Screenshots:**
   - **Home Screen:** Showing the "Time Value Jar" in its full, glowing state.
   - **Analytics Screen:** Showing the "Daywise Savings" history with mini jars.
   - **App Selection:** Showing the simple list of apps being tracked.
   - **The "Addiction" View:** Showing an empty/cracked jar when the budget is exceeded.

---

### 🛠️ Technical Details for Upload
- **Package Name:** `com.chirag.scrolltoll`
- **Minimum SDK:** API 23 (Android 6.0)
- **Target SDK:** API 35 (Android 15)
- **Version:** 1.0.0+1
- **Permission required:** `PACKAGE_USAGE_STATS` (Device Usage Access)

### 📂 How to build the .aab
To generate the final app bundle for upload:
1. Open terminal in the project root.
2. Run: `flutter build appbundle --release`
3. The file will be at: `build/app/outputs/bundle/release/app-release.aab`

---

*Note: For the final Play Store upload, you MUST sign the app bundle with your own developer JKS key in Android Studio.*
