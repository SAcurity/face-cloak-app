# 3-auth-token - Token-based Registration and Authorization

> Keep this plan updated while implementing. If context is lost, this file should explain what the week requires, how Tyto implemented it, and exactly what FaceCloak App still needs.

## Source Material

- Requirement PDF: `../3-auth-token/SEC Project - 009 Token-based Authorization.docx.pdf`
- Reference App: `../3-auth-token/tyto2026-app-3-auth-token`
- Target App: `face-cloak-app`
- API counterpart: `../../api/face-cloak-api`

## Requirement Summary

This week adds token-based registration and authorization.

1. Registration becomes a two-step email verification workflow.
   - App initially collects only `email`.
   - App creates an encrypted verification/registration token containing only the email verification context.
   - App builds a verification URL back to itself and sends `email` and `verification_url` to the API.
   - API sends the verification email.
   - After sending the email, App shows an "Email verification" waiting page; it must not navigate directly to the username/password registration-completion page.
   - When the user follows the link, App decrypts the token, then asks for `@username`, password, and password confirmation.
   - App calls API account creation only after email verification and final username/password entry.
   - Username is the globally unique canonical account name.
   - User-facing display should prefix usernames with `@`; the stored/submitted canonical username should not include `@`.
   - If the chosen username is already taken, the confirmation form must show a field-level warning and let the user choose another name.

2. API issues and requires auth tokens.
   - API returns an `auth_token` when login succeeds.
   - Protected API routes must read `Authorization: Bearer <token>`.
   - Suspicious, expired, or unauthorized token usage must fail on the API side.

3. App stores and uses auth tokens.
   - App stores both account information and the API-issued auth token in secure session storage.
   - App sends the auth token on every protected API request.
   - App must stop sending caller identity through `current_account_id`, `owner_id`, `X-Actor-Id`, username, or user id request fields when the API can derive the caller from the token.
   - Username may still be used as a target identifier for actions like assigning a face record to another account.
   - In face assignment, typing `@` is a mention/user-menu trigger, not part of the canonical username.

4. App should show owned resources by token-derived identity.
   - For FaceCloak, owned resources are images, image logs, raw images, face records, and face assignment flows.
   - The App should ask the API for resources using the token and let the API decide the current account.

## Tyto App Findings

Tyto's `3-auth-token` implementation is the main pattern to copy, adjusted for FaceCloak's image domain.

- `app/lib/registration_token.rb`
  - Wraps `SecureMessage`.
  - Encrypts `{ email:, username: }`.
  - Provides `.load(token_string)` and raises `InvalidTokenError` for tampered tokens.
  - Does not implement expiration in this branch.

- `app/services/verify_registration.rb`
  - Creates a `RegistrationToken`.
  - Builds `verification_url = "#{config.APP_URL}/auth/register/#{token}"`.
  - Posts `{ email:, username:, verification_url: }` to `POST /auth/register`.

- `app/services/authenticate_account.rb`
  - Expects new API envelope:
    - `attributes.account`
    - `attributes.auth_token`
  - Returns `{ account: account_hash, auth_token: token_string }` to the controller.

- `app/services/api_client.rb`
  - Adds optional `auth_token:` kwarg to `get`, `post`, `put`, and `delete`.
  - Sends `HTTP.auth("Bearer #{auth_token}")` when present.
  - Removes old authenticated helpers that inserted caller identity into the body.

- `app/models/account.rb` and `app/models/current_session.rb`
  - `Account` wraps account info plus auth token.
  - `CurrentSession` stores account info and auth token as separate `SecureSession` keys.
  - Logout deletes both.

- `app/controllers/auth.rb`
  - Login stores both account info and token.
  - Register POST starts email verification instead of creating the account immediately.
  - Register GET with token shows the password confirmation page.

- `app/controllers/account.rb`
  - `POST /account/:registration_token` decrypts token, validates password confirmation, then creates the account.

### FaceCloak Delta From Tyto

FaceCloak must not copy Tyto's initial `email + username` registration payload exactly. The backend has been adjusted so email verification is email-only. Username is chosen after the verification link is opened, at the same time as password setup.

- `RegistrationToken` should carry email verification context only, not username.
- `VerifyRegistration` should accept and send only `email` plus `verification_url`.
- `register.slim` should ask only for email.
- After `POST /auth/register`, redirect to an Email verification waiting page, not the registration-completion page.
- `register_confirm.slim` should ask for `@username`, password, and password confirmation.
- `CreateAccount` should receive `email` from the decrypted token and `username/password` from the confirmation form.
- Username uniqueness is resolved at final account creation time. Duplicate username errors must be displayed beside the username field, not as only a generic flash.
- User-facing usernames should be rendered as `@username`. Normalize consistently so the API receives the canonical username without `@`.
- Face assignment should move from raw numeric `assigned_user_id` input to a username/mention input when the API endpoint supports it. `@` opens the user menu; it is stripped before submission.

## FaceCloak Current State

- Secure sessions already exist:
  - `app/lib/secure_message.rb`
  - `app/lib/secure_session.rb`
- Current App registration is still one-step:
  - `POST /auth/register` calls `CreateAccount` with `email`, `username`, and `password`.
- Current login stores only `:current_account`, not `:auth_token`.
- Current `AuthenticateAccount` still parses the old API response shape.
- Current `ApiClient` still has `authenticated_*` helpers that send `X-Actor-Id`.
- Current protected flows still pass caller identity directly:
  - `ListImages`
  - `GetImage`
  - `GetImageLogs`
  - `AssignFace`
  - `UploadImage`
  - `images.rb` raw image proxy
  - `account.rb` profile image listing
- `require_app.rb` currently loads `lib`, `services`, and `controllers`; if `app/models` is added, it must load `models` too.
- FaceCloak API already appears to support this week's token contract:
  - `POST /api/v1/auth/authenticate` returns `attributes.account` and `attributes.auth_token`.
  - `POST /api/v1/auth/register` validates registration and sends email through Resend.
  - Protected routes require `Authorization: Bearer <auth_token>`.
  - API README explicitly says not to send caller identity through `X-Actor-Id`, `owner_id`, username, or user id fields.
- User-provided API contract update on 2026-05-22:
  - email verification starts from email only
  - username/password are entered after verification link
  - username is the unique canonical account name
  - UI should display usernames with a default `@` prefix
  - face record assignment should use username mention UI; `@` triggers the user menu and is not stored
- Note: the local API checkout may still contain README/spec text that mentions older username-at-registration or `assigned_user_id` payloads. Treat the user-provided contract above as the target and update App tasks to match it.

## Goal

Refactor `face-cloak-app` to match the week 3 token-based flow:

- email-verified registration before account creation
- email-only verification before choosing username/password
- login stores account info plus API auth token
- every protected FaceCloak API call sends `Authorization: Bearer <token>`
- App no longer sends `X-Actor-Id` or caller-owned `owner_id` as proof of identity
- User-facing account names display as `@username`, and canonical usernames are usable for face assignment.

## Scope

In scope for App:

- Add `RegistrationToken`
- Add `VerifyRegistration`
- Add `Account` and `CurrentSession`, or an equivalent small session wrapper following Tyto
- Update authentication, registration, and account creation routes
- Split registration UI into email-only verification and post-verification `@username`/password completion
- Add username normalization and duplicate-username field warning on the completion form
- Update `ApiClient` for Bearer token forwarding
- Refactor image/account services to use `auth_token:`
- Refactor face assignment UI/service to target accounts by canonical username through a mention-style input when supported by the API
- Add/update WebMock service specs
- Add/update registration confirmation view
- Verify against the existing FaceCloak API token routes

Out of scope:

- Reimplementing API-side token validation in the App
- Adding registration-token expiration unless there is extra time
- Changing FaceCloak authorization policy
- Adding new image or face management product features unrelated to auth token usage
- Storing passwords or pending accounts in the App session

## Execution Steps

### 1. Setup and Baseline

- [ ] Confirm branch name, likely `3-auth-token`.
- [ ] Run current checks before edits:
  - [ ] `rake spec`
  - [ ] `rake style`
- [ ] Read the FaceCloak API README route contract before changing App service signatures.
- [ ] Keep this plan updated after each meaningful implementation step.

### 2. Registration Token

- [ ] Add `app/lib/registration_token.rb`.
- [ ] Follow Tyto's shape but remove username from the token payload:
  - [ ] `RegistrationToken.new(email:)`
  - [ ] `RegistrationToken.load(token_string)`
  - [ ] `#email`
  - [ ] `#to_s`
  - [ ] `InvalidTokenError`
- [ ] Use `SecureMessage.encrypt(email: email).to_s`.
- [ ] Rescue decryption/JSON failures and raise `InvalidTokenError`.
- [ ] Add `spec/lib/registration_token_spec.rb`.
- [ ] Assert token payload does not contain username, password, roles, or account id.

### 3. Verify Registration Service

- [ ] Add `app/services/verify_registration.rb`.
- [ ] Service input: `email:` only.
- [ ] Build `verification_url` from `App.config.APP_URL`:
  - `/auth/register/:registration_token`
- [ ] Post to API:
  - `POST /auth/register`
  - body: `{ email:, verification_url: }`
- [ ] Define errors:
  - `VerificationError` for 4xx validation errors
  - `ApiServerError` for 5xx/API unavailable cases
- [ ] Add `spec/integration/service_verify_registration_spec.rb`.
- [ ] Use WebMock to assert the request body contains a verification URL whose token decrypts to the expected `email`.
- [ ] Assert the request body does not send username during email verification.

### 4. Login Response and Session Shape

- [ ] Update `app/services/authenticate_account.rb`.
- [ ] Parse current API envelope:
  - `response.fetch('attributes').fetch('account')`
  - `response.fetch('attributes').fetch('auth_token')`
- [ ] Return `{ account: account_hash, auth_token: token_string }`.
- [ ] Add `ApiServerError` handling for 5xx.
- [ ] Update `spec/integration/service_authenticate_spec.rb`.

- [ ] Add `app/models/account.rb`.
  - Store `account_info` and `auth_token`.
  - Provide `logged_in?`, `logged_out?`, `id`, `username`, `email`.
  - Keep helpers minimal; FaceCloak currently mostly needs `id`, `username`, and token access.
  - Provide `handle` or equivalent display helper that returns `@username` for UI while keeping `username` canonical.
- [ ] Add `app/models/current_session.rb`.
  - Store account info and token as separate secure session keys.
  - Recommended keys: `:account` and `:auth_token`, matching Tyto.
  - `#current_account` returns an `Account`.
  - `#current_account=` stores both pieces.
  - `#delete` removes both.
- [ ] Update `require_app.rb` to load `models`.

### 5. ApiClient Bearer Forwarding

- [ ] Change `ApiClient#get`, `#post`, `#put`, and `#delete` to accept `auth_token: nil`.
- [ ] Add private `http(auth_token)` helper:
  - no token: `HTTP`
  - token: `HTTP.auth("Bearer #{auth_token}")`
- [ ] Preserve existing JSON parsing and `ApiError` behavior.
- [ ] Remove or stop using:
  - `authenticated_get`
  - `authenticated_post`
  - `authenticated_put`
  - `authenticated_delete`
- [ ] Check multipart upload separately because it currently uses raw `HTTP.headers`; it must also use Bearer auth.

### 6. Controllers

#### `auth.rb`

- [ ] Login POST:
  - call updated `AuthenticateAccount`
  - wrap result in `Account`
  - store through `CurrentSession`
  - flash with `account.username`
- [ ] Logout:
  - call `CurrentSession.new(session).delete`
- [ ] Register GET `/auth/register`:
  - keep registration form route
- [ ] Register POST `/auth/register`:
  - collect only `email`
  - call `VerifyRegistration`
  - redirect to `/auth/email_verification`
  - do not render or redirect to `register_confirm` directly
  - do not call `CreateAccount` here
- [ ] Register GET `/auth/register/:registration_token`:
  - load `RegistrationToken`
  - render password confirmation view
  - invalid/tampered token redirects to `/auth/register`

- [ ] Register GET `/auth/email_verification`:
  - render an Email verification waiting page
  - explain that username/password setup only happens through the verification link

#### `account.rb`

- [ ] Allow `POST /account/:registration_token` before `require_login!`.
- [ ] For token POST:
  - decrypt registration token
  - read username from the confirmation form
  - normalize username before API submission
  - validate `password` and `password_confirm`
  - call `CreateAccount` with token email and submitted username/password
  - redirect to login on success
  - never trust email fields from the browser at this stage
  - if API reports duplicate username, re-render the confirmation form with a username-field warning
  - keep the verification token available when re-rendering so the user can retry a different username
- [ ] For logged-in account page:
  - use `@current_account.username` if adopting `Account` model
  - list own images through Bearer-token API calls
  - avoid passing `owner_id` as a trust signal

#### `app.rb`

- [ ] Replace `current_account_from_session` with `CurrentSession.new(session).current_account`.
- [ ] Treat `logged_out?` account object or `nil` consistently; choose the least disruptive style.
- [ ] Root page:
  - if logged in, list images using auth token so API returns token-derived resources.
  - if logged out, either show public/filtered list only if API route is public, or show empty/listing fallback depending on current product behavior.

#### `images.rb`

- [ ] Replace `current_account_id = @current_account['id']` with token use.
- [ ] Raw image proxy:
  - send `Authorization: Bearer <token>` to `/images/:id/raw`
  - do not send `X-Actor-Id`
- [ ] Logs:
  - `GetImageLogs.call(image_id:, auth_token:)`
- [ ] Face assignment:
  - `AssignFace.call(face_id:, assigned_username:, auth_token:)` when the API supports username-based assignment
  - until the API endpoint is finalized, isolate payload construction inside `AssignFace` so the controller/view do not depend on numeric user ids
  - treat `@` as a mention/user-menu trigger and strip it before the API call
- [ ] Show image:
  - `GetImage.call(image_id, auth_token:)`
  - compute owner UI from returned image payload and current account id only for presentation, not authorization
- [ ] Upload:
  - `UploadImage.call(auth_token:, file_path:, file_name:)`
  - do not send `owner_id`; API derives owner from token.

### 7. Services to Refactor

- [ ] `list_images.rb`
  - Replace `current_account_id:` with `auth_token:`.
  - `GET /images` with `auth_token:` should return images owned/accessible by the authenticated account.
  - Remove client-side `owner_id` filtering where possible.

- [ ] `get_image.rb`
  - Accept `auth_token:`.
  - Use `ListImages.call(auth_token:)`.
  - Fetch face records using `GET /images/:id/face_records` with `auth_token:`.

- [ ] `get_image_logs.rb`
  - Accept `auth_token:`.
  - Use `GET /images/:id/logs` with `auth_token:`.

- [ ] `assign_face.rb`
  - Accept `auth_token:`.
  - Accept `assigned_username:` from UI input, including mention text such as `@alice`.
  - Normalize `@alice` to the API's expected canonical username in one place.
  - Use `POST /face_records/:id/assignment` with Bearer token.
  - Payload should target the assignee by username once the API contract supports it; do not leak numeric account id lookup into the view.

- [ ] `upload_image.rb`
  - Accept `auth_token:`.
  - Multipart POST to `/images`.
  - Include `Authorization: Bearer <token>`.
  - Remove `owner_id` form field.

- [ ] `create_account.rb`
  - Confirm it stays unauthenticated `POST /accounts`.
  - No auth token required.

### 8. Views

- [ ] Update `app/presentation/views/register.slim`.
  - Remove password input.
  - Remove username input.
  - Keep email only.
  - Button text should indicate sending a verification email.

- [ ] Add `app/presentation/views/email_verification.slim`.
  - Show "Email verification" copy after email submit.
  - Do not include username/password inputs.
  - Provide a way to return to the email form if the email address was wrong.

- [ ] Add `app/presentation/views/register_confirm.slim`.
  - Show verified email as read-only display.
  - Add username input with a visible default `@` prefix.
  - Store/submit only the canonical username value expected by the API; do not accidentally submit `@@alice`.
  - Add field-level duplicate warning state for username conflicts.
  - Ask for password and password confirmation.
  - Submit to `/account/:registration_token`.

- [ ] Update account/profile display text so usernames appear as `@username` where they are shown to users.
- [ ] Keep login username input plain; do not show `@` there because login expects normal username entry.

- [ ] Update face assignment controls in `app/presentation/views/images/show.slim`.
  - Replace "User ID" placeholder with mention-style copy, e.g. "Type @ to choose a user".
  - Input name should reflect the canonical target identifier, e.g. `assigned_username`.
  - Add local validation/help state for unknown target responses from the API.
  - Later, wire `@` to open the user menu/autocomplete once the user-search endpoint is available.

- [ ] Audit views for raw hash account access.
  - If using `Account` model, update `@current_account['username']` style reads to methods where needed.
  - Keep changes small and compatible with existing Slim templates.

### 9. Tests

- [ ] Add registration token unit spec.
- [ ] Add verify registration integration spec.
- [ ] Update authenticate account integration spec for new token envelope.
- [ ] Update/create ApiClient spec if useful for Bearer header behavior.
- [ ] Update service specs that currently assert `X-Actor-Id`.
- [ ] Update/create registration completion tests:
  - email-only token enters completion form
  - username/password are sent only after verification link
  - duplicate username error re-renders with username field warning
  - username normalization accepts `alice` and `@alice` without creating `@@alice`
- [ ] Add or update upload service spec if multipart header behavior is practical to test.
- [ ] Add/update assignment service/view tests for username mention input once the API contract is settled.
- [ ] Run:
  - [ ] `rake spec`
  - [ ] `rake style`
  - [ ] `rake audit`
  - [ ] `rake release_check`

## Manual Verification

- [ ] Start FaceCloak API locally on port `3000`.
- [ ] Confirm API has registration email env vars for local/test provider:
  - `RESEND_API_KEY`
  - `RESEND_API_URL`
  - `RESEND_FROM_EMAIL`
  - `RESEND_FROM_NAME`
- [ ] Start App locally on port `9292`.
- [ ] Register:
  - submit email only
  - API accepts `/auth/register`
  - verification email is sent
  - click verification URL
  - App shows username/password form
  - username field presents `@` by default
  - submit `@username`, password, and password confirmation
  - account is created
- [ ] Duplicate username:
  - verify a new email
  - choose an already-used username
  - App stays on completion form and shows a username-field warning
  - choose a unique username and complete registration
- [ ] Login:
  - API returns `auth_token`
  - App stores token in secure session
- [ ] Image list:
  - `GET /images` uses Bearer token
  - no `X-Actor-Id`
- [ ] Upload:
  - multipart upload uses Bearer token
  - request does not include `owner_id`
  - uploaded image owner is derived by API
- [ ] Raw image/logs/face assignment:
  - all protected calls work for authorized users
  - unauthorized access fails through API token policy
- [ ] Face assignment by username mention:
  - owner assigns a face record to another account using mention UI
  - typing `@` opens the user menu once autocomplete is available
  - API resolves the target account
  - UI displays the assigned username as `@username`
- [ ] Logout:
  - both account info and auth token are removed from session
  - protected pages redirect to login

## Important Notes

- The App should not prove identity by sending `X-Actor-Id`; that is exactly what this week removes.
- `owner_id` can be displayed if the API returns it, but should not be sent as the authenticated caller during protected operations.
- Registration token is App-created and encrypted with App `MSG_KEY`; API auth token is API-created and opaque to the App.
- Store API auth token inside `SecureSession`; do not expose it in URLs, forms, hidden inputs, or logs.
- The verification URL necessarily contains the registration token. Keep it limited to email verification context and avoid putting username, passwords, roles, or ids in it.
- Tyto did not expire registration tokens in this branch. If FaceCloak needs expiration, implement it deliberately and test old-token failure paths; otherwise document it as a known limitation.
- The target API flow now says `/auth/register` email verification is email-only. If local API README/spec text still mentions username at this step, update docs/tests or confirm the backend branch before implementing App code.
- Username canonicalization must be consistent across registration, login, display, profile URLs, and face assignment. Display contexts should show `@alice`; login and API/database should use the canonical username without `@`.
- Duplicate username is not a generic registration failure. It must map to a username field warning on the completion form.
- Face assignment by username mention should not require users to know numeric account ids.
- Multipart upload cannot use `ApiClient.post(..., json:)` directly; use the same Bearer header logic while preserving `HTTP::FormData::File`.
- If the App adopts `Account` model, update templates and helpers consistently enough to avoid mixing object-method and raw-hash reads in the same path.

## Completion Criteria

- Registration is two-step and email-verified.
- Initial email verification asks only for email.
- After sending verification email, App shows an Email verification waiting page.
- Post-verification completion asks for `@username`, password, and password confirmation.
- Duplicate usernames produce a username-field warning and allow retry.
- Login stores both account info and auth token through secure session storage.
- All protected API calls use `Authorization: Bearer <token>`.
- No protected App service sends `X-Actor-Id` or caller `owner_id` as identity proof.
- Face assignment uses username mention input rather than numeric user id input.
- Existing image list, upload, raw image, logs, and face assignment flows still work.
- Specs, style, audit, and release check pass.

## Current Status

- [x] Plan written from week requirement PDF, Tyto App reference, and current FaceCloak App/API inspection.
- [x] Plan updated for 2026-05-22 backend change: email-only verification first, username/password after verification link, display usernames as `@username`, duplicate username field warning, and username mention-based face assignment.
- [x] App implementation completed for email-only verification, post-verification username/password completion, secure session auth token storage, Bearer API calls, and username-based face assignment UI/service.
- [x] Tests updated for email-only registration token, verification request payload, and authenticated login token envelope.
- [x] Verification passed:
  - `RBENV_VERSION=4.0.2 /Users/lyc/.rbenv/shims/bundle exec rake spec`
  - `RBENV_VERSION=4.0.2 /Users/lyc/.rbenv/shims/bundle exec rake style`
  - `RBENV_VERSION=4.0.2 /Users/lyc/.rbenv/shims/bundle exec rake release_check`
- [ ] Manual browser/API smoke test pending.

Last updated: 2026-05-22
