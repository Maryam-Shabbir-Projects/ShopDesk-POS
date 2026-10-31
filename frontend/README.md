# ShopDesk (Flutter)

Inventory and point-of-sale app for small shops. Mobile first, adapts to tablets and desktop.

## Features
- Owner sign up, email-code verification, sign in, forgot password (code first, then new password)
- Home dashboard (sales today, orders, stock value, low stock, weekly chart)
- Sell: products by category, search, cart, discount, tax, payment type, receipt
- Stock: add / edit / delete, restock, **scan stock in** (USB scanner or camera)
- Product icons from the name, emoji picker, photo from camera/gallery, optional online photo lookup
- Sales history by day / 7 / 30 days, items sold, who bought, reopen any receipt
- Add sale (manual): scan or pick items, tax %, payment, custom date, receipt
- Predictor: best / worst sellers, days of stock left, reorder advice
- Settings: currency, default tax, shop name, receipt footer
- Receipts as 80 mm PDF (print or share)

## Run it
```bash
flutter create . --org com.yourcompany --project-name shopdesk   # generates android/ ios/ (keeps lib/)
flutter pub get
flutter run
flutter test
```
The app opens on a welcome page. The owner creates an account, confirms the email with a 6-digit code, then signs in. See `docs/AUTH_SETUP.md`. To use your own Node.js backend instead of the demo, see `../shopdesk_server/README.md`.
The shop starts empty: no sample products or sales are added. Add your own products in Stock.

### Platform setup (after `flutter create .`)
**Android** `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
```
Check the `mobile_scanner` README for the minimum `minSdkVersion`.

**iOS** `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key><string>Scan product barcodes and take product photos.</string>
<key>NSPhotoLibraryUsageDescription</key><string>Choose product photos.</string>
```
Check the `mobile_scanner` README for the minimum iOS version.

## Architecture
Feature-first, with three layers inside each feature:

```
lib/
  core/        theme, router, database, shared widgets, formatters
  features/
    auth/        domain (AppUser, AuthRepository) · data (demo + Supabase) · application (AuthController) · presentation (sign in/up, verify code, forgot, new password)
    products/    domain (Product, ProductRepository) · data (SQLite, image lookup) · application · presentation
    sales/       domain (Sale, PricingService) · data (SQLite) · application (SaleDraft, CheckoutService) · presentation
    scanner/     ScanInputBar (hardware scanner field + camera) and BarcodeScannerPage
    dashboard/   weekly sales provider and page
    predictor/   ForecastService (pure Dart, unit tested) and page
    settings/    SettingsController (SharedPreferences) and page
    shell/       adaptive navigation (bottom bar on phones, rail on tablets)
```
- **State**: Riverpod (`Notifier` / `AsyncNotifier`). Pages never touch the database.
- **Navigation**: go_router with an auth redirect and a role guard.
- **Persistence**: SQLite through repository interfaces (`ProductRepository`, `SaleRepository`, `AuthRepository`).
- **One sale model**: `SaleDraft` is used by both Sell and Add sale, and `PricingService` does all the maths.

## Connecting your Laravel backend
Each repository is an interface. Write `ApiProductRepository` and `ApiSaleRepository`
that call your REST API, then change the two provider definitions
(`productRepositoryProvider`, `saleRepositoryProvider`). No page needs to change.

## Before you ship
- Demo auth shows the code on screen and sends no email. For real emails, connect Supabase (or your own server) as described in `docs/AUTH_SETUP.md`, and turn off public sign-ups after creating the owner.
- Money is stored as `double` and rounded to 2 places. For strict accounting, switch to integer minor units.
- The online photo lookup uses Open Food Facts (mostly food). Do the lookup on your server and cache the image.
- The PDF receipt uses the currency code because the built-in PDF font has no currency symbols or emoji. Embed a font with `pdf` if you want symbols.

## Fonts
Screen titles use **Pacifico** (cursive), bundled in `assets/fonts` under the SIL Open Font Licence (`OFL.txt`).
Title colour is dark green on light screens and a lighter green on dark screens (`AppTheme.titleGreen`).

<img width="1920" height="1080" alt="ShopDesk banner, all 16 screens@1x" src="https://github.com/user-attachments/assets/cddcfbb7-b769-4460-83ca-29250b23240f" />

