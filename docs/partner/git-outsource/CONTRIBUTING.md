# Contributing to ECall iOS

Thank you for your interest in contributing to ECall iOS! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold this code.

## How to Contribute

### Reporting Bugs

Before reporting a bug:
1. Check if the issue already exists in [GitHub Issues](https://github.com/your-org/ecall-ios/issues)
2. Search closed issues to see if it was already fixed

When reporting a bug:
- Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md)
- Include iOS version, device model, and app version
- Provide steps to reproduce
- Include relevant logs or screenshots
- Describe expected vs actual behavior

### Suggesting Features

We welcome feature suggestions! To suggest a feature:
1. Open a GitHub Issue with the "Feature Request" label
2. Clearly describe the use case and benefits
3. Discuss the proposal before implementing
4. Consider security and E2EE implications

### Pull Requests

#### Before You Start

1. **Fork the repository**
2. **Create a branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Read the documentation**:
   - [Authentication Overview](../../dev/authentication/overview.md)
   - [Calls Overview](../../dev/calls/overview.md)
   - Relevant module documentation

#### Development Process

1. **Make your changes**
   - Follow code style guidelines (see below)
   - Write self-documenting code
   - Add comments for complex logic

2. **Write or update tests**
   - Unit tests for new features
   - Integration tests for critical paths
   - Ensure all tests pass

3. **Update documentation**
   - Update relevant docs in `docs/`
   - Add code comments if needed
   - Update CHANGELOG.md if applicable

4. **Test thoroughly**
   - Test on physical device when possible
   - Test on multiple iOS versions
   - Test edge cases and error scenarios

5. **Commit your changes**
   ```bash
   git commit -m "Add: Description of your changes"
   ```
   - Use clear, descriptive commit messages
   - Follow conventional commits format (optional but preferred):
     - `Add:` for new features
     - `Fix:` for bug fixes
     - `Update:` for updates
     - `Refactor:` for refactoring
     - `Docs:` for documentation

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Open a Pull Request**
   - Use the [PR template](.github/pull_request_template.md)
   - Link related issues
   - Request review from maintainers
   - Respond to feedback promptly

#### PR Review Process

- Maintainers will review your PR
- Address review comments
- Keep PR focused and reasonably sized
- Update PR if requested
- Squash commits if needed before merge

## Code Style Guidelines

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use Swift 6 concurrency features (`async/await`, `@MainActor`)
- Prefer `let` over `var`
- Use meaningful variable and function names
- Keep functions focused and small

### Formatting

- Use 4 spaces for indentation
- Maximum line length: 120 characters
- Use SwiftFormat or SwiftLint (see below)

### Architecture

- Follow existing module structure
- Keep Core layer independent
- Use dependency injection where appropriate
- Maintain separation of concerns

### Security

- **Never commit secrets or credentials**
- Use Keychain for sensitive data
- Follow E2EE best practices
- Validate all inputs
- Handle errors securely

### Example

```swift
// Good
func fetchUserProfile(userId: String) async throws -> UserProfile {
    guard !userId.isEmpty else {
        throw APIError.invalidUserId
    }
    
    return try await apiClient.request(
        endpoint: .userProfile(userId: userId)
    )
}

// Bad
func get(u: String) -> User? {
    // Missing error handling, unclear naming
    return api.getUser(u)
}
```

## Testing

### Unit Tests

- Write tests for new features
- Aim for good test coverage
- Test edge cases and error scenarios
- Use descriptive test names

### Integration Tests

- Test critical user flows
- Test E2EE encryption/decryption
- Test network error handling
- Test authentication flows

### Running Tests

```bash
# Run all tests
xcodebuild test -workspace ecall.xcworkspace \
                -scheme ecall \
                -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run specific test
xcodebuild test -workspace ecall.xcworkspace \
                -scheme ecall \
                -only-testing:ecall/YourTestClass
```

## Code Quality Tools

### SwiftLint

We use SwiftLint for code quality. Run before committing:

```bash
# Install SwiftLint
brew install swiftlint

# Run SwiftLint
swiftlint lint

# Auto-fix issues
swiftlint --fix
```

### SwiftFormat

Optional but recommended:

```bash
# Install SwiftFormat
brew install swiftformat

# Format code
swiftformat .
```

## Documentation

### Code Documentation

- Document public APIs
- Add comments for complex algorithms
- Explain "why" not just "what"
- Keep comments up-to-date

### Documentation Updates

When adding features:
- Update relevant docs in `docs/`
- Add examples if helpful
- Update architecture diagrams if needed
- Keep documentation in sync with code

## Security Contributions

### Reporting Security Issues

**DO NOT** report security vulnerabilities publicly. See [SECURITY.md](SECURITY.md) for:
- How to report vulnerabilities
- What information to include
- Response timeline

### Security Best Practices

When contributing security-related code:
- Follow E2EE implementation guidelines
- Use secure key storage (Keychain)
- Never log sensitive data
- Validate all cryptographic operations
- Get security review for major changes

## Partner-Specific Contributions

If you're contributing as a partner:
- Follow same guidelines as other contributors
- Test with your API credentials
- Document any partner-specific changes
- Consider impact on other partners

## Getting Help

### Questions?

- Check [documentation](docs/)
- Search [GitHub Issues](https://github.com/your-org/ecall-ios/issues)
- Ask in [GitHub Discussions](https://github.com/your-org/ecall-ios/discussions)
- Contact maintainers (for sensitive questions)

### Stuck?

- Review similar PRs or issues
- Check existing code for patterns
- Ask for help in discussions
- Request clarification on issues

## Recognition

Contributors will be:
- Listed in CONTRIBUTORS.md (if we maintain one)
- Credited in release notes
- Acknowledged in the project

Thank you for contributing to ECall iOS! 🎉

