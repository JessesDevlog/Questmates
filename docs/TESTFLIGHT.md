# TestFlight Distribution

Switch to this workflow once the MVP is validated via USB sideload builds.

## Cost

$99/year — Apple Developer Program

## Enrollment

1. Go to [developer.apple.com/programs](https://developer.apple.com/programs/)
2. Enroll with your Apple ID
3. Wait for approval (usually 24–48 hours)

## Setup App Store Connect

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Apps → New App
2. Platform: iOS, name: QuestMates, bundle ID matching your export preset
3. No public App Store release required — internal TestFlight only

## Upload Build

1. Export iOS project from Godot (same as IOS_EXPORT.md)
2. In Xcode: Product → Archive
3. Distribute App → App Store Connect → Upload
4. Wait for processing in App Store Connect (5–30 min)

## Add Internal Testers

1. App Store Connect → your app → TestFlight tab
2. Internal Testing → add your wife's email (and yours)
3. She installs the free **TestFlight** app from the App Store
4. Accept invite → install QuestMates

## Updates

Re-archive and upload new builds. TestFlight shows an Update button — no cables, no re-signing.

## Notes

- Internal builds do not require full App Store review
- Builds expire after 90 days if not refreshed (re-upload during active development)
- Up to 100 internal testers (more than enough for family)

## Checklist Before First Upload

- [ ] `secrets.gd` configured with production Supabase project
- [ ] Privacy policy URL (one-page GitHub Pages is fine)
- [ ] App icon set in Godot export preset
