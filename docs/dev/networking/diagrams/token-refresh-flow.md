# Diagram: Token Refresh & Session Management

> Canonical doc: `../token-refresh.md`

This document contains simplified diagrams for the token refresh and session management flows.

---

## 1. Overview: Token Refresh Flow (on 401 Error)

This is the main flow, triggered when an API call returns a `401 Unauthorized` error because the access token has expired.

```mermaid
flowchart TD
    REQ[API Request with Bearer Token] --> SERVER[Server Response]

    SERVER --> OK{Status Code?}

    OK -->|2xx| SUCCESS[Return Data]
    OK -->|401| PARSE[Parse Error Code]
    OK -->|Other| ERR[Return Error]

    PARSE --> CODE{Error Code?}

    CODE -->|ErrAccessTokenExpired| REFRESH[Call TokenRefreshManager]
    CODE -->|ErrRefreshTokenExpired or ErrDeviceNotRegistered| LOGOUT[Force Logout]

    REFRESH --> RESULT{Refresh Result?}

    RESULT -->|Success| RETRY["Retry Original Request (once)"]
    RESULT -->|Failure| LOGOUT

    RETRY --> SUCCESS
```

---

## 2. Proactive Refresh Flow (on App Foreground)

To improve user experience, the app automatically refreshes the token when it returns to the foreground.

```mermaid
flowchart TD
    subgraph App Lifecycle
        FG[App Enters Foreground]
    end

    FG --> CHECK{Is User Logged In?}

    CHECK -->|No| SKIP[Do Nothing]
    CHECK -->|Yes| TRIGGER[Trigger Proactive Refresh]

    TRIGGER --> TRM[TokenRefreshManager.refreshAccessToken]

    TRM --> RESULT{Result?}

    RESULT -->|Success| CONTINUE[Session Validated]
    RESULT -->|Failure| LOGOUT[Force Logout]
```

---

## 3. Thread-Safe Refresh Queue

`TokenRefreshManager` ensures only one refresh request is active at a time, even if multiple API calls fail simultaneously.

```mermaid
sequenceDiagram
    autonumber
    participant A as Request A
    participant B as Request B
    participant TRM as TokenRefreshManager
    participant API as Refresh Token API

    Note over A, B: Multiple requests hit 401 at once

    A->>TRM: refreshAccessToken()
    TRM->>TRM: Start refreshing...

    B->>TRM: refreshAccessToken()
    TRM->>TRM: Add to wait queue

    TRM->>API: POST /app/api/refresh-token
    API-->>TRM: New Tokens

    TRM->>TRM: Finish refreshing

    par Notify all waiting requests
        TRM-->>A: Success
        TRM-->>B: Success
    end

    Note over A, B: Both requests will now retry
```
