# PLAN: Account API, Scoped Tokens, and Google SSO

This plan covers the **FaceCloak Web App** changes required by `5-account-api/SEC Project - 011 Auth Scopes and SSO.docx.pdf`.

Reference implementation/style inspected: `5-account-api/tyto2026-app-5-account-api-token`.

## Requirement Summary

1. Scoped authorization:
   - Existing session/auth tokens now include an authorization scope.
   - The app may need to clear old session data that contains unscoped tokens.
   - The account information page should display a limited-scope API key for the signed-in user.
   - The limited key should be safe to use from the command line and should not expose the full session token.

2. Google OAuth 2.0 / OIDC SSO:
   - Use only `http` and `jwt` gems for the OAuth/OIDC flow; do not use Google packaged SSO gems.
   - The app initiates Google OAuth, receives the callback code, exchanges it for an `id_token`, fetches Google's JWKS, and sends the final SSO payload to the API.
   - The API verifies the `id_token`, creates or finds the account, and returns normal account/auth token data to the app.

## Tyto App Patterns to Preserve

1. **Controllers orchestrate only**
   - Roda route files keep validation, service invocation, flash messages, and redirects together.
   - External/API logic stays in service objects.

2. **Services own HTTP calls**
   - `ApiClient` remains the single wrapper for JSON API calls.
   - Authenticated API calls pass tokens through `Authorization: Bearer <token>`.

3. **Models parse API envelopes**
   - Controllers should not flatten API responses.
   - Services return `Account.from_api(...)` and other parser models, not raw response hashes, unless the endpoint is a simple status payload.

4. **Limited API key safety**
   - Tyto's `GetAccount` parses a fresh read-only token from the account-detail response.
   - The account view receives `api_key` explicitly.
   - The displayed API key is gated on self-view only and is never taken from the cached full session token.

## API Contract Dependencies

These app changes assume the FaceCloak API exposes matching behavior:

1. `POST /auth/authenticate`
   - Returns a scoped full-session auth token in the existing authenticated account envelope.

2. `GET /accounts/:username`
   - Requires the caller's full-session Bearer token.
   - Returns an authorized account envelope carrying both the account data and a newly minted limited-scope API key:

   ```json
   {
     "data": {
       "type": "authorized_account",
       "attributes": {
         "account": { "type": "account", "attributes": {}, "policies": {}, "capabilities": {} },
         "auth_token": "read.only.scoped.api.key"
       }
     }
   }
   ```

3. `POST /auth/sso`
   - Receives Google SSO data from the app, e.g. `provider`, `id_token`, and `jwks`.
   - Verifies the token and returns the same account/auth token shape as password login:

   ```json
   {
     "type": "authenticated_account",
     "attributes": {
       "account": { "type": "account", "attributes": {}, "policies": {}, "capabilities": {} },
       "auth_token": "full.scoped.session.token"
     }
   }
   ```

## Phase 1: Dependencies and Configuration

- [x] **Update Gemfile**
  - [x] Confirm `http` is already present.
  - [x] Add `jwt` if missing.
  - [x] Do not add Google OAuth gems.

- [x] **Add Google OAuth config keys**
  - [x] Update `config/secrets-example.yml`.
  - [x] Add `GOOGLE_CLIENT_ID` in `development`, `test`, and `production`.
  - [x] Add `GOOGLE_CLIENT_SECRET` in `development`, `test`, and `production`.
  - [x] Add `GOOGLE_REDIRECT_URI` or derive it from `APP_URL`.
  - [x] Add optional `GOOGLE_OAUTH_SCOPE`, defaulting to `openid email profile`.

- [x] **Keep secrets out of source control**
  - [x] Verify `config/secrets.yml` remains ignored.
  - [x] Do not commit real Google client credentials.

## Phase 2: Session Compatibility for Scoped Tokens

- [x] **Handle old unscoped session tokens**
  - [x] Clear `CurrentSession` when an authenticated API request returns `401` or `403` because the session token is no longer valid.
  - [x] Redirect the user to `/auth/login` after clearing the stale session.
  - [x] Keep `SecureSession.wipe_redis_sessions` available as the manual one-time reset path if local Redis contains old session payloads.

- [x] **Avoid overwriting full session tokens with limited API keys**
  - [x] Keep the full session token stored only through `CurrentSession.current_account=`.
  - [x] Pass limited API keys to views as separate locals.
  - [x] Do not write limited API keys back into the session account.

## Phase 3: Limited-Scope Account API Key

- [x] **Update `GetAccount` service**
  - [x] Edit `app/services/get_account.rb`.
  - [x] Keep caller credentials as `auth_token: @current_account.auth_token`.
  - [x] Parse the API response as an authorized account envelope:

   ```ruby
   attributes = response.fetch('data').fetch('attributes')
   Account.from_api(attributes.fetch('account'), attributes.fetch('auth_token'))
   ```

  - [x] Ensure the returned model's `auth_token` is the limited API key, not the caller's full session token.

- [x] **Update account profile route**
  - [x] Edit `app/controllers/account.rb`.
  - [x] In `GET /account/:username`, fetch the current user's account detail through `GetAccount` when rendering the self profile.
  - [x] Continue using `@current_account.auth_token` for privileged calls like `ListImages`.
  - [x] Pass the limited key explicitly:

   ```ruby
   api_key: profile_account.auth_token
   ```

  - [x] For non-self profiles, keep the current redirect until profile viewing is implemented, or explicitly pass `api_key: nil`.

- [x] **Display the API key on the account page**
  - [x] Edit `app/presentation/views/account/show.slim`.
  - [x] Add an `API Access` section matching FaceCloak's visual style, not Tyto's Bootstrap-only layout.
  - [x] Gate rendering on `is_self && api_key`.
  - [x] Use a collapsed/reveal UI so the key is not shown by default.
  - [x] Label it as a limited/read-only API key and avoid implying it is the full login session.

- [x] **Regression guard**
  - [x] Add a regression spec similar to Tyto's `spec/regression_spec.rb`.
  - [x] Assert the controller passes an explicit `api_key` local only for self-view.
  - [x] Assert the view gates the API access block on self-view and `api_key`.
  - [x] Assert source does not render `@current_account.auth_token` directly.

## Phase 4: Google OAuth/OIDC App Flow

- [x] **Create a Google OAuth client service**
  - [x] Create `app/services/google_oauth_client.rb`.
  - [x] Build the Google authorization URL.
  - [x] Exchange callback `code` for token response using `HTTP.post`.
  - [x] Fetch Google JWKS using `HTTP.get`.
  - [x] Use authorization endpoint `https://accounts.google.com/o/oauth2/v2/auth`.
  - [x] Use token endpoint `https://oauth2.googleapis.com/token`.
  - [x] Use JWKS endpoint `https://www.googleapis.com/oauth2/v3/certs`.

- [x] **Protect OAuth callback with state**
  - [x] Generate a random `state` value before redirecting to Google.
  - [x] Store `state` in `SecureSession`.
  - [x] Verify callback `state` before exchanging the code.
  - [x] Clear the stored state after success or failure.

- [x] **Create SSO authentication service**
  - [x] Create `app/services/authenticate_sso_account.rb`.
  - [x] POST to `POST /auth/sso` through `ApiClient`.
  - [x] Send:

   ```ruby
   {
     provider: 'google',
     id_token: id_token,
     jwks: jwks
   }
   ```

  - [x] Parse the API response into `Account.from_api(account, auth_token)`.
  - [x] Mirror `AuthenticateAccount::UnauthorizedError`.
  - [x] Mirror `AuthenticateAccount::ApiServerError`.

- [x] **Add auth routes**
  - [x] Edit `app/controllers/auth.rb`.
  - [x] Add `GET /auth/sso/google`.
  - [x] Generate state in `GET /auth/sso/google`.
  - [x] Redirect to Google authorization URL in `GET /auth/sso/google`.
  - [x] Add `GET /auth/sso/google/callback`.
  - [x] Verify state in the callback.
  - [x] Exchange code for `id_token` in the callback.
  - [x] Fetch JWKS in the callback.
  - [x] Call `AuthenticateSsoAccount` in the callback.
  - [x] Store returned account in `CurrentSession`.
  - [x] Redirect to `/` with a normal login flash.

- [x] **Add login page entry point**
  - [x] Edit `app/presentation/views/login.slim`.
  - [x] Add a "Continue with Google" action using the existing FaceCloak button/layout style.
  - [x] Keep password login as-is.

## Phase 5: Error Handling and UX

- [x] **OAuth denial/error callback**
  - [x] If Google returns `error`, show a friendly login error.
  - [x] Do not call the API when Google returns `error`.

- [x] **State mismatch**
  - [x] Treat missing/mismatched state as a failed login.
  - [x] Clear OAuth state from the session.
  - [x] Log a warning without leaking tokens.

- [x] **Google/API outage**
  - [x] Convert external HTTP failures into service-specific errors.
  - [x] Show the same "servers are not responding" style used by existing login/registration flows.

- [x] **Token secrecy**
  - [x] Never log `id_token`.
  - [x] Never log access tokens.
  - [x] Never log JWKS body.
  - [x] Never log session tokens.
  - [x] Never log API keys.
  - [x] Avoid placing tokens in query strings except the Google callback `code` received from the provider.

## Phase 6: Tests

- [x] **Service tests: limited account API key**
  - [x] Add/update `spec/integration/service_get_account_spec.rb`.
  - [x] Stub `GET /accounts/:username`.
  - [x] Assert caller Bearer token is the full session token.
  - [x] Assert returned `Account#auth_token` is the limited API key from `data.attributes.auth_token`.

- [x] **Service tests: Google OAuth client**
  - [x] Stub Google token endpoint with WebMock.
  - [x] Stub Google JWKS endpoint with WebMock.
  - [x] Assert request shape and parsed outputs.
  - [x] Assert non-2xx responses raise service errors.

- [x] **Service tests: SSO API auth**
  - [x] Add `spec/integration/service_authenticate_sso_account_spec.rb`.
  - [x] Stub `POST /auth/sso`.
  - [x] Assert `provider`, `id_token`, and `jwks` are sent.
  - [x] Assert returned account and full session auth token are parsed like password login.

- [x] **Controller/regression tests**
  - [x] Add high-signal source/regression checks if full Rack OAuth tests are too heavy.
  - [x] Ensure login page links to `/auth/sso/google`.
  - [x] Ensure callback verifies state before service calls.
  - [x] Ensure account page does not display API key unless `is_self && api_key`.

- [x] **Existing regression suite**
  - [x] Run `bundle exec rake style`.
  - [x] Run `bundle exec rake spec`.

## Phase 7: Manual Verification

- [ ] **Scoped API key smoke test**
  - [ ] Login normally.
  - [ ] Visit `/account/:username`.
  - [ ] Reveal the API key.
  - [ ] Use it from the command line against a read endpoint.
  - [ ] Confirm write endpoints fail when called with the limited key.

- [ ] **Old session behavior**
  - [ ] Start with an old local session if available.
  - [ ] Confirm the app clears it or asks the user to log in again cleanly.

- [ ] **Google SSO**
  - [ ] Configure Google OAuth credentials.
  - [ ] Click "Continue with Google".
  - [ ] Complete the Google flow.
  - [ ] Confirm the API-created/found account is stored in `CurrentSession`.
  - [ ] Confirm logout/login still works for password accounts.

## Implementation Notes

1. Keep app changes in `face-cloak-app`.
2. Keep API verification logic out of the app; the app only coordinates Google OAuth and forwards SSO evidence to the API.
3. Follow existing FaceCloak naming and modularization:
   - small route helper modules inside controller files when the route grows,
   - service classes for external/API calls,
   - parser models for API envelopes,
   - Slim views with existing FaceCloak layout/classes.
4. Do not store limited API keys or Google tokens in `CurrentSession`.
5. Do not introduce Google SDK gems.
