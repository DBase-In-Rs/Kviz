# Kviz DBase

[![Flutter CI](https://github.com/DBase-In-Rs/Kviz/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/DBase-In-Rs/Kviz/actions/workflows/flutter_ci.yml)
[![Google Play](https://img.shields.io/badge/Google%20Play-Preuzmi-blue?logo=google-play)](https://play.google.com/store/apps/details?id=rs.in.dbase.kviz)

Kviz DBase je mobilna kviz aplikacija — **Kviz solo**, **Kviz duel** i **Kviz+** sa pitanjima, asocijacijama, Moj Broj i Tangram rundama. Dostupna na Google Play-u za Android.

---

## Modovi igre

| Mod | Runde | Tip |
|---|---|---|
| **Kviz Solo** | Pitanja · Asocijacije · Moj Broj | Solo, vežba |
| **Kviz Duel** | Pitanja · Asocijacije · Moj Broj | 1v1 online |
| **Kviz+ Duel** | Pitanja · Asocijacije · Moj Broj · Tangram | 1v1 online |
| **Premier** | Isto kao Kviz+ | Premier liga |

Pojedinačni modovi: **Pitanja**, **Asocijacije**, **Moj Broj**, **Tangram+**.

---

## Tehnologija

- **Frontend:** Flutter 3 (Dart ^3.11)
- **Backend:** Laravel 12 (PHP 8.2, Sanctum)
- **Auth:** Google Sign-In + Play Integrity
- **Ads:** Google AdMob (rewarded, interstitial, banner)
- **Leaderboards:** Google Play Games v2
- **Push:** Firebase Cloud Messaging
- **Subscriptions:** Google Play Billing

---

## ⚡ Brzi start (lokalno)

```bash
# Web (dev)
.\scripts\run_web.ps1           # http://localhost:7357

# Android (debug)
flutter run

# Provera pre commit-a
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

---

## 🔨 Build & Release

```powershell
# AAB za Google Play (release, obfuscated)
.\scripts\build_aab.ps1
.\scripts\build_aab.ps1 -Version "1.0.1"

# Fastlane (iz android/ foldera)
cd android
bundle exec fastlane android internal
```

---

## 🧪 CI/CD

Na svaki push/PR na `main` pokreće se:

- `dart format` — provera formatiranja
- `flutter analyze` — statička analiza
- `flutter test` — unit i widget testovi

[![Flutter CI](https://github.com/DBase-In-Rs/Kviz/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/DBase-In-Rs/Kviz/actions/workflows/flutter_ci.yml)

---

## 📦 Google Play

[![Google Play](https://img.shields.io/badge/Google%20Play-Preuzmi-blue?logo=google-play)](https://play.google.com/store/apps/details?id=rs.in.dbase.kviz)

---

## 🔒 Web Google Login (dev)

Za lokalni web login koristi fiksni origin `http://localhost:7357`.  
U Google Cloud Console → OAuth 2.0 Web client ID, u `Authorized JavaScript origins`:

- `http://localhost:7357`
- `https://dbase.in.rs`
- `https://kviz.dbase.in.rs`

Origin nema path — **ne** `https://dbase.in.rs/kviz`.

---

## 📁 Struktura projekta

```
lib/
├── app/                  # Firebase bootstrap, app shell
├── data/
│   ├── billing/          # Google Play IAP
│   ├── local/            # SQLite cache, repositories
│   └── remote/           # API client, auth, integrity, session launcher
├── domain/               # Models, entities
├── features/
│   ├── queue/            # Duel matchmaking
│   └── session/          # Practice session + shared round widgets
├── presentation/
│   ├── home/             # Mode preview, mode cards
│   ├── leaderboard/      # Rang liste
│   ├── online_session/   # Online game UI (part files)
│   ├── profile/          # Achievements
│   └── settings/         # Subscriptions, rewarded ads, preferences
└── shared/               # Utility widgets, script helpers
```
