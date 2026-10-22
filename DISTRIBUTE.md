# Distributing with AltStore PAL

Three facts decide whether this is worth starting. All three come from AltStore's
own docs, not from me.

## 1. PAL is EU, Japan and Brazil only

> "AltStore PAL is an official alternative app marketplace for Notarized apps
> available for users in the EU, Japan, and Brazil."

**Users outside those regions cannot install the marketplace at all.** You can be
a developer anywhere, but the person installing the app must be in an eligible
country with an eligible Apple ID. If your friends with these scales are in Nepal
or India, PAL does not reach them.

## 2. It does not replace the $99 Developer Program

> "You will still submit apps through App Store Connect using your paid Apple
> Developer account."

PAL is not a way around Apple. It swaps App Store review for Notarization review —
less strict, still review — and still requires the paid account.

## 3. You host the package yourself

Apple generates an **Alternative Distribution Package** (ADP). You download it
through AltStore's REST API, host it, and the file hashes must not change —
`manifest.json` must not be reformatted.

## What you get for it

| App Store | AltStore PAL |
|---|---|
| Worldwide | EU / Japan / Brazil only |
| $99 + review | $99 + notarization review |
| Apple hosts the binary | You host the ADP |
| Users find it by searching | Users add your source URL |

The one genuine advantage: lighter review, and no App Store listing competing on
search. For a niche hardware utility, that is not nothing.

## Steps

1. **Developer Program** ($99/yr) and an app record in App Store Connect.
   Note the app's **Apple ID** under App Information — that is `marketplaceID`.
2. **Register your Developer ID** with AltStore:
   ```bash
   curl -X POST https://api.altstore.io/v1/developers \
     -H 'Content-Type: application/json' \
     -d '{"developerId":"<Developer ID from App Store Connect>"}'
   ```
   It returns a security token.
3. **App Store Connect → Users and Access → Integrations → Marketplace → +**,
   paste the token, select Barefoot, and opt into automatic processing.
4. **Submit for Notarization**: app → App Review → Review Type → *Notarization*.
5. **Download the ADP** from Apple (AltStore REST API, `download-adp`), and host
   it exactly as delivered:
   ```
   adp/
     manifest.json
     signature
     variant/<uuid>.ipa
   ```
6. **Generate the source**, reading entitlements and usage strings from the real
   build (AltStore compares them against the IPA and refuses installs on any
   mismatch):
   ```bash
   python3 scripts/make_altstore_source.py \
     build/Build/Products/Release-iphoneos/Barefoot.app \
     --adp-url https://your-host/barefoot/adp \
     --adp-dir path/to/downloaded/adp \
     --marketing-id <Apple ID from App Store Connect>
   ```
   If your host flattens directories, use `assetURLs` in the source instead —
   AltStore documents that GitHub Releases works for this.
7. **Publish** `altstore/source.json` at a public URL and add that URL in
   AltStore PAL. Source URLs work from AltStore PAL 2.2 onward.

## Verification before you publish

```bash
python3 -c "import json;json.load(open('altstore/source.json'))"   # valid JSON
plutil -extract CFBundleIdentifier raw build/Build/Products/Release-iphoneos/Barefoot.app/Info.plist
```
The bundle identifier, version and build number in the source must match the IPA
exactly (case sensitive), and `marketplaceID` must match App Store Connect.

## The honest recommendation

If the goal is **your own phone without the 7-day expiry**, PAL cannot help you
unless your Apple ID region is EU, Japan or Brazil. The path that does work is the
plain **App Store** listing — free app, no expiry, no sideloading, and the work is
mostly the same: $99, notarization-grade review, screenshots.

If the goal is **sharing with people beyond your region without an account
review**, that is AltStore **Classic** — worldwide and free of Apple review, but
it keeps the 7-day expiry and 3-app limit, i.e. exactly what you already have.

**Unknown, check before paying:** Apple's Core Technology Fee technically applies
to EU alternative distribution. At this scale it should be zero, but the terms
have changed more than once — confirm on Apple's current page rather than trusting
this document.
