# Partner Technical Reference

Technical reference for Xcode setup, branding, troubleshooting, and compliance.

> **Start here first:** [Partner Onboarding Guide](./partner-onboarding.md) - Step-by-step from registration to deployment

---

## Partner Program Overview

### What is a Partner?

A partner is an organization, company, or reseller that:
- Wants to offer E2EE calling services under their own brand
- Requires custom branding (app name, logo, bundle ID)
- Needs independent API credentials for their user base

### Partner Benefits

- **White-Label Solution**: Full customization of app branding and identity
- **Independent User Base**: Separate user accounts and data per partner
- **Custom Bundle ID**: Deploy to App Store with your own identifier
- **API Credentials**: Unique `APP_API_ID` and `APP_API_HASH` for security
- **Full E2EE**: Complete end-to-end encryption for all calls
- **Source Code Access**: Open-source codebase for transparency

---

## Prerequisites

### Required Software

- **Xcode**: Latest stable version (14.0+ recommended)
- **macOS**: macOS 12.0 or later
- **CocoaPods**: For dependency management
- **Git**: For cloning repository

### Required Accounts

- **Apple Developer Account**: Active membership ($99/year)
- **Partner API Credentials**: APP_API_ID and APP_API_HASH from partner program
- **GitHub Access**: Access to ECall source code repository

---

## Project Setup

### Clone Repository

```bash
git clone https://github.com/your-org/e2ecall-ios.git
cd e2ecall-ios
```

### Install Dependencies

```bash
# Install CocoaPods if not already installed
sudo gem install cocoapods

# Install dependencies
pod install
```

**Note**: Always open `ecall.xcworkspace`, not `ecall.xcodeproj` after running `pod install`.

---

## Xcode Configuration

### Bundle Identifier Setup

1. Select project in Project Navigator
2. Select target `ecall`
3. Go to **General** tab
4. Update **Bundle Identifier**: `com.yourcompany.ecall`
5. Update **Display Name**: `YourAppName`

**Recommended Format**: `com.[company].[appname]`

### Configuration Responsibility Matrix

#### Partner-provided (per cloned app)
- **Apple account & bundle identifiers**
  - `PRODUCT_BUNDLE_IDENTIFIER` (e.g., `com.partner.brandcall`)
  - App display name
- **Partner API credentials**
  - `APP_API_ID`
  - `APP_API_HASH`
- **URL schemes and client IDs**
  - `BUNDLE_URL_SCHEME` (recommended: derived from bundle ID)
  - `GOOGLE_CLIENT_ID` (from partner Google Cloud Console)
  - `GOOGLE_URL_SCHEME`
- **Partner-visible URLs**
  - `SHARE_URL` (public share URL)
  - `BASE_DOMAIN` (primary domain shown to users)

#### Fixed by ECall system (do not modify)
- `API_BASE_URL`
- `SOCKET_BASE_URL`
- `JANUS_SOCKET_URL`
- `ENVIRONMENT_NAME` (Dev / Staging / Production)
- `MTL_ENABLE_DEBUG_INFO`
- `MTL_FAST_MATH`

### API Credentials Configuration

**Method 1: Build Settings (Recommended)**

1. Select project → target `ecall` → **Build Settings**
2. Click **+** → **Add User-Defined Setting**
3. Add:
   ```
   APP_API_ID = 12345678
   APP_API_HASH = a1b2c3d4e5f6g7h8
   ```

**Method 2: Configuration Files**

1. Create `Config.plist` (add to `.gitignore`)
2. Load in code:
   ```swift
   if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
      let config = NSDictionary(contentsOfFile: path) {
       let apiId = config["APP_API_ID"] as? String
   }
   ```

---

## Branding Configuration

### App Icon

1. Prepare assets (1024x1024px for App Store)
2. Open `Assets.xcassets` → Select `AppIcon`
3. Required sizes: 20x20, 29x29, 40x40, 60x60, 76x76, 83.5x83.5, 1024x1024

### Launch Screen

1. Open `LaunchScreen.storyboard`
2. Customize: Add logo, update colors, modify layout

### App Name

Update `CFBundleDisplayName` in Info.plist:
```xml
<key>CFBundleDisplayName</key>
<string>YourAppName</string>
```

### Localization

1. Open `Localizable.xcstrings`
2. Update strings for your brand
3. Add new languages if needed

---

## Certificates and Provisioning

### Automatic Signing (Recommended)

1. Project → target → **Signing & Capabilities**
2. Enable **Automatically manage signing**
3. Select your **Team**

### Required Capabilities

Enable in **Signing & Capabilities**:
- **Push Notifications**
- **Background Modes**: Voice over IP, Background fetch, Remote notifications
- **CallKit**
- **Audio, AirPlay, and Picture in Picture**
- **Camera**, **Microphone**

---

## Building the App

### Development Build

1. Select **ecall** scheme
2. Select target device
3. Press **⌘ + R**

### Archive Build (for Distribution)

1. Select **Any iOS Device** as target
2. **Product** → **Archive**
3. **Distribute App** → Choose method (App Store Connect, Ad Hoc, etc.)

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "No such module 'WebRTC'" | Run `pod install`, open `.xcworkspace` |
| "Signing requires development team" | Add Apple Developer team in Signing & Capabilities |
| "Bundle identifier already in use" | Use unique bundle identifier |
| API credentials not working | Verify credentials, check Info.plist/build settings |
| Push notifications not working | Verify APNs/VoIP certs, check capabilities, test on device |
| Code signing errors | Clean build (⌘ + Shift + K), verify certs in Keychain |

---

## Security

### Credential Storage

1. **Never commit credentials to Git** - Add to `.gitignore`
2. **Separate by environment** - Use build configurations
3. **Access control** - Limit to authorized developers

### Certificate Pinning

Already implemented via `Core/Security/SSLPinningManager.swift`:
- **Dev**: Pinning disabled
- **Staging/Production**: Pinning enforced

**Partner guidance**: Do not modify pinning logic. Coordinate with ECall team for certificate rotation.

---

## Deployment

### App Store Connect

1. Create app with matching bundle ID
2. Complete app information (name, description, screenshots)
3. Provide privacy policy URL
4. Archive and upload build
5. Submit for review

### Version Management

```bash
agvtool next-version -all
agvtool new-version -all $VERSION_NUMBER
```

---

## Maintenance

### Updating Dependencies

```bash
pod update
```

### Updating Source Code

```bash
git pull origin main
pod install
```

---

## Compliance and Legal

### Privacy Requirements

- **Privacy Policy**: Required for App Store submission
- **GDPR Compliance**: For EU users
- **Data Handling**: Clear disclosure of data usage

### Security Compliance

- **E2EE**: Must be maintained
- **Key Management**: Secure key storage
- **Certificate Pinning**: Recommended for production

---

## Pricing and Licensing

### Partner Agreement

Partners must agree to:
- Terms of service and usage policy
- E2EE security requirements
- Data handling and privacy compliance

### Open Source License

ECall source code is open source (check LICENSE file):
- Partners can modify and customize code
- Must comply with license terms

---

## FAQ

**Q: Can I modify the source code?**
A: Yes, following license terms.

**Q: Can I use my own backend server?**
A: No, partner builds connect to shared ECall infrastructure.

**Q: What if credentials are compromised?**
A: Contact support immediately to revoke and regenerate.

**Q: What iOS version is required?**
A: Minimum iOS 16.6+

---

## Contact

- **Email**: support@airfeedkh.com
- **Portal**: http://web.ecall.org/
- **Documentation**: https://docs.ecall.org/
