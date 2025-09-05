# Xcode Setup Instructions

## Fix "Missing bundle ID" Error

The error occurs because Xcode needs a development team configured for code signing. Here's how to fix it:

### Option 1: Set Development Team in Xcode (Recommended)

1. Open `translateMd.xcodeproj` in Xcode
2. Select the project in the navigator (top-level "translateMd")
3. Select the "translateMd" target
4. Go to the "Signing & Capabilities" tab
5. Under "Team", select your Apple ID or development team
   - If you don't see your team, click "Add Account..." to sign in with your Apple ID
   - For personal development, your Apple ID will work fine

### Option 2: Use Manual Code Signing (Advanced)

1. In Xcode project settings, change "Automatically manage signing" to OFF
2. Set "Provisioning Profile" to "iOS Team Provisioning Profile: com.ashavolian.translateMd"
3. Set "Code Signing Identity" to "Apple Development"

### Option 3: Change Bundle Identifier

If you want to use a different bundle identifier:

1. In Xcode project settings, under "General" tab
2. Change "Bundle Identifier" from `com.ashavolian.translateMd` to something like:
   - `com.yourname.translateMd`
   - `com.yourcompany.translateMd`

### Testing on Device vs Simulator

- **Simulator**: No code signing needed, but microphone won't work
- **Physical Device**: Requires proper code signing and development team

### Quick Fix Command

You can also run this to get your Apple Developer Team ID:
```bash
# List available teams
xcrun simctl list devicetypes
# Or check your keychain
security find-identity -v -p codesigning
```

Then update the project file with your team ID if needed.
