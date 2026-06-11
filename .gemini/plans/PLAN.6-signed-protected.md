# PLAN: Signed Client Requests and Browser Security

This plan covers the **FaceCloak Web App** changes required by
`6-signed-protected/SEC Project - 012 Client-Side Security.docx.pdf`.

Reference implementation/style inspected:
`6-signed-protected/tyto2026-app-6-signed-protected`.

> Keep this plan current while implementing. Treat it as the handoff document
> if context is cleared.

## Requirement Summary

1. Google OAuth CSRF prevention:
   - Create a state nonce before redirecting to Google OAuth.
   - Store that nonce in the session.
   - Compare the returned callback `state` against the expected session value.
   - Stop the SSO flow when the state is missing or mismatched.

2. Signed client requests:
   - The API will require signed POST routes when the request cannot provide an
     `auth_token`.
   - The app must sign critical unauthenticated JSON bodies with an app-only
     signing key.
   - Signed requests should be sent as separate `data` and `signature` parts.

3. Browser security controls:
   - Move browser/security header configuration into `app/controllers/security.rb`.
   - Set cookie hardening, security headers, and Content Security Policy.
   - Add a CSP violation reporting route.

4. Asset verification:
   - Third-party scripts, stylesheets, and fonts must either carry SRI
     `integrity` hashes or be removed/self-hosted.
   - Keep or improve the existing `rake url:integrity` support.

## Tyto Patterns to Preserve

1. **Thin Roda route files**
   - Controllers validate route-level state, call service objects, set flash,
     and redirect/render.
   - Signing and HTTP details stay out of route blocks.

2. **Service-owned API calls**
   - `ApiClient` remains the generic JSON transport wrapper.
   - Match Tyto's pattern: sign at the service call site with
     `SignedMessage.sign(payload)` rather than making `ApiClient` silently
     mutate all unauthenticated requests.

3. **Small security libraries**
   - Add `FaceCloak::SignedMessage` under `app/lib`.
   - Mirror the existing `SecureMessage`/Tyto `SignedMessage` style:
     class-level `.setup`, `.sign`, and a focused `KeypairError`.

4. **Specs pin contracts**
   - WebMock service specs should assert the signed request envelope exactly
     where deterministic Ed25519 signatures make that practical.
   - Add high-signal security header specs using Rack::Test against the real
     middleware stack.

5. **Plan-driven checklist**
   - Keep tasks grouped by vertical slice and check them off as completed.

## Current FaceCloak Findings

- [x] PDF requirements extracted and reviewed.
- [x] Tyto 6-signed-protected plan and implementation reviewed.
- [x] FaceCloak currently already protects Google SSO state:
  `AuthSsoRoute` stores `GOOGLE_SSO_STATE_KEY` in `SecureSession`, validates
  with `Rack::Utils.secure_compare`, and clears state on success/failure.
- [x] FaceCloak already uses external app JavaScript via Roda assets:
  `app/presentation/assets/js/main.js` and `modules/*.js`.
- [x] FaceCloak has `rake url:integrity`.
- [x] `FaceCloak::SignedMessage` added in `app/lib/signed_message.rb`.
- [x] `SIGNING_KEY` is wired in `config/environments.rb` and
  `config/secrets-example.yml`.
- [x] Unauthenticated API POST call sites send signed `{data, signature}`
  envelopes.
- [x] `secure_headers` added to the Gemfile.
- [x] `app/controllers/security.rb` added.
- [x] Session cookies hardened with `httponly` and `same_site`; production also
  uses `secure: true`.
- [x] Layout third-party assets carry SRI.
- [x] Slim views no longer use inline `style=` attributes; dynamic face/avatar
  styles are applied by external JS.

## API Contract Dependencies

These app changes assume the FaceCloak API branch implements the matching
server-side requirement:

1. API holds the public `VERIFY_KEY`.
2. App holds the private `SIGNING_KEY`.
3. For signed JSON requests, the app sends:

   ```json
   {
     "data": {
       "...": "original request body"
     },
     "signature": "base64-ed25519-signature"
   }
   ```

4. The signature is computed over `data.to_json`, matching Tyto.
5. The API verifies the envelope before parsing/handling unauthenticated POST
   requests.

## Signed Request Scope

Sign every FaceCloak API POST that does not send `auth_token`.

Required app call sites:

- `app/services/create_account.rb`
  - `POST /accounts`
  - Final account creation after email verification.

- `app/services/verify_registration.rb`
  - `POST /auth/register`
  - Email-only registration start.

- `app/services/authenticate_account.rb`
  - `POST /auth/authenticate`
  - Password login.

- `app/services/authenticate_sso_account.rb`
  - `POST /auth/sso`
  - Google SSO handoff to API.

- `app/services/check_username_availability.rb`
  - `POST /accounts/search`
  - Public username availability lookup used by the registration page.

Do not sign authenticated POSTs such as face assignment/response/decline. They
already send a Bearer `auth_token` and are outside the PDF minimum.

## CSP and Asset Inventory

Current external sources in `layout.slim`:

- `https://cdn.jsdelivr.net/npm/bootswatch@5.3.3/dist/lumen/bootstrap.min.css`
- `https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css`
- `https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined...`
- `https://cdn.jsdelivr.net/npm/@popperjs/core@2.11.8/dist/umd/popper.min.js`
- `https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js`

Recommended direction:

- Keep Bootswatch, Font Awesome, Popper, and Bootstrap only if each tag gets
  `integrity` and `crossorigin="anonymous"`.
- Remove the Google Material Symbols stylesheet unless a real usage is found.
  It appears unused, and Google Fonts CSS is dynamic enough that stable SRI is
  not a good fit. If Material Symbols are required later, self-host the font and
  serve it from `'self'`.
- CSP allowlist should be no wider than:
  - `default-src 'self'`
  - `script-src 'self' https://cdn.jsdelivr.net`
  - `style-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com`
  - `font-src 'self' https://cdnjs.cloudflare.com`
  - `img-src 'self' data: <API image host>`
  - `connect-src 'self'`
  - `form-action 'self'`
  - `frame-ancestors 'none'`
  - `object-src 'none'`
  - `report-uri /security/report_csp_violation`

FaceCloak-specific CSP risks:

- `layout.slim` has inline style attributes on the brand link, upload button,
  and back-chevron icon.
- `_search_section.slim`, `account/show.slim`, and `images/index.slim` have
  inline layout/image styles that should move to CSS classes.
- `images/show.slim` uses `style=face_box_style(face, image)` for face overlay
  geometry. A strict no-`unsafe-inline` CSP will block this. Convert the helper
  to emit `data-box-left`, `data-box-top`, `data-box-width`, and
  `data-box-height`; let external JS apply those values through CSSOM on load.
- There are no Slim `javascript:` blocks in the current app. Preserve that.

## Phase 1: SignedMessage Library and Config

- [x] Add `secure_headers` to `Gemfile` and update `Gemfile.lock`.
  `rbnacl` and `base64` are already present.

- [x] Create `app/lib/signed_message.rb`.
  - [x] Define `FaceCloak::SignedMessage`.
  - [x] Define `KeypairError < StandardError`.
  - [x] Implement `.setup(signing_key64)` using `Base64.strict_decode64`.
  - [x] Implement `.sign(message)` returning `{ data: message, signature: ... }`.
  - [x] Sign `message.to_json` with `RbNaCl::SigningKey`.
  - [x] Keep the implementation close to Tyto's small class style.

- [x] Wire setup in `config/environments.rb`.
  - [x] `require './app/lib/signed_message'`.
  - [x] Call `SignedMessage.setup(ENV.delete('SIGNING_KEY') || config.SIGNING_KEY)`.
  - [x] Keep it beside `SecureMessage.setup`.

- [x] Update `config/secrets-example.yml`.
  - [x] Add `SIGNING_KEY` for development, test, and production.
  - [x] Document that API gets only the matching `VERIFY_KEY`.

- [x] Add a key generation helper.
  - [x] Extend `Rakefile` with `rake newkey:signing`.
  - [x] Print both `SIGNING_KEY` and `VERIFY_KEY` so app/API config can be paired.
  - [x] Do not commit real keys to `config/secrets.yml`.

## Phase 2: Sign Unauthenticated POST Services

- [x] Update `CreateAccount`.
  - [x] Build the existing account payload.
  - [x] Post `SignedMessage.sign(payload)` to `/accounts`.

- [x] Update `VerifyRegistration`.
  - [x] Preserve the generated `registration` hash returned to callers.
  - [x] Post `SignedMessage.sign(registration)` to `/auth/register`.

- [x] Update `AuthenticateAccount`.
  - [x] Preserve username normalization and local blank validation.
  - [x] Post `SignedMessage.sign(credentials)` to `/auth/authenticate`.

- [x] Update `AuthenticateSsoAccount`.
  - [x] Preserve provider/id_token/jwks validation.
  - [x] Post `SignedMessage.sign(payload)` to `/auth/sso`.
  - [x] Do not log tokens or JWKS body.

- [x] Update `CheckUsernameAvailability`.
  - [x] Post `SignedMessage.sign({ username: username })` to `/accounts/search`.
  - [x] Preserve 404 means available, 200 means taken.

- [x] Keep `ApiClient` generic.
  - [x] Do not auto-sign inside `ApiClient#post`.
  - [x] Do not sign authenticated POST/PUT/DELETE calls.

## Phase 3: Google OAuth State Audit

The main implementation already exists from Plan 5. This phase is a hardening
audit against the new PDF requirement.

- [x] Confirm `GET /auth/sso/google` always generates a fresh nonce.
- [x] Confirm the nonce is stored through `SecureSession`, not a query param or
  hidden field.
- [x] Confirm callback state validation happens before code exchange,
  JWKS fetch, or API call.
- [x] Confirm state is cleared on success, denied OAuth, state mismatch, Google
  OAuth error, and API auth error.
- [x] Add or update regression coverage if any of those checks are not already
  pinned.

## Phase 4: Security Controller and Cookie Hardening

- [x] Create `app/controllers/security.rb`.
  - [x] `require 'secure_headers'`.
  - [x] `require_relative 'app'`.
  - [x] Add `use SecureHeaders::Middleware`.
  - [x] Configure `SecureHeaders::Configuration.default`.
  - [x] Add route `POST /security/report_csp_violation`.
  - [x] Log report bodies with `App.logger.warn`.
  - [x] Return `204` with no body.

- [x] Configure browser security headers.
  - [x] `X-Frame-Options: DENY`.
  - [x] `X-Content-Type-Options: nosniff`.
  - [x] `X-XSS-Protection: 1` for legacy completeness.
  - [x] `X-Permitted-Cross-Domain-Policies: none`.
  - [x] `Referrer-Policy: origin-when-cross-origin`.

- [x] Configure CSP.
  - [x] No `unsafe-inline` for scripts.
  - [x] Avoid `unsafe-inline` for styles if Phase 5 removes all inline style
    attributes, including dynamic face boxes.
  - [x] Include `/security/report_csp_violation` as `report-uri`.
  - [x] Keep source allowlists aligned with actual asset usage.

- [x] Harden session cookies in `config/environments.rb`.
  - [x] Development/test `Rack::Session::Pool`: add `httponly: true`,
    `same_site: :lax`.
  - [x] Production `Rack::Session::Redis`: add `secure: true`,
    `httponly: true`, `same_site: :lax`.
  - [x] Leave HTTPS enforcement in production's existing Roda
    `redirect_http_to_https` and `hsts` plugins.

## Phase 5: CSP Compliance Refactor

- [x] Remove inline style attributes in `layout.slim`.
  - [x] Brand sizing/letter spacing -> CSS class.
  - [x] Upload pill radius/padding -> CSS class.
  - [x] Back icon font size -> CSS class.

- [x] Remove inline style attributes in shared/content views.
  - [x] `_search_section.slim` max-width -> CSS class.
  - [x] `account/show.slim` top padding -> CSS class.
  - [x] `images/index.slim` section spacing/search centering/card image style
    -> CSS classes.

- [x] Convert dynamic face box inline style.
  - [x] Replace `face_box_style` usage with data attributes generated from
    normalized box coordinates.
  - [x] Add a JS initializer in `modules/face-assignment.js` or a focused new
    module to apply `left/top/width/height` through `element.style`.
  - [x] Keep server-side clamping/normalization in `FaceBoxHelper`; only the
    transport from Slim to JS changes.
  - [x] Add regression/source checks so `style=face_box_style` does not return.

- [x] Confirm no Slim `javascript:` blocks exist.
- [x] Confirm no remaining `style=` attributes exist unless the chosen CSP
  explicitly and intentionally allows style attributes.

## Phase 6: Third-Party Asset Integrity

- [x] Generate SRI hashes for pinned third-party
  assets kept in `layout.slim`.
- [x] Add `integrity` and `crossorigin="anonymous"` to each kept third-party
  stylesheet/script tag.
- [x] Remove the Google Material Symbols stylesheet if still unused.
- [x] If any Google-hosted font is actually required, self-host it under
  `app/presentation/public` or `app/presentation/assets` instead of relying on
  Google Fonts CSS.
- [x] Add a regression spec or source check that third-party `http` assets in
  layout have integrity attributes.

## Phase 7: Tests

- [x] Add `spec/unit/signed_message_spec.rb`.
  - [x] Valid message signs and verifies with matching verify key.
  - [x] Tampered data fails verification.
  - [x] Bad/missing signing key raises `KeypairError`.
  - [x] Signing is deterministic for the same payload.

- [x] Update service specs for signed request bodies.
  - [x] `service_create_account_spec.rb`.
  - [x] `service_verify_registration_spec.rb`.
  - [x] `service_authenticate_spec.rb`.
  - [x] `service_authenticate_sso_account_spec.rb`.
  - [x] `service_check_username_availability_spec.rb`.

- [x] Add `spec/integration/security_headers_spec.rb`.
  - [x] Asserts the security headers are present.
  - [x] Asserts CSP includes expected directives and report URI.
  - [x] Asserts CSP does not include `unsafe-inline` for scripts.
  - [x] Posts a sample CSP report and expects `204`.

- [x] Add/extend regression specs for CSP source hygiene.
  - [x] No Slim `javascript:` blocks.
  - [x] No banned inline styles after refactor.
  - [x] Third-party layout assets have SRI or have been removed/self-hosted.
  - [x] Google SSO state is validated before token exchange/API auth.

## Phase 8: Manual Verification

- [x] Run `bundle exec rake spec`.
- [x] Run `bundle exec rake style`.
- [x] Run `bundle exec rake audit`.
- [ ] Start the app in development and verify:
  - [ ] Register email verification start.
  - [ ] Username availability checks.
  - [ ] Registration confirm creates the account.
  - [ ] Password login.
  - [ ] Google SSO start/callback with a real Google account.
  - [ ] Home image feed renders.
  - [ ] Image detail face boxes render in edit/response modes.
  - [ ] Face assignment, response, decline, and image upload still work.
- [ ] Browser devtools:
  - [ ] No CSP violations during normal flows.
  - [ ] Third-party assets load with SRI.
  - [ ] Session cookie has `HttpOnly` and `SameSite=Lax`; production/staging
    cookie also has `Secure`.
- [ ] Deliberately trigger one CSP violation and confirm
  `/security/report_csp_violation` logs and returns `204`.

## Commit Strategy

Recommended payload split:

1. `Sign unauthenticated API requests`
   - Phases 1-3 plus signed service spec updates.

2. `Configure browser security headers and CSP`
   - Phases 4-6 plus CSP/security header specs.

3. `Verify final client-side security requirements`
   - Manual verification notes, regression cleanup, and any release-check fixes.

The plan file itself may be committed separately as documentation and should not
count as one of the payload commits if the course requires implementation commit
counts.

## Out of Scope

- Per-form CSRF tokens for every app POST form.
- Replay protection for signed API messages unless the API requirement expands.
- Replacing the existing OAuth/OIDC flow with Google SDK gems.
- Signing authenticated requests that already carry Bearer auth tokens.
- Broad UI redesign while removing inline styles.

## Open Questions

- [ ] Confirm the matching FaceCloak API branch uses the same signed envelope
  shape and signs/verifies `data.to_json`.
- [ ] Confirm whether the API wants `/accounts/search` signed. The PDF minimum
  says all POST routes without `auth_token` should be signed, so this plan signs
  it unless the API contract says otherwise.
- [x] Confirm whether the team wants to keep Font Awesome via CDN with SRI or
  self-host it to simplify CSP/font policy.

## Completed

- 2026-06-12 — Implemented `FaceCloak::SignedMessage`, `SIGNING_KEY`
  configuration, `rake newkey:signing`, and signed envelopes for every
  unauthenticated API POST service.
- 2026-06-12 — Added `secure_headers`, centralized browser security headers and
  CSP in `app/controllers/security.rb`, hardened session cookies, and added CSP
  report handling at `/security/report_csp_violation`.
- 2026-06-12 — Removed CSP-blocking inline styles from Slim/helper output.
  Static styles moved to CSS classes; face box and avatar dynamic geometry/color
  now travel through data attributes and are applied by external JS.
- 2026-06-12 — Added SRI/crossorigin to kept CDN assets, removed unused Google
  Material Symbols CSS, and kept Font Awesome via CDN with SRI.
- 2026-06-12 — Added signed-message, security-header, signed-service, and CSP
  hygiene specs. Updated `puma` from 7.2.0 to 7.2.1 because
  `bundle audit check --update` reported high-severity Puma advisories.
- 2026-06-12 — Verified `bundle exec rake release_check`: 54 runs /
  148 assertions, RuboCop clean, bundle-audit clean.

---

Last updated: 2026-06-12
