# ECall iOS

End-to-end encrypted (E2EE) video & audio calling — open source.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![iOS](https://img.shields.io/badge/iOS-16.6%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)

## Features

- 🔒 **End-to-End Encryption** — RSA-2048 key exchange + AES-256-GCM media encryption
- 📞 **Video & Audio Calls** — High-quality calls powered by WebRTC
- 👥 **Group Calls** — Multiple participants with E2EE
- 🔐 **Multiple Auth** — Email, Phone, Google Sign-in, Sign in with Apple
- 🌍 **Multi-language** — 15+ languages
- 📱 **CallKit** — Native iOS call UI integration
- 🎨 **White-Label** — Full branding customization for partners

## Requirements

- **iOS** 16.6+
- **Xcode** 16.2+
- **macOS** 14.0+ (Sonoma)
- **CocoaPods** for dependency management

## Quick Start

```bash
# 1. Clone
git clone https://github.com/ProjectSuite/e2e-call-ios.git
cd e2e-call-ios

# 2. Install dependencies
pod install

# 3. Configure credentials
cp Config.local.example.xcconfig Config.local.xcconfig
# Edit Config.local.xcconfig with your API credentials

# 4. Open in Xcode (always .xcworkspace, NOT .xcodeproj)
open ecall.xcworkspace
```

> ⚠️ **Never commit `Config.local.xcconfig`** — it's gitignored and contains your private API credentials.

## Configuration

### Config.local.xcconfig

All partner-specific credentials are managed via `Config.local.xcconfig`:

```xcconfig
SLASH = /

APP_API_ID = your_api_id
APP_API_HASH = your_api_hash
BASE_DOMAIN = your_app.org
BUNDLE_URL_SCHEME = your_bundle_url_scheme
GOOGLE_CLIENT_ID = your_google_client_id.apps.googleusercontent.com
GOOGLE_URL_SCHEME = com.googleusercontent.apps.your_google_client_id
SHARE_URL = https:$(SLASH)/your_app_url
```

> **URL Note**: `//` is a comment in xcconfig. Use `https:$(SLASH)/domain.com` instead.

Values are injected into Build Settings via the xcconfig include chain:
```
Config/[Env].xcconfig → Pods xcconfig + Config.local.xcconfig
```

### What Partners Can Customize

| Customizable | Not Customizable |
|-------------|------------------|
| App name & icon | API endpoints |
| Bundle ID | WebSocket / Janus URLs |
| API credentials | E2EE encryption logic |
| Google / Apple sign-in | Call signaling flow |
| Share URL & domain | Certificate pinning |
| Branding & localization | Background modes |

See [Partner Technical Reference](docs/partner/partner-technical.md) for full details.

## Architecture

```
App Layer (SwiftUI)
    ↓
Modules (Auth, Call, Contacts, Settings)
    ↓
Core (Security, Networking, Persistence, Language)
```

### Key Technologies

| Technology | Purpose |
|-----------|---------|
| **SwiftUI** | Declarative UI |
| **WebRTC** | Real-time communication |
| **CallKit** | Native iOS call integration |
| **Swift 6** | Modern concurrency (`async/await`) |
| **CocoaPods** | Dependency management |

## Security

- **E2EE**: All media encrypted end-to-end
- **Key Exchange**: P-256 ECDH (Secure Enclave) / RSA-2048 fallback
- **Media Encryption**: AES-256-GCM
- **Key Storage**: iOS Keychain (Secure Enclave-backed)
- **Zero Server Access**: Server cannot decrypt media
- **Certificate Pinning**: Enforced in Staging/Production

## Documentation

### For Partners

- [**Partner Onboarding Guide**](docs/partner/partner-onboarding.md) — Step-by-step from registration to deployment
- [**Partner Technical Reference**](docs/partner/partner-technical.md) — Xcode config, branding, troubleshooting

### Open Source Community

- [**Contributing**](docs/partner/git-outsource/CONTRIBUTING.md) — How to contribute
- [**Code of Conduct**](docs/partner/git-outsource/CODE_OF_CONDUCT.md) — Community guidelines
- [**Security Policy**](docs/partner/git-outsource/SECURITY.md) — Reporting vulnerabilities
- [**Changelog**](docs/partner/git-outsource/CHANGELOG.md) — Version history

## Contributing

We welcome contributions! Please read [CONTRIBUTING.md](docs/partner/git-outsource/CONTRIBUTING.md) before submitting a PR.

```bash
# Fork → Clone → Branch → Code → Test → PR
git checkout -b feature/your-feature
# Make changes...
git commit -m "feat: description"
git push origin feature/your-feature
```

### Rules

1. **Never commit credentials** — use `Config.local.xcconfig`
2. **Do NOT modify** E2EE, SSL pinning, or signaling logic
3. **Test on real device** — Push/VoIP requires physical device
4. **Follow Swift conventions** — Swift 6 concurrency, `@MainActor`

## License

MIT License — see [LICENSE](docs/partner/git-outsource/LICENSE).

## Support

- **Email**: support@airfeedkh.com
- **Portal**: https://ecall.org/
- **Docs**: https://docs.ecall.org/

---

**Made with ❤️ by the ECall team**
