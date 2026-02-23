# ECall Partner Onboarding Guide

Step-by-step guide from account registration to iOS app deployment.

> **Need more details?** See [Partner Technical Reference](./partner-technical.md) for Xcode setup, troubleshooting, branding, and compliance.

---

## Target Audience

- iOS developers integrating ECall open-source for a branded app
- Technical partners with Apple Developer accounts

## Prerequisites

- You own an Apple Developer Account
- You can build and run iOS apps using Xcode

---

## 1. Register Partner Account

### Action

1. Open the registration page:
   - 👉 http://web.ecall.org/auth/registration

2. Fill in the following fields:
   - **Email**: Partner email address
   - **Password / Confirm Password**
   - **App Title**: Full application name
   - **App Short Name**: Short, unique identifier (no spaces)

3. Click **Register**

4. Verify OTP

### Expected Result

- Partner account is created successfully
- You can log in to the ECall web dashboard

---

## 2. Create Apple Certificates (Local CSR → Apple Developer Portal)

This step creates the required Apple certificates used for Sign in with Apple, Push Notification and VoIP Push, which are mandatory for incoming calls (CallKit).

### 2.1 Create Sign in with Apple Key (.p8)

This section creates the Apple Authentication Key used for Sign in with Apple.

#### Action

1. Go to Apple Developer Portal
   - 👉 https://developer.apple.com/account

2. Navigate to:
   - **Certificates, Identifiers & Profiles → Keys**

3. Click **+** to create a new key

4. Enter:
   - **Key Name**: Example: `Ecall Sign In`

5. Enable service:
   - ✅ **Sign in with Apple**

6. Click **Continue → Register**

7. Download the key file: `AuthKey_XXXXXXXXXX.p8`

> ⚠️ **Important**
> - `.p8` file can be downloaded only once
> - Apple does not store it
> - Back it up immediately in a secure location

---

### 2.2 Create Certificate Signing Request (CSR) on macOS

#### Action

1. Open **Keychain Access**

2. From the menu bar, select:
   - **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority…**

3. Fill in the form:
   - **User Email Address**: Your Apple ID email
   - **Common Name**: Company or app name (e.g. `YourCompany`)
   - **CA Email Address**: (leave empty)

4. Under **Request is**, select:
   - ✅ **Saved to disk**

5. Click **Continue**

6. Save the file (example): `ApplePushCertRequest.certSigningRequest`

#### Expected Result

- A `.certSigningRequest` (CSR) file is created on your machine
- This file will be uploaded to Apple Developer Portal in the next step

> ⚠️ **Important**
> Do NOT choose "Emailed to the CA".
> Always use **Saved to disk** for Apple certificates.

---

### 2.3 Create Push Notification Certificate on Apple Developer Portal

#### Action

1. Go to Apple Developer Certificates page:
   - 👉 https://developer.apple.com/account/resources/certificates/add

2. Under **Services**, select:
   - ✅ **Apple Push Notification service SSL (Sandbox & Production)**

3. Click **Continue**

4. Choose **App ID** (bundle app)

5. Upload the CSR file created in Step 2.2

6. Click **Continue → Download**

#### Expected Result

- A Push certificate (`aps.cer`) is downloaded
- This certificate supports both Sandbox & Production
- It will be used for standard push notifications

---

### 2.4 Create VoIP Push Certificate

#### Action

1. Repeat the same process:
   - Go to **Certificates → Add**

2. Select:
   - ✅ **VoIP Services Certificate**

3. Choose **Same App ID** (bundle app)

4. Upload the same CSR file

5. Download the VoIP certificate

#### Expected Result

- A VoIP Services certificate (`voip.cer`) is downloaded
- This certificate is required for CallKit incoming calls

> 📞 **Without VoIP Push, incoming calls will not wake the app in background.**

---

### 2.5 Install Certificates & Export .p12

#### Action

1. Double-click each downloaded `.cer` file to install into Keychain Access

2. Open **Keychain Access**

3. Locate the certificate + private key pair:
   - Apple Push Services
   - VoIP Services

4. Click the **▼ (disclosure arrow)** to expand the certificate.

5. **Select both rows at the same time**:
   - the **certificate** row (e.g. `Apple Push Services: <bundle id>` / `VoIP Services: <bundle id>`)
   - the **private key** row under it (e.g. `… private key`)

6. Right-click (or Control-click) on the selection → **Export 2 items…**

7. Export as:
   - `push_cert.p12`
   - `voip_cert.p12`

6. Set and remember a password for each `.p12`

#### Expected Result

- You have:
  - `push_cert.p12`
  - `voip_cert.p12`
- Passwords are known and ready for upload

---

### 2.6 Upload Certificates to ECall Partner Dashboard

#### Action

1. Go back to ECall Partner Dashboard

2. Navigate to **Account → Settings → Apple Configuration**

3. Upload:
   - Apple Push Cert (`.p12`) + password
   - Apple VoIP Cert (`.p12`) + password

#### Expected Result

- Apple Push & VoIP services are fully configured
- Incoming call notifications will work correctly

---

## 3. Retrieve API Credentials & Configure Apple Integration

This step collects all credentials required for iOS integration, including ECall API credentials and Apple authentication & push certificates.

### 3.1 Retrieve ECall API Credentials

#### Action

1. Log in to the Partner Dashboard

2. Navigate to:
   - **Account → Settings**
   - 👉 http://web.ecall.org/admin/profile/settings

3. In **App Configuration**, copy the following values:
   - **API ID**
   - **API Hash**

#### Expected Result

- You have both:
  - `APP_API_ID`
  - `APP_API_HASH`
- These credentials will be used in the iOS project to authenticate with the ECall backend

> 🔒 **Security Notice**
> - API ID and API Hash are sensitive credentials
> - Do NOT commit them to GitHub
> - Do NOT hardcode them in source code
> - Store them only in:
>   - Xcode Build Settings (User-Defined)

---

### 3.2 Upload Apple Credentials to ECall Partner Dashboard

This step binds all Apple credentials (Login, Push, VoIP) to your ECall partner application.

#### Action

1. In Partner Dashboard, navigate to:
   - **Account → Settings → Apple Configuration**

2. Fill in the following fields:

**Apple Login**

| Field | Value |
|-------|-------|
| Apple Client ID | Your app Bundle ID (e.g. `com.company.ecall`) |
| Apple Team ID | Found in Apple Developer Portal → Membership |
| Apple Key ID | The 10-character ID shown when creating the Sign in with Apple key |
| Apple Private Key | Upload the `.p8` file (`AuthKey_XXXXXXXXXX.p8`) |

**APNs**

| Field | Value |
|-------|-------|
| Apple Push Cert (.p12) | Upload `push_cert.p12` |
| Apple Push Password | Password used when exporting `.p12` |

**VoIP Push**

| Field | Value |
|-------|-------|
| Apple VoIP Cert (.p12) | Upload `voip_cert.p12` |
| Apple VoIP Password | Password used when exporting `.p12` |

3. Click **Save / Update**

#### Expected Result

- Apple Login is enabled
- APNs Push is enabled
- VoIP Push is enabled
- Incoming calls can be delivered via CallKit

---

### 3.3 OTP Delivery Configuration (SMTP & Twilio)

This section configures how OTP codes are delivered to users, via Email (SMTP) and/or Phone (Twilio SMS).

ECall supports Email OTP, SMS OTP, or both, depending on partner configuration.

#### 3.3.1 SMTP Configuration (Email OTP)

SMTP configuration defines the sender email address used when sending OTP via email.

**Fields**

| Field | Description |
|-------|-------------|
| SMTP Host | Mail server hostname (e.g. `smtp.gmail.com`, `smtp.office365.com`) |
| SMTP Port | Common values: `587` (TLS – recommended), `465` (SSL) |
| SMTP User | Email account used to authenticate with SMTP server |
| SMTP Password | Password or App Password of the SMTP account |

**Behavior When SMTP Is Configured**

- OTP emails are sent from the partner's SMTP email
- Sender name and address are derived from SMTP account

**Fallback Behavior**

> ⚠️ **If SMTP configuration is left empty**
> - OTP emails will be sent using the ECall default system email:
>   - `E2EE Call Support <support@airfeedkh.com>`
> - No email delivery is blocked
> - This is a safe default for partners who do not want to manage SMTP

✅ **Recommended**: Partners who want custom sender branding should configure SMTP.

---

#### 3.3.2 Twilio Configuration (SMS OTP)

Twilio configuration enables OTP delivery via phone number (SMS).

**Required Fields**

| Field | Description |
|-------|-------------|
| Twilio Account SID | From Twilio Console |
| Twilio Auth Token | From Twilio Console |
| Twilio Verify Service SID | From Twilio Console |

**Behavior When Twilio Is Configured**

- Users can receive OTP via SMS
- The login UI will show:
  - Continue with Phone
  - Continue with Email

**Behavior When Twilio Is NOT Configured**

> ⚠️ **If Twilio configuration is empty**
> - SMS OTP is automatically disabled
> - The option "Continue with Phone" is hidden from UI
> - Only Email OTP is available

This behavior is controlled dynamically via:
```
GET https://api.your_app.org/app/api/app-config
```

The backend returns app configuration flags, and the client UI adapts automatically.

✅ **This is by design, not a UI bug.**

---

## 4. Configure iOS Project (Xcode)

This step configures the iOS source code to use the credentials prepared above.

### 4.1 Configure API Credentials in Xcode

#### Action

1. Open the iOS project in Xcode

2. Select **Project → Target**

3. Go to **Build Settings**

4. Scroll to **User-Defined**

5. Add the following keys:
   - `APP_API_ID`
   - `APP_API_HASH`

6. Set value for **Production** configuration

#### Expected Result

- API credentials are injected at build time
- App can authenticate with ECall backend

> 🔒 **Security Notice**
> Never hardcode credentials in source files.

> ⚠️ **Do NOT modify the following:**
> - API base URLs
> - Socket / Janus endpoints
> - Encryption / E2EE logic
> - Call signaling flow
>
> These components are managed by the ECall core system.
> Changing them may break security and compatibility.

---

### 4.2 Build & Run on Real Device

#### Action

1. Select a physical iOS device

2. Build & Run the app

3. Test:
   - App launch
   - Login (Apple ID)
   - Incoming call (VoIP Push)
   - CallKit UI appears

#### Expected Result

- App launches successfully
- Incoming calls work in background & locked screen

---

## 5. Final Pre-Submission Checklist

| Item | Status |
|------|--------|
| Partner account created | ☐ |
| Apple certificates created (Push, VoIP, Sign in with Apple) | ☐ |
| `.p8`, `.p12` uploaded to dashboard | ☐ |
| API credentials configured in Xcode | ☐ |
| SMTP & Twilio configuration | ☐ |
| Bundle ID matches everywhere | ☐ |
| Push & VoIP tested on real device | ☐ |
| CallKit works correctly | ☐ |
| No credentials committed to Git | ☐ |

---

## Support

For technical support, contact:
- Email: support@airfeedkh.com
- Portal: https://web.ecall.org/
- Documentation: https://docs.ecall.org
