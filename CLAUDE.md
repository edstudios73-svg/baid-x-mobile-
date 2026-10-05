# BAID X — Flutter Application

Claude Code Project Instructions

Project: BAID X Infrastructure
Platform: Flutter Mobile Application
Backend: Supabase
Repository: edstudios73-svg/baid-x
Primary branch: main
Current development environment: Windows
Flutter: 3.47.4
Dart: 3.13.3
Android SDK: 36.0.0
Development AI: Claude Code

This file is the primary project instruction document for Claude Code.

## 1. PROJECT IDENTITY

BAID X is an African technology startup building digital infrastructure for the workforce.

The application connects:

- Skilled workers
- Employers / individuals
- Businesses
- Project managers
- Companies / enterprises
- Projects
- Jobs
- Equipment
- Materials
- Payments
- Verification
- Reviews
- Professional relationships

The long-term objective is to build trusted infrastructure for how work, skills, projects and opportunities move across Africa.

### Core positioning

BAID X is trust infrastructure, not just profiles.

The platform should help users discover trusted people, organize work, manage projects, communicate, make payments and build long-term professional relationships.

### Brand philosophy

The future of work in Africa isn't about connections — it's about capability.

BAID X should feel:

- Professional
- African
- Modern
- Reliable
- Simple
- Practical
- Scalable
- Technology-driven
- Trustworthy

Do not turn the application into a generic social network.

## 2. IMPORTANT DEVELOPMENT RULE

DO NOT REBUILD THE PROJECT FROM SCRATCH

This is an existing BAID X Flutter application.

Claude Code must:

- Inspect the existing project first.
- Understand the existing architecture.
- Read this CLAUDE.md.
- Read BAID_X_PROJECT_HANDOVER.html if present.
- Inspect the current Git state.
- Understand existing Supabase integration.
- Preserve working functionality.
- Make incremental changes.

Never assume the project is empty.

Never replace the existing architecture simply because another architecture looks cleaner.

Never delete working code without understanding why it exists.

## 3. CURRENT PROJECT STATUS

The project has already been started and developed in Flutter.

The repository is connected to GitHub:

edstudios73-svg/baid-x

The primary branch is:

main

The project has previously been verified as clean and synchronized with GitHub.

A project handover document exists:

BAID_X_PROJECT_HANDOVER.html

If the file exists, read it before making substantial changes.

The handover document contains additional information about the current implementation and development state.

## 4. DEVELOPMENT ENVIRONMENT

The known development environment is:

### Operating system

Windows 11 Pro

### Flutter

Flutter 3.47.4 stable

### Dart

Dart 3.13.3

### Android SDK

Android SDK 36.0.0

### Backend

Supabase

### Repository

GitHub:

edstudios73-svg/baid-x

### Development tools

The project may be opened with:

- Claude Code
- Cursor
- VS Code
- Android Studio

Claude Code is currently the primary AI development environment.

## 5. FIRST ACTIONS WHEN CLAUDE OPENS THE PROJECT

Before modifying anything, Claude Code should perform the following:

### Step 1 — Read this file

Read:

CLAUDE.md

### Step 2 — Check the project structure

Inspect:

- lib/
- android/
- ios/
- test/
- pubspec.yaml
- configuration files
- Supabase-related files
- authentication files
- routing/navigation
- models
- services
- repositories
- providers/controllers/state management
- screens/widgets

### Step 3 — Read the handover

If available:

BAID_X_PROJECT_HANDOVER.html

### Step 4 — Check Git

Run:

```text
git status
```

Then inspect:

```text
git branch
git log --oneline -10
```

Do not reset, revert or delete changes automatically.

### Step 5 — Inspect Flutter

Run:

```text
flutter --version
flutter doctor
```

### Step 6 — Inspect dependencies

Read:

pubspec.yaml

Do not automatically upgrade dependencies.

### Step 7 — Run the project

Use the appropriate available emulator/device.

First verify that the application currently builds before making major changes.

## 6. ARCHITECTURE PRINCIPLES

BAID X should remain modular and scalable.

Use clear separation between:

```text
Presentation
    ↓
Application / State
    ↓
Domain / Models
    ↓
Data / Services
    ↓
Supabase
```

The exact existing architecture takes precedence over this conceptual model.

Do not introduce a completely different architecture unless there is a strong technical reason and the change is explicitly approved.

## 7. RECOMMENDED PROJECT STRUCTURE

Where compatible with the existing project, prefer a structure similar to:

```text
lib/
├── main.dart
│
├── app/
│   ├── app.dart
│   ├── router/
│   ├── theme/
│   └── config/
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── utils/
│   ├── services/
│   └── widgets/
│
├── features/
│   ├── auth/
│   ├── onboarding/
│   ├── home/
│   ├── jobs/
│   ├── projects/
│   ├── workers/
│   ├── employers/
│   ├── businesses/
│   ├── project_managers/
│   ├── companies/
│   ├── equipment/
│   ├── materials/
│   ├── payments/
│   ├── verification/
│   ├── notifications/
│   ├── messaging/
│   ├── profile/
│   └── settings/
│
└── shared/
    ├── models/
    ├── widgets/
    └── components/
```

However:

The existing repository structure always takes priority.

Do not reorganize the entire project just to match this structure.

## 8. SUPABASE

Supabase is the backend for BAID X.

Supabase may be used for:

- Authentication
- PostgreSQL database
- Row Level Security
- User profiles
- Roles
- Projects
- Jobs
- Businesses
- Workers
- Companies
- Project managers
- Messages
- Notifications
- Reviews
- Verification data
- Payments metadata
- Subscriptions
- Storage
- Realtime functionality

Claude must understand the existing Supabase implementation before changing it.

### NEVER replace Supabase

- Do not migrate BAID X to another backend unless explicitly instructed.
- Do not create a second backend.
- Do not bypass Supabase authentication.
- Do not create fake authentication systems.
- Do not hard-code authenticated users.

## 9. AUTHENTICATION RULES

BAID X authentication must use the actual Supabase authentication system.

Expected authentication functionality includes:

- Email/password authentication
- Email verification
- Google OAuth where configured
- Sign in
- Sign up
- Sign out
- Session persistence
- Password reset
- Profile creation
- Authentication state handling

There have previously been authentication issues involving:

- Email verification returning to the homepage without the expected session.
- Google OAuth not completing the expected sign-in flow.

If these issues are still present, debug the existing implementation.

- Do not bypass authentication to make the application appear to work.
- Do not automatically create fake sessions.
- Do not remove email verification.
- Do not remove OAuth.

## 10. USER ROLES

The current BAID X role structure is:

### 1. Worker

For skilled professionals such as:

- Mason
- Electrician
- Carpenter
- Plumber
- Technician
- Driver
- Designer
- Developer
- Other skilled professionals

Workers should be able to build professional profiles and participate in jobs/projects.

### 2. Employer / Individual

For individuals who need to find or hire people for work.

Important:

Employer / Individual is an account type under the company/employer ecosystem.

Do not incorrectly treat this role as the same thing as a marketplace Business profile.

### 3. Business

A Business profile is primarily for:

- Materials
- Equipment
- Products
- Rentals
- Listings
- Sales

Examples:

- Cement
- Sand
- Quarry dust
- PPE
- Shovels
- Excavators
- Trucks
- Construction materials
- Equipment

Important:

A Business profile is NOT automatically an employer/hiring role.

Do not use Business as a replacement for Employer or Company.

### 4. Project Manager

Project Managers manage projects and teams.

A Project Manager may handle:

- Projects
- Tasks
- Workers
- Reports
- Expenses
- Payments
- Completion
- Communication
- Company assignments

### 5. Company / Enterprise

Companies and enterprises can:

- Create projects
- Assign project managers
- Manage workers
- Manage company users
- Approve project manager access
- Manage payments
- Manage subscriptions
- Manage company information
- Monitor projects

## 11. PROJECT MANAGER ↔ COMPANY WORKFLOW

The company/project-manager relationship is important.

Expected workflow:

```text
Company
   ↓
Creates / assigns PM ID
   ↓
Project Manager enters ID
   ↓
Company receives access request
   ↓
Company approves
   ↓
PM gets access
   ↓
PM manages projects
```

The PM may then:

- View assigned projects
- Manage tasks
- Invite workers
- Submit reports
- Track expenses
- Track payments
- Mark work complete

Worker invitations should support configurable company approval where applicable.

Do not simplify this workflow into an unrestricted relationship.

## 12. CORE PRODUCT AREAS

The application should eventually support:

### Home

Potential areas:

- Jobs
- Projects
- Equipment
- Materials
- Verified professionals
- Project managers
- Marketplace listings
- Recommended opportunities

### Jobs

Users should be able to discover and manage relevant jobs.

Potential functionality:

- Job creation
- Job discovery
- Job details
- Applications
- Worker selection
- Job status
- Completion
- Reviews

### Projects

Projects are a major BAID X feature.

Projects may contain:

- Project information
- Client/company
- Project manager
- Workers
- Tasks
- Expenses
- Reports
- Payments
- Progress
- Completion status

### Equipment

Equipment listings can include:

- Excavators
- Trucks
- Tools
- Machinery
- Construction equipment

Support appropriate:

- Sale
- Rental
- Availability
- Owner/business
- Location
- Pricing

### Materials

Examples:

- Cement
- Sand
- Quarry dust
- Blocks
- PPE
- Construction materials

Businesses can create listings.

### Workers

Worker profiles should focus on professional capability.

Potential information:

- Name
- Skills
- Experience
- Location
- Portfolio
- Work history
- Ratings/reviews
- Verification
- Availability
- Completed work

Remember:

BAID X is about capability and trust, not vanity profiles.

## 13. TRUST & VERIFICATION

Trust is one of BAID X's major differentiators.

The system should eventually support:

- Identity verification
- Professional verification
- Work history
- Completed jobs
- Reviews
- Ratings
- Payment history where appropriate
- Repeat partnerships
- Verification status

Important distinction:

Verification is separate from the "Verified" subscription plan.

Do not automatically equate:

Paid subscription = verified professional

They are separate concepts.

## 14. SUBSCRIPTIONS

The planned BAID X monetization model is primarily subscription-based rather than relying heavily on large payment commissions.

Potential plans:

- Access
- Pro
- Verified
- Enterprise

Role-specific pricing may apply.

Examples previously considered include:

- Worker
- Project Manager
- Business
- Company

Subscription functionality may eventually include:

- Monthly billing
- Annual billing
- Trial period
- Founding-user discounts
- Price lock
- Upgrade
- Downgrade
- Failed payment handling
- Cancellation
- Refund rules

Do not implement payment processing based on assumptions.

If payment providers are not yet connected, clearly separate:

UI / architecture

from:

LIVE PAYMENT PROCESSING

Potential Ghana payment providers include:

- MTN MoMo
- Hubtel
- Paystack

Do not pretend a payment was completed when the provider is not actually connected.

## 15. UI/UX RULES

BAID X is mobile-first.

The application should feel like a serious production mobile application, not a website placed inside a phone.

Priorities:

- Simple navigation
- Clear hierarchy
- Fast interaction
- Minimal clutter
- Professional typography
- Strong spacing
- Responsive layouts
- Accessible controls
- Consistent components

Avoid:

- Huge overlapping cards
- Excessive decorative elements
- Unnecessary animations
- Excessive gradients
- Excessive glowing effects
- Unnecessary scrolling
- Social-media-style clutter

The interface should be modern without becoming visually complicated.

## 16. RESPONSIVE DESIGN

The app should work across:

- Small Android phones
- Large Android phones
- Tablets
- Larger screens where appropriate

Never hard-code a layout for one specific phone.

Avoid:

```text
width: 390
```

or similar fixed screen assumptions unless genuinely necessary.

Prefer:

- MediaQuery
- LayoutBuilder
- Flexible layouts
- Expanded/Flexible
- Responsive constraints
- Adaptive navigation

## 17. BRANDING

BAID X branding should remain consistent.

Use the existing project theme and brand configuration where available.

- Do not invent new brand colors.
- Do not randomly redesign the logo.
- Do not add glow effects to the logo unless explicitly requested.

The logo is primarily intended for:

- Landing/home experience
- Loading/splash experience

The logo should not be unnecessarily repeated throughout every screen.

## 18. NAVIGATION

Navigation should remain predictable.

Depending on the existing implementation, the application may use:

- Bottom navigation
- Navigation rail
- Drawer
- Nested routes
- GoRouter
- Flutter Navigator

Do not replace the existing navigation system without understanding it.

Every new feature should integrate into the current navigation architecture.

Avoid creating multiple competing navigation systems.

## 19. STATE MANAGEMENT

Use the existing state-management solution in the repository.

Do not introduce a second state-management framework without a strong reason.

Before adding state:

- Find how existing features manage state.
- Follow the existing pattern.
- Keep business logic outside presentation widgets where appropriate.
- Avoid unnecessarily large StatefulWidgets.
- Avoid duplicated state.

## 20. DATA MODELS

Models should represent real BAID X entities.

Potential models include:

- User
- Profile
- Worker
- Employer
- Business
- Company
- ProjectManager
- Project
- Task
- Job
- Application
- Equipment
- Material
- Listing
- Review
- Verification
- Subscription
- Payment
- Notification
- Message

Do not create duplicate models representing the same database entity.

Before creating a new model, search the repository.

## 21. DATABASE RULES

When modifying Supabase database functionality:

- Inspect existing schema.
- Inspect existing migrations.
- Check existing relationships.
- Check Row Level Security.
- Preserve existing data.
- Avoid destructive migrations.
- Explain potentially destructive changes before executing them.

Never casually execute:

```text
DROP TABLE
```

or destructive operations.

Do not disable RLS just to make a feature work.

Security is part of the product.

## 22. SECURITY

Never commit secrets.

Do not commit:

- Supabase service-role keys
- Private API keys
- Payment secrets
- OAuth secrets
- Private certificates
- Keystores/passwords
- Production credentials

Use environment/configuration mechanisms appropriate to the project.

Never expose a Supabase service-role key inside Flutter client code.

The Flutter application must only use client-safe credentials.

## 23. ERROR HANDLING

Production code should handle failures gracefully.

Do not expose raw technical errors to users.

Bad:

```text
PostgrestException: JWT expired...
```

Prefer:

```text
Your session has expired. Please sign in again.
```

Log useful debugging information during development without exposing secrets.

Handle:

- Network failures
- Authentication failures
- Database errors
- Empty states
- Permission errors
- Loading states
- Timeout situations
- Invalid input
- Offline situations where applicable

## 24. LOADING STATES

Every asynchronous production feature should consider:

- Loading
- Success
- Empty
- Error

Do not leave users staring at blank screens.

Avoid excessive spinners.

Use appropriate skeletons/placeholders where the design supports them.

## 25. FORMS

Forms must have:

- Validation
- Clear labels
- Useful error messages
- Proper keyboard types
- Loading states
- Disabled states during submission
- Success feedback
- Failure feedback

Never allow a button to trigger duplicate submissions because of rapid taps.

## 26. FILES & IMAGES

When working with images:

- Compress appropriately
- Avoid unnecessarily huge assets
- Use caching where appropriate
- Handle failed image loading
- Provide placeholders
- Respect Supabase Storage policies

Do not put huge raw image assets into the repository unnecessarily.

## 27. PERFORMANCE

Keep BAID X performant.

Avoid:

- Heavy rebuilds
- Unnecessary database queries
- Repeated network requests
- Loading entire datasets when pagination is appropriate
- Huge images
- Unnecessary animations
- Blocking the UI thread

For lists that may grow large, consider pagination or lazy loading.

## 28. OFFLINE / NETWORK AWARENESS

The application should gracefully handle poor network conditions.

Ghana/African users may have:

- Slow connections
- Unstable mobile networks
- Temporary outages
- Limited data

Do not design features assuming perfect internet.

Where appropriate:

- Cache data
- Show connection errors
- Retry safely
- Prevent duplicate submissions
- Preserve user input where possible

## 29. TESTING

Before considering a feature complete, run appropriate checks.

At minimum:

```text
flutter analyze
```

and:

```text
flutter test
```

If appropriate:

```text
flutter build apk --debug
```

For release validation:

```text
flutter build apk --release
```

Do not claim a feature works without testing it when testing is available.

## 30. GIT RULES

Git is the source of truth for the application code.

Before significant work:

```text
git status
```

After significant work:

```text
git diff
```

Before committing:

```text
flutter analyze
flutter test
```

Do not automatically push to GitHub unless explicitly requested.

Do not run destructive Git commands such as:

```text
git reset --hard
git clean -fd
git push --force
```

unless explicitly authorized.

Never discard user changes simply to make the working tree clean.

## 31. COMMIT STYLE

Use meaningful commit messages.

Examples:

```text
feat: add worker profile flow
feat: implement project manager dashboard
fix: resolve email verification session handling
fix: correct Google OAuth callback
refactor: simplify project repository
chore: update Flutter dependencies
docs: update BAID X project handover
```

Avoid:

```text
update
changes
stuff
fix
test
```

## 32. DEPENDENCY RULES

Do not add a package simply because it is convenient.

Before adding a dependency:

- Check whether Flutter/Dart already provides the functionality.
- Check existing dependencies.
- Determine whether a package is actively maintained.
- Consider package size.
- Consider security.
- Consider compatibility with the current Flutter version.

Do not randomly upgrade every package.

Avoid unnecessary dependency churn.

## 33. CLAUDE CODE WORKFLOW

When asked to implement a feature:

### Phase 1 — Understand

Inspect relevant files.

### Phase 2 — Plan

Explain briefly:

- What will change
- Which files will change
- What database changes are needed
- What risks exist

### Phase 3 — Implement

Make the smallest clean changes necessary.

### Phase 4 — Validate

Run:

```text
flutter analyze
```

and relevant tests.

### Phase 5 — Review

Check:

- UI
- navigation
- authentication
- database access
- error handling
- responsive behavior
- security

### Phase 6 — Report

Tell the user:

- What changed
- Files changed
- Tests performed
- Any remaining issues

Do not hide errors.

## 34. DO NOT MAKE UNAUTHORIZED PRODUCT DECISIONS

Claude Code should implement the requested product direction, not invent major product decisions.

Do not independently change:

- User roles
- Pricing
- Subscription structure
- Brand identity
- Business model
- Authentication strategy
- Database architecture
- Core navigation
- Monetization
- Verification policy

If a major product decision is required, explain the options and ask before making a permanent decision.

## 35. DO NOT REDESIGN WITHOUT BEING ASKED

If the user asks:

"Fix this button"

Do not redesign the entire screen.

If the user asks:

"Fix authentication"

Do not rebuild the authentication system.

If the user asks:

"Add project creation"

Do not redesign the entire dashboard.

Make focused changes.

## 36. PRESERVE EXISTING FUNCTIONALITY

Before changing a feature, understand what it currently does.

A new change must not silently break:

- Authentication
- Navigation
- Existing profiles
- Supabase queries
- Existing dashboards
- Existing forms
- Existing subscriptions
- Existing project functionality

When modifying shared code, check all known consumers.

## 37. AUTHENTICATION ENVIRONMENT

Authentication behavior may differ between:

- Development
- Production

Always distinguish:

- Local development URL
- Production URL
- Supabase project URL
- OAuth redirect URL
- Deep-link configuration
- Android intent configuration

Never hard-code a development callback into production.

## 38. ANDROID

The Android application must remain compatible with the configured Flutter/Android toolchain.

When changing Android files:

- Inspect existing Gradle configuration.
- Preserve package/application ID.
- Preserve signing configuration.
- Avoid unnecessary Gradle upgrades.
- Check Android manifest changes carefully.
- Test on an Android device/emulator.

Do not change package identifiers casually.

## 39. CURRENT DEVELOPMENT DEVICES

The project has previously been tested with Android emulators/devices.

One known environment used:

- Genymotion
- Android 15
- API 35

The exact device may differ on another computer.

Do not assume the old emulator exists.

Discover available devices using:

```text
flutter devices
```

## 40. NEW COMPUTER SETUP

When moving BAID X to another PC:

### Install

- Git
- Flutter
- Android Studio / Android SDK
- Android platform tools
- Java/JDK required by Flutter/Android tooling
- Claude Code
- Optional: Cursor / VS Code

### Verify

```text
git --version
flutter --version
flutter doctor
```

### Clone

```text
git clone https://github.com/edstudios73-svg/baid-x.git
```

### Enter project

```text
cd baid-x
```

### Install dependencies

```text
flutter pub get
```

### Check devices

```text
flutter devices
```

### Analyze

```text
flutter analyze
```

### Run

```text
flutter run
```

## 41. ENVIRONMENT VARIABLES ON A NEW PC

A Git clone does NOT automatically restore ignored local environment files.

Before moving computers, ensure required configuration is backed up securely.

Potential files may include:

- .env
- .env.local
- .env.development
- .env.production

depending on the project's implementation.

If these files are intentionally ignored by Git, do not assume they exist after cloning.

Recreate them from the secure backup.

Never put production secrets into CLAUDE.md.

## 42. PROJECT HANDOVER DOCUMENT

If this file exists:

BAID_X_PROJECT_HANDOVER.html

Claude Code should read it.

It is supplementary to this document.

Priority:

```text
Actual source code
        ↓
Current Supabase/database configuration
        ↓
CLAUDE.md
        ↓
BAID_X_PROJECT_HANDOVER.html
```

If there is a contradiction, inspect the actual implementation and report the discrepancy.

## 43. WHEN SOMETHING IS BROKEN

Do not immediately rewrite the feature.

Use this debugging order:

1. Reproduce
2. Read error
3. Identify affected layer
4. Inspect relevant code
5. Check configuration
6. Check Supabase/auth/network
7. Apply smallest fix
8. Test
9. Re-test related functionality

Do not hide errors with:

```dart
catch (_) {}
```

Do not solve a backend problem by creating fake frontend data.

Do not solve an authentication problem by bypassing authentication.

## 44. DATABASE DEBUGGING

When a Supabase feature fails, determine whether the problem is:

```text
Flutter UI
↓
State management
↓
Service/repository
↓
Supabase client
↓
Authentication/session
↓
RLS
↓
Database schema
```

Do not assume the UI is the problem.

Likewise, do not modify database security policies just because the Flutter UI receives an error.

## 45. EMPTY STATES

BAID X may initially have limited users and content.

Do not make empty screens look broken.

Use useful empty states such as:

```text
No jobs available yet.
Check back soon or create your first opportunity.
```

But do not fill production feeds with fake users/jobs unless explicitly requested for development/demo purposes.

Clearly separate:

Demo data

from:

Production data

## 46. NOTIFICATIONS

Notifications may eventually support:

- Job updates
- Project updates
- Worker invitations
- Company approvals
- Messages
- Payment updates
- Verification updates
- Subscription updates

Do not claim push notifications are fully functional until the required backend/mobile infrastructure is actually implemented and tested.

## 47. MESSAGING

Messaging should be professional and work-oriented.

Potential uses:

- Employer ↔ Worker
- Company ↔ PM
- PM ↔ Worker
- Business ↔ Customer
- Project communication

Do not turn the feature into an unrestricted social media feed.

## 48. ANALYTICS

Analytics should not compromise privacy.

If analytics are implemented:

- Track meaningful product events.
- Avoid unnecessary personal data.
- Do not expose private information.
- Separate analytics from authentication logic.

## 49. ACCESSIBILITY

Consider:

- Readable text
- Adequate touch targets
- Good contrast
- Semantic labels
- Keyboard/input behavior
- Screen-reader compatibility where practical

Do not sacrifice usability for visual effects.

## 50. CODE QUALITY

Prefer:

- Small reusable widgets
- Clear naming
- Single responsibility
- Typed models
- Strong null safety
- Explicit error handling
- Reusable services
- Clean imports

Avoid:

- Giant files
- Giant widgets
- Duplicate logic
- Magic strings
- Magic numbers
- Dead code
- Commented-out abandoned implementations

Do not refactor unrelated code during a feature task unless necessary.

## 51. NAMING

Use clear Dart naming conventions.

Classes:

```text
WorkerProfile
ProjectManagerDashboard
CompanyService
ProjectRepository
```

Methods:

```text
createProject()
fetchWorkerProfile()
updateSubscription()
```

Variables:

```text
currentUser
projectId
isLoading
```

Do not use vague names such as:

```text
data
stuff
thing
temp
abc
x
```

unless they are genuinely appropriate in a small local scope.

## 52. COMMENTS

Comments should explain WHY, not obvious WHAT.

Bad:

```dart
// Set loading to true
isLoading = true;
```

Better:

```dart
// Prevent duplicate submissions while the project is being created.
isLoading = true;
```

Remove stale comments when code changes.

## 53. PRODUCTION READINESS

Before a production release, verify:

- Authentication
- Database
- RLS
- Storage
- OAuth
- Deep links
- Environment variables
- Payments
- Subscriptions
- Notifications
- Error handling
- Loading states
- Empty states
- Android build
- Release signing
- App icon
- Splash screen
- Privacy
- Terms
- Analytics
- Crash handling

Do not mark BAID X production-ready merely because the Flutter build succeeds.

## 54. WHAT CLAUDE MUST NOT DO

Claude Code must NOT:

- Delete the project and rebuild it.
- Replace Supabase.
- Bypass authentication.
- Invent production credentials.
- Commit secrets.
- Disable RLS just to fix an error.
- Delete database tables casually.
- Reset Git without permission.
- Force-push without permission.
- Change the product's core business model.
- Change roles without permission.
- Change subscription pricing without permission.
- Redesign the entire app when asked to fix one feature.
- Add fake production data.
- Pretend integrations work when they do not.
- Claim tests passed when they were not run.
- Hide build errors.
- Automatically upgrade every dependency.
- Remove existing functionality without explanation.

## 55. WHEN UNCERTAINTY EXISTS

If Claude is uncertain about an existing implementation:

DO NOT GUESS.

Inspect:

- source code
- configuration
- Supabase schema
- routes
- models
- services
- Git history
- handover documentation

If uncertainty remains and the decision would materially affect the product, ask the user before proceeding.

For small implementation details, choose the least invasive approach.

## 56. CHANGE MANAGEMENT

For every meaningful change, Claude should be able to answer:

What changed?

A short description.

Why?

The reason for the change.

Where?

The files/modules affected.

How was it tested?

Commands or manual checks.

What remains?

Known limitations or follow-up work.

## 57. FEATURE COMPLETION CHECKLIST

A feature is not complete simply because the UI exists.

Check:

- [ ] UI implemented
- [ ] Navigation implemented
- [ ] Data model implemented
- [ ] Supabase integration implemented
- [ ] Authentication/authorization handled
- [ ] Loading state
- [ ] Empty state
- [ ] Error state
- [ ] Validation
- [ ] Responsive layout
- [ ] Security/RLS considered
- [ ] Tests
- [ ] flutter analyze passes
- [ ] Build tested

Only mark completed items that were actually verified.

## 58. DEVELOPMENT PRIORITY

When deciding what to work on, prioritize:

1. Security
2. Authentication
3. Data integrity
4. Core functionality
5. Reliability
6. UX
7. Performance
8. Visual polish
9. Nice-to-have features

A beautiful interface that loses user data is not acceptable.

## 59. PRODUCT PRIORITY

The core BAID X value proposition is:

```text
People
   +
Skills
   +
Projects
   +
Trust
   +
Payments
   +
Technology
```

The application should help turn informal work relationships into organized, trusted digital workflows.

Avoid features that distract from this purpose.

## 60. FINAL CLAUDE CODE RULE

Before making substantial changes, remember:

Understand first. Modify second. Test third.

The BAID X project is an existing production-oriented codebase.

Protect what already works.

Make changes incrementally.

Keep the architecture understandable.

Keep Supabase secure.

Keep authentication real.

Keep the UI simple.

Keep the product focused.

And always leave the repository in a state that another developer can understand and continue.

## 61. QUICK START COMMANDS

For a fresh development machine:

```text
git clone https://github.com/edstudios73-svg/baid-x.git
cd baid-x
flutter pub get
flutter doctor
flutter devices
flutter analyze
flutter test
flutter run
```

For normal development:

```text
git status
git pull
flutter pub get
flutter analyze
flutter test
flutter run
```

Before committing:

```text
git status
git diff
flutter analyze
flutter test
git add .
git commit -m "feat: describe the change"
```

## 62. PROJECT CONTINUITY

This project may be developed across:

- Cursor
- Claude Code
- VS Code
- Different computers
- Different development environments

Therefore:

The repository and project documentation must contain enough information for development to continue without relying on one computer's local state.

The project must remain reproducible.

Local machine state should never be the only place where critical project knowledge exists.

END OF BAID X CLAUDE CODE INSTRUCTIONS

## 63. WEBSITE AND APP ARE ONE PRODUCT

BAID X has two clients on one shared backend:

- Website: `edstudios73-svg/baid-x-website-` (static site + `/api` on Vercel)
- App: `edstudios73-svg/baid-x-mobile-` (this Flutter project)
- Both use the same Supabase project (`igfmmprlrybxsdzehwid`) and the website's `/api` routes.

Standing rule from the product owner: **every change requested for the website is also made in the app, and every app change is also made on the website, in the same task.** One request covers both; the owner should never have to ask twice.

For every change:

1. Implement it on the website and in the app, matching flow, wording and UI (sizes, layout, states).
2. Website: run `npm test`. App: run `flutter analyze` and `flutter test`.
3. Rebuild the app's web build into the website repo at `app/`
   (`flutter build web --release --base-href /app/`, copy `main.dart.js`, `flutter_bootstrap.js`, `version.json`, `assets/`).
4. Commit and push both repos on the working branch, then deploy the website.
5. Compare the website and the app at phone width (390px) before calling it done.

UI source of truth is the website: flat dark cards on the grid background for home, dashboards, profile and checklist; the glass style only on sign-in/sign-up and the guest Profile. No emoji in the UI (no waving hand).
