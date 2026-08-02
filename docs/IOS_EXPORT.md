# iOS Export — Free USB Sideload (Personal Team)

Use this workflow during Phase 0–1 development before paying for TestFlight.

## Requirements

- Mac with Xcode installed
- Free Apple ID (no paid Developer Program required)
- iPhone connected via USB

## Steps

1. **Install Godot iOS export templates**
   - Godot Editor → Editor → Manage Export Templates → Download for your Godot version.

2. **Add iOS export preset**
   - Project → Export → Add → iOS
   - Bundle Identifier: `com.yourname.questmates` (unique to you)
   - Signing: leave for Xcode

3. **Export Xcode project**
   - Export → Export Project → choose `build/ios/QuestMates.xcodeproj`

4. **Open in Xcode**
   - Open the exported `.xcodeproj`
   - Select your iPhone as run target
   - Signing & Capabilities → Team → Personal Team (your Apple ID)

5. **Install on device**
   - Click Run (▶) with phone plugged in
   - On iPhone: Settings → General → VPN & Device Management → trust developer

## Limitations

- Build expires after **7 days** — re-run from Xcode weekly
- Wife's phone must be plugged into your Mac each reinstall
- No over-the-air updates

## Troubleshooting

- **"Unable to install"**: Delete old app, clean build folder in Xcode
- **Network blocked**: Ensure app has network entitlement (default in Godot export)
- **Godot export fails**: Verify export templates match editor version exactly

When the chore-loop MVP feels solid, switch to TestFlight (see TESTFLIGHT.md).
