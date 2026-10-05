import '../../account_type/domain/account_type.dart';
import '../../account_type/domain/role_categories.dart';

/// Account setup rules shared with the website (js/common.js checklists and
/// js/features.js STEPS/FIELDS), so a member sees the same checklist and the
/// same step questions in the app and on the website.

bool real(Object? v) {
  if (v == null) return false;
  final s = v.toString().trim();
  return s.isNotEmpty && s.toLowerCase() != 'pending' && !s.toLowerCase().endsWith('.invalid');
}

typedef ProfileRow = Map<String, dynamic>;

class ChecklistItem {
  const ChecklistItem(this.title, this.desc, this.test);
  final String title;
  final String desc;
  final bool Function(ProfileRow p) test;
}

bool _list(Object? v) => v is List && v.isNotEmpty;
num _n(Object? v) => num.tryParse('${v ?? ''}') ?? 0;

final Map<AccountType, List<ChecklistItem>> checklists = {
  AccountType.worker: [
    ChecklistItem('Phone number', 'Your verified mobile number.', (p) => real(p['phone_number'])),
    ChecklistItem('Email', 'Add your own email so you can also sign in with it.', (p) => real(p['email'])),
    ChecklistItem('Basic profile', 'Add your name and account photo so clients can identify you.', (p) => real(p['full_name']) && real(p['profile_photo_url'])),
    ChecklistItem('Trade category', 'Choose your profession and specialties.', (p) => p['primary_job_category_id'] != null),
    ChecklistItem('About you', 'Add a short description of your work.', (p) => real(p['short_bio'])),
    ChecklistItem('Portfolio', 'Add completed works with images and descriptions.', (p) => _list(p['portfolio_photo_urls'])),
    ChecklistItem('Location', 'Add the city and region clients should use for your profile.', (p) => real(p['city_town']) && real(p['region'])),
    ChecklistItem('Years of experience', 'Tell clients how long you have worked professionally.', (p) => real(p['years_of_experience'])),
    ChecklistItem('Daily rate', 'Set what you charge per day.', (p) => _n(p['daily_rate_ghs']) > 0),
    ChecklistItem('Ghana Card', 'Upload the identity document required for BAID X verification.', (p) => real(p['ghana_card_front_url'])),
    ChecklistItem('Payout details', 'Add the Mobile Money account you get paid on.', (p) => real(p['payout_account'])),
  ],
  AccountType.company: [
    ChecklistItem('Phone number', 'Your verified mobile number.', (p) => real(p['contact_phone'])),
    ChecklistItem('Email', 'Add and verify the email used for notices.', (p) => real(p['contact_email'])),
    ChecklistItem('Basic profile', 'Add your company name and logo.', (p) => real(p['company_name']) && real(p['company_logo_url'])),
    ChecklistItem('Industry', 'Choose the industry your company works in.', (p) => real(p['industry_sector'])),
    ChecklistItem('About your company', 'Add a short description of what you do.', (p) => real(p['company_overview'])),
    ChecklistItem('Location', 'Add the city and region of your office.', (p) => real(p['city_town']) && real(p['region'])),
    ChecklistItem('Registration documents', 'Upload your registration number or certificate.', (p) => real(p['rgd_registration_number']) || real(p['business_registration_doc_url'])),
    ChecklistItem('Contact person', 'Add who we should speak to about this company.', (p) => real(p['contact_person_name'])),
    ChecklistItem('Contact Ghana Card', 'Upload the contact person\'s identity document.', (p) => real(p['contact_ghana_card_url'])),
    ChecklistItem('Payout details', 'Add the account used for payments.', (p) => real(p['payout_account'])),
  ],
  AccountType.projectManager: [
    ChecklistItem('Phone number', 'Your verified mobile number.', (p) => real(p['phone_number'])),
    ChecklistItem('Email', 'Add and verify the email used for notices.', (p) => real(p['email'])),
    ChecklistItem('Basic profile', 'Add your name and account photo.', (p) => real(p['full_name']) && real(p['profile_photo_url'])),
    ChecklistItem('Specialization', 'Choose the kind of projects you manage.', (p) => real(p['specialization'])),
    ChecklistItem('Experience', 'Add the years you have managed projects.', (p) => _n(p['years_managing_projects']) > 0),
    ChecklistItem('Past projects', 'Add projects you have delivered.', (p) => _list(p['past_projects_json'])),
    ChecklistItem('Location', 'Add the city and region you work from.', (p) => real(p['city_town']) && real(p['region'])),
    ChecklistItem('Ghana Card', 'Upload the identity document required for verification.', (p) => real(p['ghana_card_front_url'])),
    ChecklistItem('Certification', 'Upload a project management certificate if you have one.', (p) => real(p['certification_doc_url'])),
    ChecklistItem('Payout details', 'Add the account you get paid on.', (p) => real(p['payout_account'])),
  ],
  AccountType.business: [
    ChecklistItem('Phone number', 'Your verified mobile number.', (p) => real(p['contact_phone'])),
    ChecklistItem('Email', 'Add and verify the email used for notices.', (p) => real(p['contact_email'])),
    ChecklistItem('Basic profile', 'Add your business name and logo.', (p) => real(p['business_name']) && real(p['logo_url'])),
    ChecklistItem('Supply category', 'Choose the main thing you supply.', (p) => real(p['specialty'])),
    ChecklistItem('About your business', 'Add a tagline and description.', (p) => real(p['short_bio'])),
    ChecklistItem('Portfolio', 'Add photos of your products or past supply.', (p) => _list(p['portfolio_photo_urls'])),
    ChecklistItem('Location', 'Add the city and region of your shop or yard.', (p) => real(p['city_town']) && real(p['region'])),
    ChecklistItem('Registration documents', 'Upload your business registration.', (p) => real(p['rgd_registration_number']) || real(p['business_registration_doc_url'])),
    ChecklistItem('Ghana Card', 'Upload the owner\'s identity document.', (p) => real(p['ghana_card_front_url'])),
    ChecklistItem('Payout details', 'Add the account you get paid on.', (p) => real(p['payout_account'])),
  ],
  AccountType.employer: [
    ChecklistItem('Phone number', 'Your verified mobile number.', (p) => real(p['phone_number'])),
    ChecklistItem('Email', 'Add and verify an email address.', (p) => real(p['email'])),
    ChecklistItem('Basic profile', 'Add your name and account photo.', (p) => real(p['full_name']) && real(p['profile_photo_url'])),
    ChecklistItem('Location', 'Add where the work will be done.', (p) => real(p['city_town']) && real(p['region'])),
    ChecklistItem('What you hire for', 'Choose the trade you hire for most.', (p) => p['profile_sections'] is Map && real((p['profile_sections'] as Map)['need_category'])),
  ],
};

class ChecklistState {
  const ChecklistState(this.items, this.done);
  final List<(ChecklistItem, bool)> items;
  final int done;
  int get total => items.length;
  double get pct => total == 0 ? 0 : done / total;
}

/// A reviewer-verified account counts every item as done, like the website.
ChecklistState checklistState(AccountType type, ProfileRow p) {
  final verified = p['verification_status'] == 'verified';
  final items = [for (final i in checklists[type]!) (i, verified || i.test(p))];
  return ChecklistState(items, items.where((e) => e.$2).length);
}

String statusLabel(Object? v) => const {'verified': 'Verified', 'rejected': 'Rejected', 'resubmit_required': 'Resubmit', 'pending_verification': 'Under review'}[v] ?? 'Unverified';

// ---------- step questions ----------

enum FieldKind { text, area, number, select, bool, list, jobcat }

class StepField {
  const StepField(this.col, this.label, this.kind, {this.options = const [], this.hint, this.max});
  final String col; // "ps.x" = profile_sections.x
  final String label;
  final FieldKind kind;
  final List<(String, String)> options;
  final String? hint;
  final int? max;
}

const regions = ['Greater Accra', 'Ashanti', 'Central', 'Eastern', 'Western', 'Western North', 'Volta', 'Oti', 'Northern', 'Savannah', 'North East', 'Upper East', 'Upper West', 'Bono', 'Bono East', 'Ahafo'];
const _exp = [('<1', 'Under 1 year'), ('1-3', '1 to 3 years'), ('3-5', '3 to 5 years'), ('5-10', '5 to 10 years'), ('10+', '10+ years')];
const _avail = [('full_time', 'Full time'), ('part_time', 'Part time'), ('contract', 'Contract'), ('weekends_only', 'Weekends only')];
const _phase = [('structural', 'Structural'), ('electrical_mechanical', 'Electrical and mechanical'), ('plumbing_water', 'Plumbing and water'), ('finishing_interior', 'Finishing and interior'), ('exterior_compound', 'Exterior and compound'), ('support_general', 'Support and general')];
const _net = [('mtn_momo', 'MTN MoMo'), ('telecel_cash', 'Telecel Cash'), ('airteltigo_money', 'AirtelTigo Money')];
const _ind = [('real_estate_development', 'Real estate development'), ('construction', 'Construction'), ('property_management', 'Property management'), ('architecture_engineering', 'Architecture and engineering'), ('facilities_management', 'Facilities management'), ('other', 'Other')];
const _size = [('1-10', '1 to 10'), ('11-50', '11 to 50'), ('51-200', '51 to 200'), ('200+', 'More than 200')];
const _ent = [('sole_proprietorship', 'Sole proprietorship'), ('registered_company', 'Registered company'), ('partnership', 'Partnership')];
final _reg = [for (final r in regions) (r, r)];
final _supply = [for (final s in supplyCategories) (s.id, s.name)];
final _needs = [for (final s in clientNeeds) (s.id, s.name)];

final Map<String, StepField> _fields = {
  for (final f in <StepField>[
    const StepField('full_name', 'Full name', FieldKind.text),
    const StepField('company_name', 'Company name', FieldKind.text),
    const StepField('business_name', 'Business name', FieldKind.text),
    const StepField('short_bio', 'Short bio', FieldKind.area, hint: 'One or two lines about your work', max: 280),
    const StepField('company_overview', 'About the company', FieldKind.area, max: 600),
    const StepField('primary_job_category_id', 'Main trade', FieldKind.jobcat),
    const StepField('has_own_tools', 'I have my own tools', FieldKind.bool),
    const StepField('years_of_experience', 'Experience', FieldKind.select, options: _exp),
    const StepField('availability_type', 'Availability', FieldKind.select, options: _avail),
    const StepField('daily_rate_ghs', 'Daily rate (GH₵)', FieldKind.number),
    StepField('region', 'Region', FieldKind.select, options: _reg),
    const StepField('city_town', 'Town', FieldKind.text),
    const StepField('specific_area', 'Area or neighbourhood', FieldKind.text),
    const StepField('willing_to_travel_km', 'Willing to travel (km)', FieldKind.number),
    const StepField('physical_address', 'Address', FieldKind.text),
    const StepField('payout_method', 'Payout network', FieldKind.select, options: _net),
    const StepField('payout_account', 'Payout number', FieldKind.text),
    const StepField('payout_account_name', 'Payout account name', FieldKind.text),
    const StepField('industry_sector', 'Industry', FieldKind.select, options: _ind),
    const StepField('company_size', 'Company size', FieldKind.select, options: _size),
    const StepField('specialization', 'Main specialty', FieldKind.select, options: _phase),
    const StepField('specialization_tags', 'Specialties (comma separated)', FieldKind.list),
    StepField('specialty', 'What you supply', FieldKind.select, options: _supply),
    const StepField('entity_type', 'Business type', FieldKind.select, options: _ent),
    StepField('ps.need_category', 'Trade you hire for most', FieldKind.select, options: _needs),
    const StepField('ghana_card_number', 'Ghana Card number', FieldKind.text, hint: 'GHA-000000000-0'),
    const StepField('ps.ghana_card_number', 'Ghana Card number', FieldKind.text, hint: 'GHA-000000000-0'),
    const StepField('rgd_registration_number', 'Registrar General (RGD) number', FieldKind.text),
    const StepField('tin_number', 'Tax Identification Number (TIN)', FieldKind.text),
    const StepField('contact_ghana_card_number', 'Contact person\'s Ghana Card number', FieldKind.text),
    const StepField('contact_person_name', 'Contact person', FieldKind.text),
    const StepField('contact_person_title', 'Contact title', FieldKind.text),
    const StepField('years_managing_projects', 'Years managing projects', FieldKind.number),
    const StepField('projects_managed_count', 'Projects managed', FieldKind.number),
  ])
    f.col: f,
};

/// Storage bucket for each uploaded column (private documents vs public photos).
const fileBuckets = {
  'ghana_card_front_url': 'ghana-cards',
  'ghana_card_back_url': 'ghana-cards',
  'ps.ghana_card_front': 'ghana-cards',
  'ps.ghana_card_back': 'ghana-cards',
  'contact_ghana_card_url': 'ghana-cards',
  'business_registration_doc_url': 'business-docs',
};
const fileLabels = {
  'ghana_card_front_url': 'Ghana Card, front',
  'ghana_card_back_url': 'Ghana Card, back',
  'ps.ghana_card_front': 'Ghana Card, front',
  'ps.ghana_card_back': 'Ghana Card, back',
  'contact_ghana_card_url': 'Contact person\'s Ghana Card',
  'business_registration_doc_url': 'Business registration document',
};

/// Profile photo column, bucket and label per account type.
(String, String, String) photoOf(AccountType t) => switch (t) {
      AccountType.company => ('company_logo_url', 'company-logos', 'Company logo'),
      AccountType.business => ('logo_url', 'logos', 'Business logo'),
      _ => ('profile_photo_url', 'portfolios', 'Profile photo'),
    };

class StepSpec {
  const StepSpec({this.fields = const [], this.files = const [], this.photo = false, this.phone = false, this.email = false, this.web = false, this.blurb});
  final List<StepField> fields;
  final List<String> files;
  final bool photo;
  final bool phone;
  final bool email;

  /// Done on the website for now (portfolio galleries, certificates).
  final bool web;
  final String? blurb;
}

StepSpec stepSpec(AccountType t, String title) {
  List<StepField> f(List<String> cols) => [for (final c in cols) ?_fields[c]];
  final card = t == AccountType.employer ? ['ps.ghana_card_number', 'ps.ghana_card_front', 'ps.ghana_card_back'] : ['ghana_card_number', 'ghana_card_front_url', 'ghana_card_back_url'];
  final biz = t == AccountType.company || t == AccountType.business;
  return switch (title) {
    'Phone number' => const StepSpec(phone: true),
    'Email' => const StepSpec(email: true, blurb: 'Your own email, for notices and as another way to sign in.'),
    'Basic profile' => StepSpec(photo: true, fields: f([t.nameColumn]), blurb: biz ? 'Your name and logo are what people see first.' : 'Your name and photo are what people see first.'),
    'Trade category' => StepSpec(fields: f(['primary_job_category_id', 'has_own_tools']), blurb: 'Pick the trade clients should find you under.'),
    'Specialization' => StepSpec(fields: f(['specialization', 'specialization_tags'])),
    'Industry' => StepSpec(fields: f(['industry_sector', 'company_size'])),
    'Supply category' => StepSpec(fields: f(['specialty', 'entity_type'])),
    'What you hire for' => StepSpec(fields: f(['ps.need_category'])),
    'About you' => StepSpec(fields: f(['short_bio']), blurb: 'One or two lines in your own words.'),
    'About your company' => StepSpec(fields: f(['company_overview'])),
    'About your business' => StepSpec(fields: f(['short_bio'])),
    'Portfolio' => const StepSpec(web: true, blurb: 'Add photos of finished work. They are public on your profile.'),
    'Past projects' => const StepSpec(web: true, blurb: 'Add projects you have delivered.'),
    'Certification' => const StepSpec(web: true, blurb: 'Upload a project management certificate if you have one.'),
    'Location' => StepSpec(
        fields: f(t == AccountType.worker ? ['region', 'city_town', 'specific_area', 'willing_to_travel_km'] : biz ? ['region', 'city_town', 'physical_address'] : ['region', 'city_town']),
        blurb: 'Where clients should look for you.'),
    'Years of experience' => StepSpec(fields: f(['years_of_experience'])),
    'Experience' => StepSpec(fields: f(['years_managing_projects', 'projects_managed_count'])),
    'Daily rate' => StepSpec(fields: f(['daily_rate_ghs', 'availability_type']), blurb: 'What you charge per day. You can change it any time.'),
    'Ghana Card' => StepSpec(fields: f([card[0]]), files: [card[1], card[2]], blurb: 'Private. Only you and BAID X reviewers can open it.'),
    'Contact person' => StepSpec(fields: f(['contact_person_name', 'contact_person_title'])),
    'Contact Ghana Card' => StepSpec(fields: f(['contact_ghana_card_number']), files: const ['contact_ghana_card_url'], blurb: 'Private. Only you and BAID X reviewers can open it.'),
    'Registration documents' => StepSpec(fields: f(['rgd_registration_number', 'tin_number']), files: const ['business_registration_doc_url'], blurb: 'Enter your registration number or upload the certificate.'),
    'Payout details' => StepSpec(fields: f(['payout_method', 'payout_account', 'payout_account_name']), blurb: 'Where you get paid. Withdrawals always need your password.'),
    _ => const StepSpec(web: true),
  };
}

/// Reads a column, including "ps.x" (profile_sections.x).
Object? valueOf(ProfileRow p, String col) => col.startsWith('ps.') ? (p['profile_sections'] is Map ? (p['profile_sections'] as Map)[col.substring(3)] : null) : p[col];
