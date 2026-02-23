# ECall iOS

End-to-end encrypted (E2EE) video/audio calling application for iOS.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![iOS](https://img.shields.io/badge/iOS-16.6%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)

## Features

- 🔒 **End-to-End Encryption**: RSA-2048 key exchange + AES-256-GCM media encryption
- 📞 **Video & Audio Calls**: High-quality calls powered by WebRTC
- 👥 **Group Calls**: Support for multiple participants
- 🔐 **Multiple Auth Methods**: Email, Phone, Google Sign-in, Sign in with Apple
- 🌍 **Multi-language**: Support for 15+ languages
- 🔄 **Rejoin Calls**: Reconnect to active calls after disconnection
- 📱 **Native Integration**: CallKit integration for seamless iOS experience
- 🎨 **White-Label Ready**: Customizable branding for partners/resellers

## Requirements

- **iOS**: 16.6 or later
- **Xcode**: 14.0 or later
- **CocoaPods**: For dependency management
- **Apple Developer Account**: Required for distribution (development/testing can use free account)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/ecall-ios.git
cd ecall-ios
```

### 2. Install Dependencies

```bash
# Install CocoaPods if not already installed
sudo gem install cocoapods

# Install dependencies
pod install
```

### 3. Open Workspace

```bash
# Always open .xcworkspace, not .xcodeproj
open ecall.xcworkspace
```

### 4. Configure API Credentials

For partners/resellers, configure your API credentials:

1. Create `Config.plist` from template (see [Configuration](#configuration))
2. Add your `APP_API_ID` and `APP_API_HASH`
3. Or use build settings (see [Partner Build Guide](docs/technical/partner-build-guide.md))

### 5. Build and Run

1. Select your target device or simulator
2. Press `⌘ + R` or click **Run**
3. App will build and launch

## Configuration

### For Partners/Resellers

If you're a partner with API credentials:

1. Copy the example config:
   ```bash
   cp Config.example.plist Config.plist
   ```

2. Edit `Config.plist` with your credentials:
   - `APP_API_ID`: Your partner API ID
   - `APP_API_HASH`: Your partner API hash

3. **Never commit** `Config.plist` to version control!

See [Partner Setup Guide](docs/business/partner-setup.md) for complete setup instructions.

### For Developers

For development/testing, you can:
- Use mock/test credentials
- Set up local backend server
- Use development environment endpoints

## Documentation

### For Developers

- **[Architecture Overview](docs/technical/architecture.md)** - System architecture and design
- **[Core Modules](docs/technical/core-modules.md)** - Security, Networking, Persistence modules
- **[Call Module](docs/technical/call-module.md)** - WebRTC and E2EE implementation
- **[Authentication Flow](docs/technical/authentication-flow.md)** - Auth implementation details

### For Partners/Resellers

- **[Partner Setup Guide](docs/business/partner-setup.md)** - Business guide for partners
- **[Partner Build Guide](docs/technical/partner-build-guide.md)** - Technical build instructions
- **[Business Requirements](docs/business/business-requirements.md)** - Feature requirements
- **[User Flows](docs/business/user-flows.md)** - Application user flows

### Contributing

- **[Contributing Guidelines](CONTRIBUTING.md)** - How to contribute to the project
- **[Code of Conduct](CODE_OF_CONDUCT.md)** - Community guidelines
- **[Security Policy](SECURITY.md)** - Security reporting guidelines

## Architecture

ECall iOS follows a modular architecture:

```
App Layer (SwiftUI)
    ↓
Modules Layer (Authentication, Call, Contacts, Settings)
    ↓
Core Layer (Security, Networking, Persistence, Language)
```

### Key Technologies

- **SwiftUI**: Modern declarative UI framework
- **WebRTC**: Real-time communication
- **CallKit**: Native iOS call integration
- **Swift 6**: Latest Swift concurrency features
- **CocoaPods**: Dependency management

## Security

- **E2EE**: All media is encrypted end-to-end
- **Key Management**: RSA-2048 keys stored securely in Keychain
- **No Server Access**: Server cannot decrypt media data
- **Secure Storage**: Private keys never leave the device

See [Security Policy](SECURITY.md) for reporting vulnerabilities.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Code of conduct
- Development setup
- Pull request process
- Code style guidelines
- Testing requirements

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

### For Users
- **Documentation**: See [docs/](docs/) directory
- **Issues**: Report bugs via [GitHub Issues](https://github.com/your-org/ecall-ios/issues)

### For Partners
- **Partner Portal**: Access your partner dashboard
- **Email**: partners@ecall.example.com
- **Documentation**: [Partner Setup Guide](docs/business/partner-setup.md)

### For Contributors
- **Discussions**: Join [GitHub Discussions](https://github.com/your-org/ecall-ios/discussions)
- **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md)

## Acknowledgments

- WebRTC community
- All contributors and partners
- Open source libraries and tools

## Roadmap

- [ ] Screen sharing support
- [ ] Call recording (with consent)
- [ ] Enhanced multi-device support
- [ ] Performance optimizations
- [ ] Additional language support

See [GitHub Issues](https://github.com/your-org/ecall-ios/issues) for current development priorities.

---

**Made with ❤️ by the ECall team**

