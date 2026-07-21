# ReceiptBook — P0 Scaffold

This is a working Flutter scaffold for the P0 slice of the ReceiptBook SRS:

- Login (email/password + mobile OTP)
- Auto-created Individual Book on first login
- Add Business Book (starts the 1-month free trial, per SRS 5.1)
- Book switcher (Active / Locked / Trial-days-left states)
- Home Ledger (list, search, income/expense filter)
- Scan → OCR (Google ML Kit, on-device) → editable review form → Save
- Transaction detail (view/delete, receipt photo viewer)
- Offline-first saves: every transaction is written to local SQLite
  immediately, then synced to Firestore in the background
- The single shared "is this Business Book writable right now?" check
  (`BookAccessService`), wired into the ledger, so the subscription/locking
  rules in SRS Section 5 are enforced from day one instead of bolted on later
- GST CGST/SGST/IGST split logic (`GstService`) ready for the invoice
  generator to consume next
- **Business Dashboard** (SRS 4.4): date range selector (this month / last
  month / this FY / custom), big Income/Expense/Net numbers, income-vs-expense
  trend chart (daily/weekly/monthly depending on range length), expense
  breakdown pie chart + top-5 categories, top customers/vendors, and an
  "estimate only" GST payable card (output tax on income minus input tax
  credit on expenses for the period) — gated by the same writable-book check,
  so a locked Business Book shows an upgrade prompt instead of numbers
- **Invoice Generator** (SRS 4.5): manual line-item entry (description,
  HSN/SAC, qty, rate, discount, tax % from the config-driven rate list) plus
  a best-effort "scan an old invoice" OCR prefill; atomic per-book invoice
  numbering with a configurable template (`INV-{YYYY}-{0000}`) and optional
  reset-per-financial-year; CGST+SGST vs IGST computed from Book state vs.
  customer state via `GstService`; a generated PDF (logo, GSTIN, line items,
  tax breakup, total in words) previewed in-app and shared through the native
  OS share sheet (`printing`/`share_plus` — no custom WhatsApp integration);
  Mark Paid/Unpaid/Partially Paid, where Paid auto-creates the linked Income
  transaction exactly once (never a duplicate) per SRS Section 8

**Not yet built** (intentionally, so this ships something runnable first):
GST Reports, ITR Pack export, Reminders, real platform billing (Play
Billing/App Store), full Contacts/Categories management screens, biometric
app lock UI, and Credit/Debit Notes (the `Invoice` model already supports
`InvoiceDocType.creditNote/debitNote` and the PDF renders their header
correctly — only the "create one linked to an existing invoice" screen is
missing). The data models and services for most of these already exist or
are easy to extend (see `lib/core/models` and `lib/core/services`).

## 1. Copy this into a real Flutter project

You already have Flutter + Android Studio SDK/emulator installed, so:

```bash
flutter create receipt_book_app
cd receipt_book_app
```

Then **replace** the generated `lib/` folder and `pubspec.yaml` with the
ones from this scaffold (copy everything over, keep the `android/`, `ios/`,
etc. platform folders that `flutter create` made for you).

```bash
flutter pub get
```

## 2. Set up Firebase (required — the app won't run without this)

The app uses Firebase for Auth, Firestore (data), and Storage (receipt
photos + invoice PDFs later).

1. Create a project at https://console.firebase.google.com
2. Enable **Authentication** → Sign-in methods → turn on **Phone** and
   **Email/Password**.
3. Enable **Cloud Firestore** (start in test mode for local dev, lock down
   rules before shipping).
4. Enable **Storage**.
5. Install the FlutterFire CLI and run it from the project root — this
   generates the real `lib/firebase_options.dart` for you and registers
   your Android/iOS apps automatically:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Pick your Firebase project, select Android + iOS, and let it overwrite
   the placeholder `lib/firebase_options.dart` in this scaffold.

6. For phone-number OTP sign-in specifically, Android also needs SHA-1/SHA-256
   fingerprints registered on the Firebase Android app (Project settings →
   your Android app → Add fingerprint). Get them with:

   ```bash
   cd android && ./gradlew signingReport
   ```

## 3. Android-specific setup

- Minimum SDK: Firebase + ML Kit need **minSdkVersion 23+**. In
  `android/app/build.gradle`, set:
  ```gradle
  defaultConfig {
      minSdkVersion 23
      multiDexEnabled true
  }
  ```
- Add camera + storage permissions in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-permission android:name="android.permission.INTERNET"/>
  ```

## 4. iOS-specific setup (when you get to it)

Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>ReceiptBook needs your camera to scan receipts.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>ReceiptBook needs photo library access to attach receipt images.</string>
```

## 5. Run it

```bash
flutter run
```

Pick your emulator when prompted. First run: sign up with email/password
(fastest for local testing — phone OTP needs the SHA fingerprint step
above and a real or configured emulator with Play Services).

**Testing on Windows/Linux desktop instead of the Android emulator:**
this scaffold already handles it — `main.dart` initializes
`sqflite_common_ffi` on those platforms before any database call, since
plain `sqflite` only ships native support for Android/iOS/macOS. If you
still see `Bad state: databaseFactory not initialized`, run
`flutter pub get` again to make sure `sqflite_common_ffi` got pulled in.

## Project structure

```
lib/
  core/
    models/        # Section 7 data model: User, Subscription, Book,
                    # Transaction, Category, Contact
    services/       # Firebase/Firestore repositories, local SQLite cache,
                    # BookAccessService (the writable-book check),
                    # GstService (CGST/SGST/IGST split)
    utils/money.dart # paise <-> ₹ conversion (Section 8 money rule)
    widgets/book_switcher.dart
  features/
    auth/           # login, OTP, AuthProvider
    books/          # first-time setup, add-business-book, BookProvider
    ledger/         # home ledger list + filters
    dashboard/      # Business Dashboard (trend chart, category pie,
                    # GST estimate, top contacts) - date-range aggregation
                    # logic lives in dashboard/services, pure + testable
    scan/           # scan choice -> camera capture -> OCR -> review form
    invoices/       # invoice list, create/edit, PDF generation, preview+share
    transaction_detail/
    settings/       # Manage Books (plan/trial/locking UI)
```

## First-time Firestore setup for invoices

Two things need seeding once per environment before invoices work smoothly:

1. **Tax rate config** — `TaxRuleConfigRepository.seedDefaultIfMissing('2026-27')`
   writes a default GST rate list to `taxRuleConfig/2026-27` if it's missing.
   Call it once (e.g. from a debug button or a one-off script) or create the
   doc manually in the Firestore console. Without it the app just falls back
   to a hardcoded default list — functional, but not remotely updatable, which
   defeats the point (SRS Section 8).
2. **Firestore index** — `InvoiceRepository.watchInvoices` queries
   `where bookId == X orderBy createdAt desc`; Firestore will throw a
   "requires an index" error with a direct link to create it the first time
   you run this in a fresh project. Click the link once; after that it's fine.

## Where to go next (matches the SRS's own P0 → P1 → P2 priority order)

1. **GST Reports / ITR Pack export** (SRS 4.6-4.7) — mostly querying
   transactions (and now invoices) by date range/tax head and exporting via
   the `pdf`/`excel` packages. The disclaimer footer requirement (Section 8)
   applies to every one of these exports.
2. **Real platform billing** — `ManageBooksScreen.choosePlan()` currently
   flips the plan directly with no payment step; swap in
   `in_app_purchase` (wraps Play Billing + StoreKit) before shipping.
3. **Credit/Debit Notes** — `InvoiceRepository.createInvoice()` already
   accepts `docType` and `linkedInvoiceId`; add a screen that opens from an
   existing invoice's detail view, defaults line items from the original,
   and calls `createInvoice(docType: InvoiceDocType.creditNote, ...)`.
