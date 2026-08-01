/// Static content for the Help & Support and About Us sections.
///
/// Kept as plain Dart constants rather than fetched from Firestore: this
/// content must render with no network (Help is exactly what a user reaches
/// for when something isn't working), and it changes on release cadence,
/// not at runtime.
///
/// ---------------------------------------------------------------------
/// BEFORE RELEASE - two things here are placeholders and must be replaced:
///
///   1. [SupportContacts] - the phone number, WhatsApp number, email and
///      registered address below are invented. Ship real ones.
///   2. The Privacy Policy and Terms text is written to describe what this
///      app actually does, but it has NOT been reviewed by a lawyer. Have
///      counsel review both before publishing to any store, and re-check
///      the Privacy Policy against the app's real data flows whenever a
///      new SDK, permission or analytics tool is added.
/// ---------------------------------------------------------------------
library;

/// Where "Call Us" and "Help on WhatsApp" go, and who the legal documents
/// name as the operator.
class SupportContacts {
  SupportContacts._();

  /// PLACEHOLDER - replace with the real support line.
  static const String phoneNumber = '+91 80000 00000';

  /// PLACEHOLDER - replace with the real WhatsApp business number.
  /// Digits only, including country code, for wa.me links.
  static const String whatsappNumber = '918000000000';

  /// PLACEHOLDER - replace with the real support inbox.
  static const String email = 'support@receiptbook.example';

  /// PLACEHOLDER - replace with the registered business name and address.
  static const String companyName = 'ReceiptBook';
  static const String registeredAddress =
      'ReceiptBook, [registered office address], India';

  static const String supportHours = 'Monday to Saturday, 10 AM – 7 PM IST';

  /// Keep in step with `version:` in pubspec.yaml.
  static const String appVersion = '0.1.0';

  /// Prefilled first message, so the support agent starts with context
  /// instead of "hi".
  static const String whatsappGreeting =
      "Hi ReceiptBook support, I need help with the app.";
}

/// One entry in the FAQ list.
class FaqItem {
  final String question;
  final String answer;
  final String category;

  const FaqItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

/// Grouped by [FaqItem.category] in the UI, in the order they first appear
/// here - so the ordering of this list is the ordering on screen.
const List<FaqItem> kFaqs = [
  // ---- Getting started ----
  FaqItem(
    category: 'Getting started',
    question: 'What is ReceiptBook?',
    answer:
        'ReceiptBook is a record-keeping app for individuals and small businesses '
        'in India. You can scan and store receipts, track income and expenses, '
        'keep a customer and supplier ledger, generate GST-style invoices, and '
        'see a dashboard of how your business is doing. Everything is organised '
        'into "books", so your personal spending and your business accounts stay '
        'separate.',
  ),
  FaqItem(
    category: 'Getting started',
    question: 'What is the difference between an Individual Book and a Business Book?',
    answer:
        'An Individual Book is for personal income and expenses - scan receipts, '
        'categorise spending, and keep records handy for tax season.\n\n'
        'A Business Book adds everything a small business needs: sales and '
        'purchase bills, a products catalogue, customer and supplier ledgers, '
        'invoice templates, and the business dashboard. Your first Individual '
        'Book is created automatically when you sign up; Business Books are '
        'added separately.',
  ),
  FaqItem(
    category: 'Getting started',
    question: 'Can I keep more than one business in the app?',
    answer:
        'Yes. Each business gets its own Business Book with its own invoice '
        'numbering, parties, products and dashboard - nothing is mixed between '
        'them. How many Business Books you can use at once depends on your plan: '
        'the Single Book plan keeps one active at a time, and the Multi-Book '
        'plan keeps them all active. You can switch which book is active from '
        'Settings > Manage Books.',
  ),

  // ---- Receipts and records ----
  FaqItem(
    category: 'Receipts & records',
    question: 'How do I scan a receipt?',
    answer:
        'Tap the add button on your book, choose to capture or upload a receipt, '
        'and point the camera at it. The app reads the text on the receipt and '
        'suggests the amount, date and merchant so you do not have to type them '
        'in. Always check the suggested values before saving - a crumpled or '
        'faded receipt can be misread.',
  ),
  FaqItem(
    category: 'Receipts & records',
    question: 'Does the app work without internet?',
    answer:
        'Mostly, yes. Receipt scanning runs on your device, and entries you '
        'create offline are saved locally and sync automatically the next time '
        'you are online. Features that need the network - such as syncing across '
        'devices - wait until a connection is available.',
  ),
  FaqItem(
    category: 'Receipts & records',
    question: 'Can I attach a PDF or a file instead of a photo?',
    answer:
        'Yes. Alongside camera captures and gallery images, you can attach a '
        'file of any common format to an entry, which is useful for emailed '
        'bills and statements you never had on paper.',
  ),

  // ---- Bills and invoices ----
  FaqItem(
    category: 'Bills & invoices',
    question: 'How does invoice numbering work?',
    answer:
        'Invoice numbers increase automatically using the prefix set for your '
        'Business Book. You can choose to restart numbering at the beginning of '
        'each financial year, which is what most businesses do. The number is '
        'assigned when the bill is created and does not change if you edit the '
        'bill afterwards.',
  ),
  FaqItem(
    category: 'Bills & invoices',
    question: 'What is the Due Date on a bill?',
    answer:
        'The due date is when payment is expected. It defaults to seven days '
        'after the bill date, and you can change it to whatever terms you agreed '
        'with the party. The dashboard uses it to show which bills fall due in '
        'the next three days and which have already crossed their due date, and '
        'the Bills list has an Overdue filter built on the same dates.',
  ),
  FaqItem(
    category: 'Bills & invoices',
    question: 'Can I change how my invoices look?',
    answer:
        'Yes. Settings > Invoice Template has ten designs. Tap one to see a full '
        'sample invoice filled with example data, then apply it. Every invoice '
        'that book generates from then on uses that design.',
  ),
  FaqItem(
    category: 'Bills & invoices',
    question: 'Why does my invoice show CGST and SGST instead of IGST?',
    answer:
        'Tax is split based on where the customer is. When your business and '
        'your customer are in the same state, GST is shown as CGST plus SGST; '
        'when they are in different states, it is shown as IGST. Making sure '
        'your business state and each party\'s state are correct is what keeps '
        'this right.',
  ),

  // ---- Money and plans ----
  FaqItem(
    category: 'Plans & billing',
    question: 'What happens when my free trial ends?',
    answer:
        'Your data is never deleted when a trial ends. Business Book features '
        'become read-only until you choose a plan, and your Individual Book '
        'keeps working. Pick a plan from Settings > Manage Books to unlock them '
        'again.',
  ),
  FaqItem(
    category: 'Plans & billing',
    question: 'How do I change or cancel my plan?',
    answer:
        'Go to Settings > Manage Books and choose a different plan. If you '
        'subscribed through an app store, cancellation is handled in that '
        'store\'s subscription settings, and your plan stays active until the '
        'end of the period you have already paid for.',
  ),

  // ---- Data and account ----
  FaqItem(
    category: 'Data & account',
    question: 'Is my data safe?',
    answer:
        'Your records are stored in your own account and are not shared with '
        'other users. Data in transit is encrypted, and access requires signing '
        'in. We recommend also turning on the app lock so that anyone holding '
        'your unlocked phone still cannot open your books.',
  ),
  FaqItem(
    category: 'Data & account',
    question: 'Can I get my data out of the app?',
    answer:
        'Yes. Invoices can be shared or printed as PDFs, and the products '
        'catalogue can be exported to Excel. If you need a full copy of your '
        'records, write to us and we will help.',
  ),
  FaqItem(
    category: 'Data & account',
    question: 'How do I delete my account?',
    answer:
        'Write to ${SupportContacts.email} from the email address on your '
        'account and ask us to delete it. We will confirm the request, delete '
        'your books, entries and attachments, and keep only what the law '
        'requires us to retain. Deletion is permanent and cannot be undone, so '
        'export anything you want to keep first.',
  ),
  FaqItem(
    category: 'Data & account',
    question: 'I use two phones. Will my data be on both?',
    answer:
        'Yes. Sign in with the same account on each device and your books sync '
        'to both once they are online.',
  ),
];

/// A section of a long-form document (About / Privacy / Terms).
class DocSection {
  final String? heading;
  final List<String> paragraphs;
  final List<String> bullets;

  const DocSection({
    this.heading,
    this.paragraphs = const [],
    this.bullets = const [],
  });
}

/// A rendered long-form document.
class LegalDocument {
  final String title;

  /// Shown under the title. Users and reviewers both look for this.
  final String lastUpdated;
  final List<DocSection> sections;

  const LegalDocument({
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });
}

const String _lastUpdated = '1 August 2026';

const LegalDocument kAboutReceiptBook = LegalDocument(
  title: 'About ReceiptBook',
  lastUpdated: _lastUpdated,
  sections: [
    DocSection(
      paragraphs: [
        'ReceiptBook is a book-keeping app built for people who run small '
            'businesses in India, and for anyone who simply wants their receipts '
            'in one place instead of a drawer.',
        'Most small businesses do not lose money because they cannot read a '
            'balance sheet. They lose it because a receipt went missing, an '
            'invoice was never followed up, or nobody noticed a supplier payment '
            'was already two weeks late. ReceiptBook is built around those '
            'everyday gaps rather than around accounting theory.',
      ],
    ),
    DocSection(
      heading: 'What you can do with it',
      bullets: [
        'Scan a paper receipt and let the app read the amount, date and '
            'merchant for you, instead of typing them in.',
        'Keep personal and business records in separate books, so your '
            'household spending never lands in your business numbers.',
        'Raise GST-style sales and purchase bills, with tax split correctly '
            'between CGST, SGST and IGST based on the parties\' states.',
        'Track what customers owe you and what you owe suppliers, with due '
            'dates that tell you what is falling due and what is already late.',
        'See income, expenses, profit, cash flow and your fastest-moving '
            'products on one dashboard.',
        'Share or print an invoice as a PDF in one of ten designs.',
      ],
    ),
    DocSection(
      heading: 'How we think about your data',
      paragraphs: [
        'Your books are yours. We do not sell your data, and we do not show '
            'you advertising inside the app. We collect what the app needs to '
            'work and to be supportable, and no more. The Privacy Policy sets '
            'this out in full.',
      ],
    ),
    DocSection(
      heading: 'A word on tax',
      paragraphs: [
        'ReceiptBook helps you keep organised records and prepare documents. '
            'It is not a tax adviser, a chartered accountant or a legal service, '
            'and nothing it shows you is professional advice. For filings and '
            'anything with consequences, please consult a qualified '
            'professional.',
      ],
    ),
    DocSection(
      heading: 'Talk to us',
      paragraphs: [
        'We build this from feedback more than from roadmaps. If something is '
            'slow, confusing or missing, tell us - Help & Support has our '
            'WhatsApp number, phone line and email, and a real person reads '
            'every message.',
      ],
    ),
  ],
);

const LegalDocument kPrivacyPolicy = LegalDocument(
  title: 'Privacy Policy',
  lastUpdated: _lastUpdated,
  sections: [
    DocSection(
      paragraphs: [
        'This policy explains what ReceiptBook ("we", "us") collects when you '
            'use the app, why we collect it, and what control you have over it. '
            'We have tried to write it in plain language rather than in legal '
            'boilerplate.',
      ],
    ),
    DocSection(
      heading: '1. Information you give us',
      bullets: [
        'Account details: your name, email address and/or phone number, used '
            'to create and sign you into your account.',
        'Business details: the business name, address, GSTIN, logo and contact '
            'details you enter for a Business Book, which appear on the invoices '
            'you generate.',
        'Your records: transactions, receipts and attachments, bills, products, '
            'and the customers and suppliers you add, including any names, phone '
            'numbers and amounts you enter about them.',
        'Messages you send us when you contact support.',
      ],
    ),
    DocSection(
      heading: '2. Information collected automatically',
      bullets: [
        'Basic device and app information - device model, operating system '
            'version and app version - used to diagnose problems.',
        'Diagnostic and crash information when the app fails, so we can fix it.',
        'Dates and times of activity in your account, used to sync your data '
            'and to keep the account secure.',
      ],
      paragraphs: [
        'We do not track you across other apps or websites, and we do not '
            'build advertising profiles.',
      ],
    ),
    DocSection(
      heading: '3. Permissions the app asks for',
      bullets: [
        'Camera - to photograph receipts. Used only when you open the scanner.',
        'Photos and files - to attach an image or document you already have, '
            'and to save PDFs you export.',
        'Contacts - only if you choose to add a customer or supplier from your '
            'phone contacts. We read the contact you pick; we do not upload your '
            'address book.',
        'Biometrics - only to unlock the app if you turn on the app lock. The '
            'check happens on your device and we never receive your fingerprint '
            'or face data.',
      ],
      paragraphs: [
        'You can refuse or withdraw any of these permissions in your device '
            'settings. The related feature stops working, but the rest of the '
            'app continues to function.',
      ],
    ),
    DocSection(
      heading: '4. How we use your information',
      bullets: [
        'To provide the app: storing your records, syncing them across your '
            'devices, and generating your invoices and reports.',
        'To support you when you contact us.',
        'To keep the service secure and to investigate misuse.',
        'To improve the app, using aggregate patterns rather than the contents '
            'of your books.',
        'To meet legal and tax obligations that apply to us.',
      ],
      paragraphs: [
        'We do not sell your personal information, and we do not share it with '
            'advertisers.',
      ],
    ),
    DocSection(
      heading: '5. Who else can see it',
      bullets: [
        'Service providers who run our infrastructure - including cloud '
            'hosting, database, file storage and authentication providers - who '
            'process data only on our instructions.',
        'Anyone you deliberately share a document with, such as a customer you '
            'send an invoice to.',
        'Authorities, where we are legally required to disclose information.',
      ],
      paragraphs: [
        'Our infrastructure providers may store or process data on servers '
            'outside India. Where that happens we rely on the safeguards those '
            'providers offer under applicable data protection law.',
      ],
    ),
    DocSection(
      heading: '6. How long we keep it',
      paragraphs: [
        'We keep your records for as long as your account is active, because '
            'they are the whole point of the app. If you ask us to delete your '
            'account we remove your books, entries and attachments, keeping only '
            'what we are legally required to retain - for example, records of '
            'payments made to us.',
        'Backups are rotated on a schedule, so deleted data may persist in '
            'backups for a short period before it is overwritten.',
      ],
    ),
    DocSection(
      heading: '7. Security',
      paragraphs: [
        'Data sent between the app and our servers is encrypted in transit, '
            'access to your account requires authentication, and access to '
            'production systems inside our team is restricted to those who need '
            'it. The optional app lock adds a device-level check on top.',
        'No system is perfectly secure. Please use a strong, unique password, '
            'do not share your sign-in details, and tell us immediately if you '
            'think someone else has access to your account.',
      ],
    ),
    DocSection(
      heading: '8. Your choices',
      bullets: [
        'Access and correct: most of your information can be viewed and edited '
            'directly in the app.',
        'Export: invoices can be saved as PDFs and your products catalogue as '
            'an Excel file. Write to us if you need a fuller copy.',
        'Delete: write to us from your registered email address to have your '
            'account and its data deleted.',
        'Withdraw permissions: manage camera, files and contacts access in '
            'your device settings at any time.',
      ],
    ),
    DocSection(
      heading: '9. Children',
      paragraphs: [
        'ReceiptBook is meant for adults running their own finances or '
            'business. It is not directed at children, and we do not knowingly '
            'collect information from anyone under 18. If you believe a child '
            'has given us information, contact us and we will delete it.',
      ],
    ),
    DocSection(
      heading: '10. Changes to this policy',
      paragraphs: [
        'We update this policy when the app changes. The date at the top tells '
            'you when it was last revised, and we will tell you in the app '
            'before a significant change takes effect.',
      ],
    ),
    DocSection(
      heading: '11. Contact us',
      paragraphs: [
        'Questions about this policy, or about your data, can go to '
            '${SupportContacts.email}, or to ${SupportContacts.registeredAddress}. '
            'We aim to respond within a few working days.',
      ],
    ),
  ],
);

const LegalDocument kTermsAndConditions = LegalDocument(
  title: 'Terms & Conditions',
  lastUpdated: _lastUpdated,
  sections: [
    DocSection(
      paragraphs: [
        'These terms are the agreement between you and ${SupportContacts.companyName} '
            'for your use of the ReceiptBook app. Please read them - by creating '
            'an account or using the app, you accept them.',
      ],
    ),
    DocSection(
      heading: '1. Who can use ReceiptBook',
      paragraphs: [
        'You must be at least 18 years old and able to enter into a binding '
            'contract. If you use the app on behalf of a business, you confirm '
            'you are authorised to accept these terms for that business.',
      ],
    ),
    DocSection(
      heading: '2. Your account',
      paragraphs: [
        'You are responsible for keeping your sign-in details private and for '
            'everything done through your account. Tell us promptly if you '
            'suspect unauthorised access. Please keep your account information '
            'accurate and up to date.',
      ],
    ),
    DocSection(
      heading: '3. Plans, trials and payment',
      bullets: [
        'Some features - including Business Book features - require a paid '
            'plan. Current plans and prices are shown in the app.',
        'Free trials run for the stated period. When a trial ends without a '
            'plan, paid features become read-only. Your data is not deleted.',
        'Subscriptions renew automatically unless cancelled before the renewal '
            'date. Where you subscribed through an app store, billing and '
            'cancellation follow that store\'s rules.',
        'Prices may change. We will give you notice before a change affects a '
            'renewal, and you may cancel if you do not accept it.',
        'Except where the law requires otherwise, payments already made are '
            'not refundable for the period already served.',
      ],
    ),
    DocSection(
      heading: '4. Your content stays yours',
      paragraphs: [
        'The records, receipts, invoices and other content you put into '
            'ReceiptBook belong to you. You grant us only the permission we need '
            'to run the service - to store, back up, process and display that '
            'content to you and to anyone you choose to share it with.',
        'You are responsible for the content you enter, including having the '
            'right to enter details about other people, such as your customers '
            'and suppliers.',
      ],
    ),
    DocSection(
      heading: '5. Acceptable use',
      bullets: [
        'Do not use ReceiptBook for anything unlawful, including creating '
            'false or misleading invoices or records.',
        'Do not attempt to break, overload, reverse engineer or gain '
            'unauthorised access to the app or its systems.',
        'Do not upload malware, or content that infringes someone else\'s '
            'rights.',
        'Do not resell or redistribute the app or offer it as your own '
            'service.',
      ],
    ),
    DocSection(
      heading: '6. Accuracy, and what this app is not',
      paragraphs: [
        'ReceiptBook helps you keep records and prepare documents. It does not '
            'provide tax, accounting, legal or financial advice, and it is not a '
            'substitute for a qualified professional.',
        'Automated features - including reading text from a scanned receipt '
            'and calculating tax - can be wrong. Receipts may be misread and tax '
            'treatment depends on facts the app cannot know. You are responsible '
            'for checking every figure before you rely on it, send an invoice, '
            'or make a filing.',
      ],
    ),
    DocSection(
      heading: '7. Availability',
      paragraphs: [
        'We work to keep ReceiptBook available and reliable, but we do not '
            'promise uninterrupted service. We may suspend the app for '
            'maintenance, and features may change, be added or be withdrawn over '
            'time. We will give reasonable notice before withdrawing something '
            'significant.',
      ],
    ),
    DocSection(
      heading: '8. Keep your own copies',
      paragraphs: [
        'We take backups, but you should not treat the app as your only copy '
            'of anything important. Export the records you cannot afford to '
            'lose, particularly before deleting an account or a book.',
      ],
    ),
    DocSection(
      heading: '9. Limitation of liability',
      paragraphs: [
        'To the extent the law allows, we are not liable for indirect or '
            'consequential loss, or for lost profits, lost business or lost data '
            'arising from your use of the app. Our total liability in any '
            'twelve-month period is limited to the amount you paid us for the '
            'app in that period.',
        'Nothing in these terms limits liability that cannot lawfully be '
            'limited, including liability for fraud.',
      ],
    ),
    DocSection(
      heading: '10. Ending the agreement',
      paragraphs: [
        'You may stop using ReceiptBook and ask us to delete your account at '
            'any time. We may suspend or end your access if you seriously or '
            'repeatedly breach these terms, or where we are required to by law. '
            'Where it is reasonable to do so, we will tell you first and give '
            'you a chance to export your data.',
      ],
    ),
    DocSection(
      heading: '11. Governing law',
      paragraphs: [
        'These terms are governed by the laws of India, and the courts of '
            'India have jurisdiction over any dispute arising from them.',
      ],
    ),
    DocSection(
      heading: '12. Changes to these terms',
      paragraphs: [
        'We may update these terms as the app develops. The date at the top '
            'shows the latest version, and we will notify you in the app before '
            'a significant change takes effect. Continuing to use ReceiptBook '
            'after that means you accept the updated terms.',
      ],
    ),
    DocSection(
      heading: '13. Contact',
      paragraphs: [
        'Questions about these terms can go to ${SupportContacts.email}, or to '
            '${SupportContacts.registeredAddress}.',
      ],
    ),
  ],
);
