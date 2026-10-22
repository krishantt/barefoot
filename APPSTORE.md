# Shipping to the App Store

Code side is done. This is the part that needs you, plus the risks worth knowing
before you pay Apple.

## Done in code

| Item | Where |
|---|---|
| Icon (1024, opaque, no alpha) | `Barefoot/Assets.xcassets/AppIcon.appiconset`, regenerate with `swift scripts/make_icon.swift` |
| Accent colour | `Assets.xcassets/AccentColor.colorset` |
| Privacy manifest, zero data collected | `Barefoot/PrivacyInfo.xcprivacy` |
| HealthKit: write Body Mass, read recent history for the trend | `HealthStore.swift`, entitlement in `project.yml` |
| Export-compliance flag (`ITSAppUsesNonExemptEncryption`) | `project.yml` |
| Category: Health & Fitness | `project.yml` |
| Dynamic Type, VoiceOver labels, kg/lb by locale | `ContentView.swift` |
| Denied-permission escape hatch | "Open Settings" button |
| Demo mode (no hardware needed) | "Demo" button |
| Version 1.0 / build 1 | `project.yml` |

## Blockers only you can clear

1. **Apple Developer Program — $99/year.** Free signing cannot submit. Individual
   enrolment is same-day; a company enrolment needs a D-U-N-S number and takes
   longer.
2. **Register the bundle id** `dev.krishtimil.Barefoot` in Certificates,
   Identifiers & Profiles (or change it first, it appears in `project.yml`).
3. **Create the app record** in App Store Connect: name, subtitle, category
   (Health & Fitness), price, availability.
4. **Host the privacy policy and support page.** Both are required URLs.
   Already live from this repo:
   - Privacy: https://krishantt.github.io/barefoot/privacy.html
   - Support: https://krishantt.github.io/barefoot/support.html
5. **Screenshots.** 6.9-inch is mandatory. You do not need the scale: the Demo
   button produces a reading, so shoot them in the simulator.
6. **App Privacy answers:** *Data Not Collected.* Accurate — nothing leaves the
   device.
7. **Submit for review.**

## Screenshots without hardware

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Barefoot.xcodeproj -scheme Barefoot \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -derivedDataPath build-sim build

xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl install booted build-sim/Build/Products/Debug-iphonesimulator/ScaleWeight.app
xcrun simctl launch booted dev.krishtimil.Barefoot
xcrun simctl io booted screenshot shot-1.png   # then tap Demo, shoot again
```

## Archive and upload

`ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>793QWV9G2U</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
```

```bash
xcodebuild -project Barefoot.xcodeproj -scheme Barefoot -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Barefoot.xcarchive \
  -allowProvisioningUpdates archive

xcodebuild -exportArchive -archivePath build/Barefoot.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export -allowProvisioningUpdates
```

Then attach the build in App Store Connect, paste the review notes below, submit.

## Review notes (paste this)

> Barefoot reads weight from Bluetooth scales that use the Chipsea broadcast
> protocol (sold with apps such as OKOK International). These scales never accept
> a GATT connection — the weight is carried in the BLE advertisement, so no
> pairing is possible or required.
>
> **No hardware needed to evaluate:** tap **Demo** on the main screen to see the
> reading state. Saving to Health requires a physical scale.
>
> HealthKit is used to **write** body mass samples and to **read back your own
> recent weight history** solely to draw the trend line on the main screen. No
> Health data is stored by the app, transmitted, or shared. No accounts, no
> analytics, no network requests.

## Honest risk assessment

| Risk | Level | Why | Mitigation |
|---|---|---|---|
| **4.2 Minimum Functionality** — one screen, one job | Medium | Apple rejects apps that are "too simple" | Demo mode, Health integration, and a real hardware problem being solved. If rejected, add weight trend/history — that is the usual fix |
| **2.1 reviewer cannot test the hardware** | Medium | They will not own this scale | Demo button + the notes above |
| **5.1.3 HealthKit** | Low | Privacy policy required, no ads, no data resale, write-only | Already compliant |
| **Trademark** | Low | "OKOK" is their brand | Never use it in the app name, icon, or subtitle. Say "compatible with Chipsea-based scales" |
| **Licensing of the protocol knowledge** | Low | openScale documents the same frame layouts under GPLv3 | This parser is an independent Swift implementation of a wire format (a fact, not creative code). Do not paste GPL source into this repo, and do not vendor openScale |

Expect at least one rejection round for a single-purpose hardware companion. That
is normal, not a failure.

## Before you submit

- [ ] `swiftc Barefoot/OkokPacket.swift Tests/main.swift -o /tmp/dt && /tmp/dt` → `decode ok`
- [ ] Bundle id registered and matches `PRODUCT_BUNDLE_IDENTIFIER`
- [ ] Privacy policy + support URLs live and loading
- [ ] Screenshots uploaded for 6.9-inch
- [ ] App Privacy: Data Not Collected
- [ ] Age rating: 4+
- [ ] Price set
- [ ] Review notes pasted
- [ ] Real weigh-in appears in Health on the physical device

## After launch

The 7-day expiry stops applying — App Store builds are signed by Apple. Use
TestFlight for betas, and keep the "N" build number incrementing per upload.
