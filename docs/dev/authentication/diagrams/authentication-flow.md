# Diagram: Authentication Flow

> Canonical doc: `../overview.md`

This document contains simplified diagrams for the main authentication flows.

---

## 1. Unified "Continue" Flow (Sign-in / Sign-up)

This diagram shows the initial step where the user provides an identifier. The backend determines if it's a new registration or an existing user login.

```mermaid
flowchart TB
    subgraph User Action
        START((Start)) --> IDENTIFY{Enter Email, Phone, <br/>or use Social Login}
    end

    subgraph Client Action
        IDENTIFY --> API_CALL{API Call}
    end

    subgraph API Endpoints
        API_CALL -->|Email or Phone| LOGIN["POST /app/api/login<br/>(verified=false)"]
        API_CALL -->|Google| GOOGLE_LOGIN["POST /app/api/login<br/>(verified=true)"]
        API_CALL -->|Apple| APPLE_LOGIN["POST /app/api/apple-login"]
    end

    subgraph Next Step
        LOGIN --> OTP_FLOW((To OTP Flow))
        GOOGLE_LOGIN --> GET_TOKENS((Get Tokens))
        APPLE_LOGIN --> GET_TOKENS((Get Tokens))
    end
```

---

## 2. OTP Verification Flow

This flow is triggered after the user submits their email or phone number.

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant App as iOS App
    participant API as Backend API

    Note over U, API: User is on OTP screen

    U->>App: Enter OTP code
    App->>API: POST /app/api/verify-login

    alt OTP is Valid
        API-->>App: Success (accessToken, refreshToken)
        App->>App: Store tokens in Keychain
        App-->>U: Navigate to Main App
    else OTP is Invalid
        API-->>App: Error
        App-->>U: Show error message
    end
```
