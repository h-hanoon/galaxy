# Galaxy — Augmented Sky Map

A Flutter app that turns your phone into a live star chart. Point the device at any part of the sky and see the Sun, Moon, all visible planets, and three major constellations rendered in real time against a procedural star field. Tap any object for an interactive 3D model and in-depth description.

---

## Features

### Live Sky Rendering
- **Procedural star field** — 300 randomised background stars fill the canvas and scroll smoothly as you pan the device.
- **Real-time celestial positions** — the Sun, Moon, and all seven visible planets (Mercury → Neptune) are placed accurately using Keplerian orbital mechanics and GMST-based coordinate transforms, updated every minute.
- **Constellation outlines** — Orion, Ursa Major, and Cassiopeia are drawn as connected star patterns using J2000 equatorial coordinates for each individual star, with labelled centroids.

### Sensor Fusion
- Accelerometer and magnetometer readings are fused to compute the device's azimuth and elevation with a two-stage low-pass filter — a fast pass on raw sensor data and a slower pass on the derived angles to eliminate jitter without lag.
- Shortest-path azimuth interpolation prevents the 0°/360° wrap-around jump.

### Guide Arrow
- Select any body or constellation from the chip bar and an animated guide arrow appears at the screen edge, pointing toward the target and switching to a crosshair reticle once the target is on screen.
- Arrow colour matches the selected object (amber for the Sun, silver for the Moon, a unique colour per planet, sky-blue for constellations).

### Tap to Explore
- Tap any object on the canvas to open a detail sheet.
- **Sun & Moon** — interactive 3D GLB model (pinch-zoom, drag to rotate) plus a full description.
- **Planets** — individual 3D GLB model for each of the seven planets plus description.
- **Constellations** — large-format description with mythology, navigation lore, and deep-sky highlights; no 3D model.

---

## Screenshots

> _Add screenshots here._

---

## Architecture

```
lib/
├── main.dart                  # App entry point
├── model/
│   ├── astronomy.dart         # Celestial maths: Julian day, GMST, sun/moon/planet
│   │                          #   positions (Keplerian elements), constellation
│   │                          #   layouts (per-star RA/Dec + line indices)
│   └── work.dart              # StatefulWidget: sensor fusion, GPS, position
│                              #   updates, chip bar, guide arrow, canvas tap
└── ui/
    ├── star_field.dart        # CustomPainter: star field, planet dots, sun/moon
    │                          #   draw routines, constellation line rendering
    └── body_detail.dart       # Bottom sheet: 3D model viewer or constellation
                               #   description sheet
```

**Data flow:**
1. GPS fix → `_updateCelestialPositions` computes virtual sky `Offset` for every body.
2. Sensor events → low-pass filtered → azimuth/elevation → `skyToVirtual` device offset.
3. `StarFieldPainter` receives both sets of offsets and paints everything at 30 fps.

---

## Getting Started

### Prerequisites
- Flutter SDK `>=3.12.0`
- An [Astronomy API](https://astronomyapi.com) account for the bodies endpoint (optional — positions are computed locally; the API is used only to list available body names on startup).

### Environment Variables

Pass your Astronomy API credentials at build time:

```bash
flutter run \
  --dart-define=ASTRO_APP_ID=your_app_id \
  --dart-define=ASTRO_APP_SECRET=your_app_secret
```

Or add them to a `.env`-equivalent `launch.json` / IDE run configuration.

### Running

```bash
git clone https://github.com/your-username/sky-map.git
cd sky-map/galaxy
flutter pub get
flutter run --dart-define=ASTRO_APP_ID=... --dart-define=ASTRO_APP_SECRET=...
```

### Permissions

The app requests the following permissions at runtime:

| Permission | Purpose |
|---|---|
| `ACCESS_FINE_LOCATION` | GPS coordinates for horizon calculations |
| `ACCESS_COARSE_LOCATION` | Fallback location |
| Accelerometer | Tilt / elevation angle |
| Magnetometer | Compass heading / azimuth |

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| [`geolocator`](https://pub.dev/packages/geolocator) | ^13.0.0 | GPS position stream |
| [`sensors_plus`](https://pub.dev/packages/sensors_plus) | ^6.1.0 | Accelerometer & magnetometer |
| [`http`](https://pub.dev/packages/http) | ^1.2.0 | Astronomy API calls |
| [`model_viewer_plus`](https://pub.dev/packages/model_viewer_plus) | ^1.10.0 | Interactive 3D GLB viewer |

---

## Celestial Bodies Covered

| Body | Type | Position Method |
|---|---|---|
| Sun | Star | Simplified solar longitude formula |
| Moon | Natural satellite | Low-precision lunar theory |
| Mercury – Neptune | Planets | Keplerian orbital elements (J2000) |
| Orion | Constellation | Per-star J2000 RA/Dec → horizon |
| Ursa Major | Constellation | Per-star J2000 RA/Dec → horizon |
| Cassiopeia | Constellation | Per-star J2000 RA/Dec → horizon |

