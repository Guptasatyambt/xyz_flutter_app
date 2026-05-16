# XYZ — Ride Hailing App

A Flutter-based ride-hailing mobile application (Uber/Rapido-style) supporting both **Rider** and **Driver** flows with real-time GPS tracking and live maps.

---

## Features

### Rider
- Phone number OTP login
- Live map (OpenStreetMap) centered on device GPS
- Nearby driver markers on home screen
- Address search with reverse geocoding
- Drag-to-select pickup location
- Fare estimates across all vehicle types — Bike, Auto, Mini, Sedan, SUV
- Book a ride with a signed fare quote
- Real-time ride tracking — driver location streamed live during the ride
- Cancel ride
- Ride history
- Post-ride driver ratings
- Push notifications

### Driver
- Phone number OTP login
- KYC document upload and approval status
- Vehicle management (add / update / remove)
- Go online / offline with live GPS broadcast
- Receive ride offers in real time and accept/reject
- Active ride flow:
  - Map shows route from driver's current GPS → rider pickup (approach navigation)
  - GPS position emitted to server every ~15 m; rider sees driver moving live
  - Actions: Mark Arrived → Start Ride → Complete Ride
  - Map switches to pickup → destination route once ride starts
- Ride history

---

## Tech Stack

| Concern | Package |
|---|---|
| Maps | `mapbox_maps_flutter` |
| Routing / geometry | `latlong2` |
| GPS / location | `geolocator` |
| Real-time events | `socket_io_client` |
| HTTP | `http` |
| Secure token storage | `flutter_secure_storage` |
| Media / photo upload | `image_picker` |

- **Dart SDK**: `^3.11.5`
- **Flutter**: 3.x

---

## Project Structure

```
lib/
├── core/
│   ├── api/              # ApiClient + endpoint constants
│   ├── models/           # Dart model classes (Ride, User, Driver, Geo…)
│   ├── navigation/       # App router / navigator
│   ├── services/         # HTTP service layer (auth, rides, geo, driver…)
│   ├── socket/           # SocketManager — driver & rider namespaces
│   └── storage/          # Secure token storage
├── screens/
│   ├── auth/
│   │   ├── phone_entry_screen.dart
│   │   ├── otp_screen.dart
│   │   └── profile_setup_screen.dart
│   ├── driver/
│   │   ├── driver_home_screen.dart
│   │   ├── driver_online_screen.dart
│   │   ├── driver_active_ride_screen.dart
│   │   ├── driver_ride_history_screen.dart
│   │   ├── driver_profile_screen.dart
│   │   ├── vehicle_management_screen.dart
│   │   └── kyc_screen.dart
│   ├── home_screen.dart
│   ├── active_ride_screen.dart
│   ├── ride_estimate_screen.dart
│   ├── search_screen.dart
│   ├── ride_history_screen.dart
│   ├── profile_screen.dart
│   ├── edit_profile_screen.dart
│   ├── rating_screen.dart
│   └── notifications_screen.dart
└── widgets/
    └── ride_map_widget.dart   # Reusable map — polyline route, pickup/drop markers, live driver marker
```

---

## Real-time Location Flow

```
Driver app                        Server                      Rider app
──────────                        ──────                      ─────────
GPS stream (every 15 m)
  └─► location:update ──────────► fan-out ──────────────────► ride:driver-location
                                                               (live car marker on map)

Status change (arrived / started)
  └─► HTTP action ──────────────► state machine ────────────► ride:state
                                                               (UI updates instantly)
```

- Driver connects to `/driver` WebSocket namespace; rider connects to `/rider`
- Rider subscribes to their ride room to receive driver location and status events
- Map auto re-fits camera when driver location first appears or route changes

---

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.11.5
- Android device or emulator (API 21+)
- A [Mapbox account](https://account.mapbox.com) with a public token (`pk.eyJ1…`)

### 1 — Create your secrets file

`lib/secrets.dart` is excluded from version control. Copy the example and add your token:

```bash
cp lib/secrets.dart.example lib/secrets.dart
```

Then open `lib/secrets.dart` and replace the placeholder with your real Mapbox public token.

### 2 — Configure the backend URL

Set your backend base URL in [lib/core/api/api_endpoints.dart](lib/core/api/api_endpoints.dart).

### 3 — Run

```bash
flutter pub get
flutter run
```

---

## Android Permissions

Declared in `android/app/src/main/AndroidManifest.xml`:

- `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` — GPS for map centering and driver tracking
- `INTERNET` — API and WebSocket connections
- `CAMERA` + `READ_MEDIA_IMAGES` — KYC document upload (driver)

---

## Screens Overview

| Screen | Role |
|---|---|
| Phone Entry / OTP | Shared auth for rider and driver |
| Home | Rider map, pickup selection, nearby drivers |
| Search | Geocoded place search for destination |
| Ride Estimate | Vehicle selection with fare breakdown |
| Active Ride | Live map with driver tracking, ride status |
| Ride History | Past trips list |
| Rating | Post-ride driver rating |
| Driver Home | Driver dashboard, online toggle |
| Driver Online | Live GPS broadcast, incoming offers |
| Driver Active Ride | Approach + ride navigation, action buttons |
| KYC | Document upload and approval status |
| Vehicle Management | Add/edit driver vehicles |
