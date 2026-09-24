# BAID X Supabase architecture

Project: Baid-x Mobile App (`vxixalejbnvqivaytxzt`).

This database is the shared backend for the BAID X website and the Flutter app. Supabase Auth is the only identity system. The Flutter app uses the publishable key in `.env`. The service-role key is not part of the app.

## Authentication

Email and password sign-up is enabled. Email confirmation is required. Google sign-in is not enabled.

A row in `auth.users` creates:

- `profiles` — the BAID X account
- `profile_private` — phone and private notes

`profiles.id` is `auth.users.id`.

## Account types

Stored on `profiles.account_type`:

`worker`, `employer`, `business`, `project_manager`, `company`

The client cannot update that column. The signed-in user sets it once with `private.set_account_type`. It cannot be changed again from the client. Role checks read `profiles`, not editable user metadata.

Employer and Business stay separate. A business account cannot post jobs. An employer account cannot create business listings.

## Tables

| Area | Tables |
| --- | --- |
| Identity | `profiles`, `profile_private` |
| Worker | `worker_profiles`, `worker_skills`, `worker_experience` |
| Business | `business_profiles`, `business_listings` |
| Jobs | `jobs`, `job_applications` |
| Company | `companies`, `company_members`, `company_access_requests` |
| Projects | `projects`, `project_members`, `project_tasks`, `project_reports`, `project_expenses` |
| Trust | `reviews`, `verifications` |

Companies and projects get a public code such as `BXD-1A2B3C4D`.

## Company and project manager

A company row is owned by a profile whose account type is `company`. The owner is inserted into `company_members`.

A project manager inserts a pending `company_access_requests` row. The owner approves or rejects it with `private.review_company_access`. Approval adds that person as a `project_manager` member. Knowing the company code does not grant access by itself.

Project reports and expenses are not public. A project manager cannot approve their own company access.

## Marketplace and privacy

Anonymous users can read listed profiles, listed worker and business details, public listings, open public jobs, public projects, reviews, and verified verification rows.

They cannot read `profile_private`, applications, company membership, access requests, tasks, reports, or expenses.

Phone numbers live only in `profile_private`, visible to the account owner.

A client cannot mark a verification as verified. New rows stay `pending`.

## Storage

No storage buckets were created. Later buckets should be separate for profile images, portfolio images, business and product images, and private project documents. Private files need an owner policy before they are readable.

## Security rules

- Row Level Security is enabled on every application table.
- There is no policy that lets every signed-in user edit every row.
- Authorization uses `auth.uid()` and the profile row, not `auth.role()` and not `raw_user_meta_data`.
- Helper checks live in the `private` schema so they are not a public data API.

## Flutter authentication

Splash reads the Supabase session, then opens the marketplace. Visitors can browse public pages without an account.

Sign-up uses Supabase Auth. The database trigger creates `profiles` and `profile_private`. The app does not insert into `auth.users`. Email confirmation is required. "I've verified my email" calls Supabase `getUser()` and does not set a local verified flag.

Protected actions use `requireAuthentication`. A missing session opens sign-in. An unconfirmed email opens the verification screen. Sign-out returns to the marketplace and does not delete the profile.

Password reset emails use Supabase Auth. The app route is `/reset-password`. The redirect `com.baidx.baid_x_mobile://login-callback` must be allowed in the Supabase auth settings before the email link can reopen the app.

## Account selection

The database is the source of truth. `profiles.account_type` is not stored on the device, in secure storage, or in editable user metadata. The client cannot update that column.

After email confirmation, the app loads `profiles`. A missing account type opens account selection. The person chooses one of the five types and confirms it. Continue stays disabled until a type is selected.

Confirming calls `public.set_account_type`. That function is security definer, executable by `authenticated` only, and it calls `private.set_account_type`. The private function sets the type only when it is still null and the caller is `auth.uid()`. The app then reloads `profiles` and continues only when the row shows the selected value.

A returning user who already has a type skips selection and opens that role's home. The app does not offer a way to switch types.

## Role onboarding

Each type has its own setup screen. Nothing on that screen is required before the person can continue. Profile photos use a placeholder. No storage bucket was created.

Saved fields use existing columns:

- Worker: `profiles` name and location, `worker_profiles` trade, years, availability, and summary, `worker_skills`
- Employer: `profiles` name, location, and headline
- Business: `business_profiles` name, category, summary, and location, plus `profile_private.phone`
- Project manager: `profiles` name, location, and headline
- Company: `companies` name and industry, plus `profiles.location_label`

Company description and project-manager years of experience have no columns, so they are not collected and the schema was not changed for them.

## Role-aware routing

- `worker` opens `/setup/worker`, then `/role/worker`
- `employer` opens `/setup/employer`, then `/role/employer`
- `business` opens `/setup/business`, then `/role/business`
- `project_manager` opens `/setup/project_manager`, then `/role/project_manager`
- `company` opens `/setup/company`, then `/role/company`

Those homes are placeholders for Phase 5. Marketplace and Discover stay public. A signed-out person who opens a role page is sent to sign-in. Row Level Security was not changed.

## Authenticated app shell

A signed-in person with an account type opens that role's home inside one shared shell. The shell uses the same bottom navigation component, with a different set of up to five destinations for each role. Notifications and settings sit in the dashboard header. Marketplace and Discover stay the existing public screens.

Each dashboard reads only the signed-in user's own rows, plus public rows row-level security already allows: open public jobs, listed worker profiles, the user's applications, listings, projects, tasks, reports, and expenses. Queries are limited to five rows. Empty, loading, and error states are shown. No sample records are inserted.

Verified is shown only when a `verifications` row for that person has status `verified`. Review counts come from `reviews` and are omitted when there are none. Phone numbers are not loaded onto dashboards.

## Workers, jobs, and applications

Open public jobs can be read without an account. A job owner can read and change their own jobs. An applicant can read a job they applied to, including after it closes. That read rule matches `job_applications.job_id` to `jobs.id`.

Only a worker account can insert an application, and only with status `submitted`, for an open public job they do not own. The same worker cannot apply twice: `job_applications` is unique on job and worker. The job owner can read applications to their jobs. Other people cannot. Application status values are `submitted`, `accepted`, `declined`, and `withdrawn`. This phase does not add buttons that change those statuses.

Jobs store title, description, location, public flag, status, owner, and dates. There is no trade, category, or budget column, so the app does not show those filters.

Listed worker profiles, skills, and experience are public. Phone numbers stay in `profile_private` and are not loaded on worker or job screens. Verification is shown only when a verification row is `verified`.

Employer and company accounts can insert jobs they own. Project managers and businesses cannot. The app posts jobs for employer accounts. Company-wide job management is left for a later phase.

## Business marketplace

Public visitors can read listings where `is_public` is true. A business account can create, update, and delete listings whose `business_profile_id` is their own profile. Other account types can browse public listings. They cannot create or edit them. The client sets ownership to the signed-in user id. An update does not send a new owner.

Listing fields used by the app are title, `listing_kind` (`product`, `equipment`, `rental`, `service`), summary, `price_amount`, currency, and `is_public`. Location comes from the business profile, not the listing. There is no image column and no storage bucket, so listings use a placeholder. There is no materials category, quantity, rental duration, or phone field. Hiding a listing sets `is_public` to false. Deleting a listing is allowed by the existing owner policy and asks for confirmation.

Reviews on a business profile are read-only. A verified badge appears only when a verification row is `verified`. Phone numbers are not loaded.

## Projects, companies, and access

A company account can read its company, public code, members, and pending access requests. A project manager enters that public code and inserts a `company_access_requests` row with status `pending`. Knowing the code does not create a membership.

Approve and reject call `public.review_company_access(request_id, approve)`. That function is `SECURITY DEFINER`, runs as the owner, and only calls `private.review_company_access`. Execute is granted to `authenticated` and not to `anon`. The private function checks that the caller is the company owner and that the request is still pending. On approval it inserts or updates `company_members` as an active project manager. The client does not insert or update members or request status.

New projects are inserted by the signed-in user as owner, with status `draft` and `is_public` false. The owner, a project member, or a member of the project's company can read it. Tasks, reports, and expenses are written only when `private.can_manage_project` allows it. Reports and expenses have no update policy, so the app creates and lists them. Tasks can be marked done. Project members added from the app use `worker` or `project_manager`. The form never sends `lead`.

Companies have no description or location column. Tasks have no assignee or due date. Member display names are not loaded, because another person's profile is readable only when that profile is listed. Company members cannot be removed from the client.

## Messaging and in-app notifications

Four tables hold private conversations and notices: `conversations`, `conversation_members`, `messages`, and `notifications`. Row level security is enabled on all four. There is no business conversation type.

A conversation is unique for one context: a job application, a project, or a company. The client cannot insert conversations or members. Signed-in users open one through `public.open_job_application_conversation`, `public.open_project_conversation`, or `public.open_company_conversation`. Each function only calls the matching private function. Those functions check the caller, then add the people who already have the relationship: the applicant and job owner, current project members, or active company members.

Reading a conversation also requires `private.can_access_conversation`. Membership in `conversation_members` is not enough. A job thread still requires the caller to be that applicant or that job owner. A project thread still requires `private.is_project_member`. A company thread still requires an active `private.is_company_member` row. Knowing an id or a company code does not open a thread. Pending and rejected access requests do not.

Messages can be inserted only by the signed-in sender, and only into a conversation they can access. The body must be trimmed and between 1 and 2000 characters. There is no update or delete. A member can update only their own `last_read_at`.

Notifications are inserted only by database triggers. The client can read and mark read its own rows. It cannot insert them or change anything except `read_at`. Events covered are a new application, an application status change, a company access request, approval, rejection, a new project member other than the project owner, and a new message to the other participants.

`supabase_realtime` includes only `messages` and `notifications`. Anonymous users have no select, insert, or function access. Push notifications, device tokens, Firebase, and Edge Functions are not part of this database.

The app inbox, conversation screen, and notification list read these tables through repositories. Opening a thread calls the public functions above. The client does not insert conversations, members, or notifications. The header bell shows the signed-in user's unread count.

## Verification and reviews

`verifications` stores a profile, a kind, and a status of `pending`, `verified`, or `rejected`. A person can insert only their own row, and only as `pending`. There is no update policy. `private.protect_verification_status` blocks a client from changing the status. Public readers can see a row only when it is `verified`, or when it is their own. The app requests `identity` for a worker, `business` for a business, and `company` for a company. There is no document column and no storage bucket, so the request does not upload an identity document. A reviewer is a row in `private.verification_reviewers`. None is seeded.

`reviews` are public to read. The author must be the signed-in user and cannot be the subject. `private.can_write_review` allows the insert only when both people are members of the given project, or when an accepted job application links the worker and the job owner. The body must be trimmed and between 1 and 1000 characters. The rating must be from 1 to 5. One review is allowed for a project pair, and one review is allowed for a pair that is not tied to a project. Reviews have no job id, so two accepted jobs between the same people still share that one review. Reviews cannot be edited.

## Billing

Plans, prices, and entitlements live in `plans`, `verification_products`, `boost_catalog`, `promotion_catalog`, and `xid_catalog`. Amounts are integer minor units. GHS is the checkout currency. A paid plan does not verify an account.

Clients can read their own subscription and payments. They cannot insert or update them. `public.start_checkout` creates a pending payment at the server price. `public.apply_provider_payment` is executable only by `service_role`. The Paystack webhook verifies the signature, then calls that function. `paystack-initialize` starts a Paystack test checkout from the pending payment. Returning from Paystack does not activate the plan. A verification purchase inserts a `pending` verification row and does not set `verified`. Boosts, promotions, and XID services use the same checkout. The server checks target ownership, listing count, and XID eligibility before creating a pending payment. Company billing is readable by an active company owner. Verification decisions go through `decide_verification`, which only a row in `private.verification_reviewers` can call, and never for the reviewer's own request. Status changes still require the server authority flag. No reviewer is seeded.

Founding slots are 1,700 across the five account types, for 90 days from the program row's start. A founding price lock is 12 months from activation and is not restarted by an upgrade. The refund deadline is 168 hours after the original `activated_at`. Protected payments are off.

`founding_programs` and `payment_events` have row level security and no client policies, so clients cannot read or write them. `public.rls_auto_enable` is a Supabase event trigger. Execute is revoked from `anon` and `authenticated`.

Billing history queries use `payments_profile_idx` and `payments_company_idx`. Company subscriptions use `subscriptions_company_idx`.

## Release

See `docs/release-preparation.md`. Paystack stays in test mode. No storage buckets exist. The service-role key and Paystack secret stay in the Supabase Edge Function environment.
