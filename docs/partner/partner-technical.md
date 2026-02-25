# Partner Technical Reference

Technical reference for Xcode configuration, branding, troubleshooting, and compliance.

> **Start here first:** [Partner Onboarding Guide](./partner-onboarding.md) — Step-by-step from registration to deployment.
> This document provides deeper technical context for the setup described there.

---

## Prerequisites

### Required Software

- **Xcode**: 16.2 or later
- **macOS**: macOS 14.0 (Sonoma) or later
- **CocoaPods**: For dependency management
- **Git**: For cloning repository

### Required Accounts

- **Apple Developer Account**: Active membership ($99/year)
- **Partner API Credentials**: `APP_API_ID` and `APP_API_HASH` from Partner Dashboard
- **Repository Access**: Access to ECall source code repository

---

## Project Setup

### Clone & Install

```bash
git clone https://github.com/ProjectSuite/e2e-call-ios.git
cd e2e-call-ios
pod install
```

> ⚠️ Always open `ecall.xcworkspace`, NOT `ecall.xcodeproj`.

---

## Configuration

### Configuration Responsibility Matrix

#### Partner-provided (via `Config.local.xcconfig`)

| Key | Description |
|-----|-------------|
| `APP_API_ID` | Partner API ID from ECall Dashboard |
| `APP_API_HASH` | Partner API Hash from ECall Dashboard |
| `BASE_DOMAIN` | Primary domain shown to users |
| `BUNDLE_URL_SCHEME` | Deep link URL scheme (recommended: match bundle ID) |
| `GOOGLE_CLIENT_ID` | From partner's Google Cloud Console |
| `GOOGLE_URL_SCHEME` | Reversed Google Client ID |
| `SHARE_URL` | Public share URL for invitations |

#### Partner-provided (via Xcode Build Settings)

| Key | Description |
|-----|-------------|
| `PRODUCT_BUNDLE_IDENTIFIER` | App Store bundle ID (e.g., `com.partner.ecall`) |
| `INFOPLIST_KEY_CFBundleDisplayName` | App display name shown under icon |
| `DEVELOPMENT_TEAM` | Apple Developer Team ID |

#### Fixed by ECall system (do NOT modify)

| Key | Description |
|-----|-------------|
| `API_BASE_URL` | Backend API endpoint per environment |
| `SOCKET_BASE_URL` | WebSocket endpoint |
| `JANUS_SOCKET_URL` | WebRTC signaling server |
| `JANUS_API_SECRET` | Janus authentication |
| `ENVIRONMENT_NAME` | Dev / Staging / Production |

### Xcconfig Include Chain

```
Config/[Env].xcconfig
  → #include  Pods-ecall.[env].xcconfig   (CocoaPods settings)
  → #include? Config.local.xcconfig        (partner secrets, gitignored)
```

Values in `Config.local.xcconfig` override the placeholders in Build Settings. See [Onboarding §4.1](./partner-onboarding.md#41-configure-api-credentials-via-configlocalxcconfig) for setup instructions.

> ⚠️ **URL Note**: In `.xcconfig` files, `//` is treated as a comment.
> Always use `https:$(SLASH)/domain.com/path` for URLs (define `SLASH = /` first).

---

## Branding Configuration

### Brand Name Checklist

The name **"Ecall"** appears in several places across the project. Partners must update all of them:

#### Build Settings (per target configuration: Dev / Staging / Production)

| Setting | Current Value | Where |
|---------|---------------|-------|
| `INFOPLIST_KEY_CFBundleDisplayName` | `Ecall` | App name under icon |
| `PRODUCT_BUNDLE_IDENTIFIER` | `com.airfeed.ecall.staging` / `com.airfeed.ecall` | App Store identifier |
| `INFOPLIST_KEY_NSFaceIDUsageDescription` | "**Ecall** uses biometric authentication..." | Face ID permission popup |
| `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` | "**Ecall** needs access to your photo library..." | Photo Library permission popup |

> 💡 These are set in **Xcode → Target → Build Settings → Info Plist Values**, NOT directly in Info.plist.

#### Entitlements (`ecall/Entitlements/`)

| File | Key | Current Value | Update to |
|------|-----|---------------|-----------|
| `Staging.entitlements` | Associated Domains | `applinks:app.ecall.org` | `applinks:app.yourdomain.com` |
| `Production.entitlements` | Associated Domains | `applinks:app.ecall.org` | `applinks:app.yourdomain.com` |

#### Info.plist (runtime strings)

| Key | Current Value |
|-----|---------------|
| `NSUserNotificationsUsageDescription` | "Ecall needs notification permissions..." |

> ⚠️ This string is hardcoded in `ecall/Info.plist` and must be edited directly.

### App Icon

1. Prepare a single **1024×1024px** PNG icon (Xcode auto-generates all required sizes)
2. Open `ecall/Resources/Assets.xcassets` → `AppIcon`
3. Drag your icon into the **All Sizes** slot
4. Clean build (**⌘⇧K**) to clear cached icons

### Launch Screen

1. Open `ecall/App/LaunchScreen.storyboard`
2. Replace the logo in `Assets.xcassets/LogoNoBg` with your brand logo
3. Customize background color if needed

> 💡 Use a single PDF with **Preserve Vector Data** enabled for best quality across all screen sizes. Alternatively, provide @2x and @3x PNGs.

### Localization

1. Open `ecall/Resources/Localized/Localizable.xcstrings`
2. Search for brand-specific strings and update
3. Add new languages via Xcode's localization editor

---

## Signing & Capabilities

### Signing Setup

1. Select target `ecall` → **Signing & Capabilities**
2. Set **Team** to your Apple Developer account
3. **Code Signing Style**: Automatic (for development) or Manual (for CI/CD)

### Required Capabilities

The project already has these configured in the entitlements files (`ecall/Entitlements/`):

| Capability | Purpose |
|------------|---------|
| **Push Notifications** | Standard push + VoIP push |
| **Background Modes** | Voice over IP, Background fetch, Remote notifications, Audio |
| **Associated Domains** | Universal links (`applinks:$(BASE_DOMAIN)`) |

> Partners must update the Associated Domains to match their `BASE_DOMAIN`.

---

## Building

### Development Build

1. Select **Staging** scheme
2. Select a physical iOS device (Push/VoIP requires a real device)
3. Press **⌘ + R**

### Archive Build (Distribution)

1. Select **Production** scheme
2. Set destination to **Any iOS Device**
3. **Product → Archive → Distribute App**

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `No such module 'WebRTC'` | Run `pod install`, open `.xcworkspace` not `.xcodeproj` |
| Signing errors | Set your Team in Signing & Capabilities, Clean build (**⌘⇧K**) |
| Bundle ID conflict | Use a unique reverse-domain bundle identifier |
| Config.local.xcconfig not applied | Verify `baseConfigurationReference` in `.pbxproj` points to `Config/*.xcconfig` |
| URL values truncated (e.g., `https:`) | Use `$(SLASH)` variable — `//` is a comment in xcconfig |
| Push not received | Verify APNs/VoIP certs uploaded to dashboard, test on real device |
| CallKit not showing | Ensure VoIP Push certificate is valid, check Background Modes |

---

## Security

### Credential Storage

1. **Never commit credentials to Git** — `Config.local.xcconfig` is already gitignored
2. **Use `Config.local.xcconfig`** — All partner secrets go here
3. **Per-developer** — Each developer creates their own copy from `Config.local.example.xcconfig`

### Certificate Pinning

Implemented via `ecall/Core/Security/SSLPinningManager.swift`:
- **Dev**: Pinning disabled
- **Staging / Production**: Pinning enforced

> Do not modify pinning logic. Coordinate with ECall team for certificate rotation.

---

## Deployment

### App Store Connect

1. Create app record with matching bundle ID
2. Complete app information (name, description, screenshots)
3. Provide privacy policy URL
4. Archive and upload build via Xcode or Transporter
5. Submit for review

---

## Compliance

### Privacy Requirements

- **Privacy Policy**: Required for App Store submission
- **Data Handling**: Clear disclosure of data usage
- **E2EE Disclosure**: Apple may flag encryption — provide proper export compliance

### Security Requirements

- **E2EE must be maintained** — do not disable or bypass
- **Certificate Pinning** — do not modify for production builds
- **Key Management** — handled by ECall SDK, do not modify

---

## FAQ

**Q: Can I modify the source code?**
A: Yes, following the project's license terms.

**Q: Can I use my own backend server?**
A: No. Partner builds connect to the shared ECall infrastructure.

**Q: What if credentials are compromised?**
A: Contact support immediately to revoke and regenerate.

**Q: What iOS version is supported?**
A: Minimum deployment target is iOS 16.6.

**Q: Where do I put my API credentials?**
A: In `Config.local.xcconfig`. See [Onboarding Guide §4.1](./partner-onboarding.md#41-configure-api-credentials-via-configlocalxcconfig).

---

## Contact

- **Email**: support@airfeedkh.com
- **Portal**: https://ecall.org/
- **Documentation**: https://docs.ecall.org/
