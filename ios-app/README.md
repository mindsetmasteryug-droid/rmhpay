# RMH PAY iOS App

## Setup Instructions

### 1. Create New Xcode Project
1. Open Xcode
2. File > New > Project
3. Select "iOS" > "App"
4. Product Name: "RMH PAY"
5. Interface: SwiftUI
6. Language: Swift
7. Minimum iOS: 16.0

### 2. Add Source Files
Copy all Swift files from the `Sources/` directory into your Xcode project.

### 3. Project Structure
```
RMH_PAY/
├── App/
│   ├── RMH_PAYApp.swift
│   └── AppDelegate.swift
├── Core/
│   ├── API/
│   │   ├── APIClient.swift
│   │   ├── AuthAPI.swift
│   │   ├── AccountsAPI.swift
│   │   └── PaymentsAPI.swift
│   ├── Models/
│   │   ├── User.swift
│   │   ├── PPPoEAccount.swift
│   │   ├── Transaction.swift
│   │   └── Receipt.swift
│   ├── Services/
│   │   ├── AuthService.swift
│   │   ├── KeychainService.swift
│   │   └── NotificationService.swift
│   └── Utilities/
│       ├── Constants.swift
│       └── Extensions.swift
├── Features/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   ├── OTPView.swift
│   │   └── AuthViewModel.swift
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   ├── AccountLookup/
│   │   ├── AccountLookupView.swift
│   │   └── AccountDetailsView.swift
│   ├── Payment/
│   │   ├── PaymentView.swift
│   │   ├── PaymentConfirmationView.swift
│   │   └── PaymentViewModel.swift
│   ├── Receipts/
│   │   ├── ReceiptsView.swift
│   │   └── ReceiptDetailView.swift
│   └── SavedAccounts/
│       ├── SavedAccountsView.swift
│       └── SavedAccountsViewModel.swift
└── Resources/
    ├── Info.plist
    └── Config.xcconfig
```

### 4. Configure Info.plist
Add the following keys:
```xml
<key>API_BASE_URL</key>
<string>YOUR_SUPABASE_URL</string>
<key>API_KEY</key>
<string>YOUR_SUPABASE_ANON_KEY</string>
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to securely access your account</string>
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### 5. Enable Capabilities
1. Select your project in Xcode
2. Select your target
3. Go to "Signing & Capabilities"
4. Add "Push Notifications" capability
5. Add "Background Modes" capability
6. Check "Remote notifications"

### 6. Build & Run
1. Select a simulator or physical device
2. Command + R to build and run

## Features Implemented

- Phone + OTP authentication
- Password login
- Google Sign-In integration
- Account lookup
- Payment processing (MTN, Airtel, Card)
- Saved accounts management
- Transaction history
- Receipt viewing and sharing
- Push notifications
- Offline support
- Biometric authentication
- Dark mode support

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Production Checklist

- [ ] Configure production API endpoints
- [ ] Set up proper code signing
- [ ] Configure push notification certificates
- [ ] Test on physical devices
- [ ] Complete App Store Connect setup
- [ ] Add app icons
- [ ] Add launch screen
- [ ] Privacy policy and terms
- [ ] App Store screenshots
