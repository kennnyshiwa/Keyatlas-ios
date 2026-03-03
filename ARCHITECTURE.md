# KeyAtlas iOS — Architecture Plan

## Overview
Native iOS app for KeyAtlas (keyatlas.io) — a mechanical keyboard community hub. Must achieve feature parity with the web app, consuming the existing REST API.

## Tech Stack
- **Language:** Swift 6
- **UI Framework:** SwiftUI
- **Minimum iOS:** 17.0
- **Architecture:** MVVM with async/await
- **Networking:** URLSession + Codable (no Alamofire — keep deps minimal)
- **Image Loading:** AsyncImage + caching layer (Kingfisher or Nuke)
- **Auth:** Keychain storage for tokens, support OAuth + email/password
- **Navigation:** NavigationStack (iOS 16+)
- **State Management:** @Observable (iOS 17+)
- **Charts:** Swift Charts framework
- **Search:** Native search integration
- **Push Notifications:** APNs (future — requires backend support)

## API Base
- Production: `https://keyatlas.io/api/v1/`
- Auth endpoints: `https://keyatlas.io/api/auth/`
- Full API routes documented in FEATURES.md

## App Structure
```
KeyAtlas/
├── App/
│   ├── KeyAtlasApp.swift
│   └── ContentView.swift
├── Models/
│   ├── Project.swift
│   ├── Vendor.swift
│   ├── User.swift
│   ├── ForumThread.swift
│   ├── Guide.swift
│   └── ...
├── Services/
│   ├── APIClient.swift
│   ├── AuthService.swift
│   ├── ImageCache.swift
│   └── KeychainService.swift
├── ViewModels/
│   ├── ProjectListViewModel.swift
│   ├── ProjectDetailViewModel.swift
│   ├── AuthViewModel.swift
│   └── ...
├── Views/
│   ├── Projects/
│   │   ├── ProjectListView.swift
│   │   ├── ProjectDetailView.swift
│   │   ├── ProjectGalleryView.swift
│   │   └── ProjectCardView.swift
│   ├── Discover/
│   │   ├── DiscoverView.swift
│   │   ├── GroupBuysView.swift
│   │   └── InterestChecksView.swift
│   ├── Vendors/
│   │   ├── VendorListView.swift
│   │   └── VendorDetailView.swift
│   ├── Forums/
│   │   ├── ForumListView.swift
│   │   ├── ThreadListView.swift
│   │   └── ThreadDetailView.swift
│   ├── Calendar/
│   │   └── CalendarView.swift
│   ├── Stats/
│   │   └── StatisticsView.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   └── SettingsView.swift
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── SignUpView.swift
│   └── Shared/
│       ├── SearchBar.swift
│       ├── StatusBadge.swift
│       └── ImageGallery.swift
├── Extensions/
│   └── ...
└── Resources/
    ├── Assets.xcassets
    └── ...
```

## Tab Bar Structure
1. **Home** — Featured/trending projects, activity feed
2. **Discover** — Interest Checks, Group Buys, Ending Soon, New This Week
3. **Forums** — Forum categories and threads
4. **Calendar** — GB dates calendar + expected deliveries
5. **Profile** — User profile, settings, notifications

## Priority Order for Implementation
1. API client + auth flow (foundation)
2. Project listing + detail (core value)
3. Discover pages (browsing)
4. Vendor pages
5. Search
6. Forums
7. Calendar + Statistics
8. Guides
9. User profiles
10. Image upload + project submission
11. Compare feature
12. Push notifications
