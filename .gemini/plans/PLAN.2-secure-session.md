# 2-secure-session - Secure Sessions, Registration, and App Deployment [COMPLETED]

## Goal
Advance the FaceCloak Web App from authenticated sessions to secure deployable sessions by following the Tyto App `2-secure-session` execution style. The App should support basic registration through the API, avoid real API calls in service tests with WebMock, encrypt session values with a secure messaging layer, enforce HTTPS/HSTS in production, and prepare for Heroku deployment.

## Scope
This plan is App-only for `app/face-cloak-app`.

The API work is handled separately in `api/face-cloak-api`. The App will call the API for account registration, authentication, images, face assignment, and logs; it should not duplicate API authorization or database logic.

## Strategy
1. **Reference Tyto App**: Use `../2-secure-session/tyto2026-app-2-secure-session` as the primary reference for execution method, secure session design, Rake tasks, and Roda code style.
2. **Transport Security**: Redirect HTTP to HTTPS and enable HSTS in production only.
3. **Service Test Isolation**: Add WebMock-backed service specs so App services can be tested without a live API.
4. **Registration Workflow**: Add a basic registration form and service object that posts `email`, `username`, and `password` to the API.
5. **Secure Messaging**: Add `SecureMessage` using `MSG_KEY` and NaCl `SimpleBox` for JSON-serializable values.
6. **Secure Session Wrapper**: Add `SecureSession` so session values are stored encrypted through `SecureMessage`.
7. **Heroku Readiness**: Configure production session storage, API URL, secrets, HTTPS/HSTS, and deployment commands.

## Reference Implementation
Use `../2-secure-session/tyto2026-app-2-secure-session` as the reference for App architecture and style.

### Tyto App Execution Method to Follow
- Install dependencies with `bundle install`.
- Copy `config/secrets.example.yml` or this project's equivalent secrets example to `config/secrets.yml`.
- Generate local session secrets with `rake generate:session_secret`.
- Generate secure message keys with `rake newkey:msg`.
- Start the API first on port `3000`.
- Start the App with `rake run:dev` on port `9292`.
- Run specs with `rake spec` once test structure exists.
- Run style checks with `rake style`.
- Run audit/release checks if the matching Rake tasks are added.

### Tyto App Code Style to Follow
- Keep `# frozen_string_literal: true` at the top of Ruby files.
- Keep Roda controllers thin: route, parse params, call services, set flash/session, redirect/render.
- Keep API communication inside service objects under `app/services`.
- Use `.new(App.config).call(...)` for App service objects, matching current FaceCloak App style.
- Use `ApiClient` as the only low-level HTTP wrapper.
- Store authenticated account state through `SecureSession`, not direct plaintext session assignment.
- Keep Slim templates focused on presentation and use partials for repeated UI.
- Keep user-facing error messages generic; log detailed server/API errors through `App.logger`.
- Match Tyto Rake task style for `generate:*`, `newkey:*`, `session:*`, `run:*`, and release checks.

## App Tasks

### 1. Transport Security
- [x] Add production-only `plugin :redirect_http_to_https`.
- [x] Add production-only `plugin :hsts`.
- [x] Confirm local development remains usable over `http://localhost:9292`.
- [x] Document that Heroku production should use HTTPS.

### 2. WebMock Service Tests
- [x] Add WebMock to the test dependencies.
- [x] Add `spec/spec_helper.rb` and `spec/test_load_all.rb` if missing.
- [x] Add `rake spec` using `Rake::TestTask`.
- [x] Add service specs for `AuthenticateAccount`.
- [x] Add service specs for registration service after it is created.
- [x] Ensure tests stub API responses and never require a live API.

### 3. Basic Registration Workflow
- [x] Add `CreateAccount` service that posts to `POST /accounts` through `ApiClient`.
- [x] Add `GET /auth/register` route.
- [x] Add `POST /auth/register` route accepting `email`, `username`, and `password`.
- [x] Add `register.slim` view with a basic registration form.
- [x] Add navigation link from login/unauthenticated UI to register.
- [x] Redirect successful registration to login with a flash notice.
- [x] Show a generic failure message on API validation or duplicate email/username.
- [x] Keep note that this workflow intentionally performs no account verification yet.

### 4. Secure Messaging Library
- [x] Add `app/lib/secure_message.rb`.
- [x] Use `MSG_KEY` from environment/config.
- [x] Use NaCl `SimpleBox` for encryption/decryption.
- [x] Encode ciphertext with URL-safe Base64.
- [x] Add `SecureMessage.generate_key` for Rake key generation.
- [x] Define clear behavior for missing or invalid `MSG_KEY`.
- [x] Add tests for encrypt/decrypt and tampered ciphertext.

### 5. Secure Session Wrapper
- [x] Add `app/lib/secure_session.rb`.
- [x] Use `SecureMessage` for all session value encryption.
- [x] Replace direct `session[:current_account] = account` with `SecureSession.new(session).set(:current_account, account)`.
- [x] Replace direct `session[:current_account]` reads with `SecureSession.new(session).get(:current_account)`.
- [x] Replace logout assignment with `SecureSession.new(session).delete(:current_account)`.
- [x] Add tests for set/get/delete/missing/corrupted session values.

### 6. Production Session Storage
- [x] Decide whether production uses `Rack::Session::Redis` like Tyto or encrypted cookies for this milestone.
- [x] Use encrypted Rack cookie sessions for this milestone, with values encrypted through `SecureSession`.
- [x] Defer Redis-backed sessions because current requirements focus on encrypted client session state.
- [x] Document that `SESSION_SECRET` and `MSG_KEY` are required in production.

### 7. Rake Tasks and Configuration
- [x] Add `rake generate:session_secret` if current task needs alignment with Tyto naming/output.
- [x] Add `rake newkey:msg`.
- [x] Add `rake spec`.
- [x] Add `rake audit`.
- [x] Add release task/check including specs, style, and audit.
- [x] Add required secrets to the secrets example file:
  - `API_URL`
  - `APP_URL`
  - `SESSION_SECRET`
  - `MSG_KEY`
  - optional Redis URL notes for production

### 8. Heroku App Deployment Readiness
- [x] Add or confirm `Procfile`.
- [x] Document Heroku `API_URL` pointing to deployed FaceCloak API `/api/v1`.
- [x] Document Heroku `APP_URL`.
- [x] Document Heroku `SESSION_SECRET`.
- [x] Document Heroku `MSG_KEY`.
- [x] Mark Redis environment variables as not required for this milestone.
- [ ] Verify deployed login/logout.
- [ ] Verify deployed registration posts to the deployed API.
- [ ] Verify deployed image views and create/update resource flows still work through the App.

## Environment Variables
- `API_URL`: FaceCloak API root, such as `https://<api-app>.herokuapp.com/api/v1`.
- `APP_URL`: FaceCloak App root, such as `https://<app>.herokuapp.com`.
- `SESSION_SECRET`: Rack session secret generated by `rake generate:session_secret`.
- `MSG_KEY`: SecureMessage key generated by `rake newkey:msg`.
- `REDISCLOUD_URL` or `REDIS_URL`: Optional production Redis session store URL.

## Risks and Notes
- Registration is intentionally basic and risky because there is no email verification or account approval yet.
- Do not store plaintext sensitive session state.
- Do not expose `MSG_KEY`, `SESSION_SECRET`, or Redis credentials to the browser.
- HSTS should be production-only and enabled carefully because browsers cache it.
- Automated tests should not require the API server to be running.
- If Redis is used, local development can use `Rack::Session::Pool` like Tyto to avoid requiring Redis locally.

## Completion Criteria
- The App follows Tyto App `2-secure-session` execution method and code style.
- HTTPS redirect and HSTS are enabled in production.
- App service tests use WebMock and pass without a live API.
- Users can register through the App, with account data posted to the API.
- Session values are encrypted through `SecureMessage` and accessed through `SecureSession`.
- Required Heroku config vars and deployment steps are documented.
- App specs/style/release checks pass where available.

## Verification Results
- `rake newkey:msg`: passed.
- `rake generate:session_secret`: passed.
- `rake spec`: 9 runs, 12 assertions, 0 failures.
- `rake style`: 27 files inspected, no offenses.
- `rake audit`: no vulnerabilities found.
- `rake release_check`: passed and reported `Ready for release!`.

## Follow-up Update: Redis Session Store Alignment

After reviewing the Tyto App `2-secure-session` implementation more closely, production session storage was aligned with Tyto's Redis-backed Rack session approach. This update supersedes the earlier milestone note that Redis was deferred, while keeping the original planning history intact above.

### What Changed
- [x] Add Redis session dependencies to `Gemfile`:
  - `redis`
  - `redis-rack`
  - `redis-store`
- [x] Require `rack/session/redis` for production Rack session storage.
- [x] Require `openssl` so `rediss://` Redis URLs can be configured with SSL params.
- [x] Configure Redis URL loading from:
  - `REDISCLOUD_URL`
  - `REDIS_URL`
- [x] Keep `Rack::Session::Pool` for development and test so local work does not require Redis.
- [x] Use `Rack::Session::Redis` in production so browser cookies store only the session id while session data is stored server-side in Redis.
- [x] Keep `SecureSession` responsible for encrypting session values with `SecureMessage` and `MSG_KEY` before they enter the Rack session.
- [x] Add `SecureSession.setup(redis_server)` for Redis configuration shared with session maintenance tasks.
- [x] Add `SecureSession.wipe_redis_sessions` for the `rake session:wipe` task.
- [x] Add `webmock/minitest` to `spec/spec_helper.rb` so service specs consistently stub external API requests.

### Current Session Storage Behavior
- Development/test:
  - `Rack::Session::Pool`
  - Session data lives in server memory.
  - Browser receives a session id cookie.
  - Redis is not required locally unless production behavior is being tested manually.
- Production:
  - `Rack::Session::Redis`
  - Session data lives in Redis.
  - Browser receives a session id cookie.
  - Session values such as `current_account` are encrypted before being stored.

### Redis Environment Notes
- Local development can set `REDISCLOUD_URL: redis://localhost:6379/0`, but it is not used by the default development middleware.
- Production must set either `REDISCLOUD_URL` or `REDIS_URL` when using `Rack::Session::Redis`.
- Heroku Redis-compatible add-ons may expose different variable names; this app checks both.
- `rediss://` URLs are supported with SSL params, matching the Tyto App approach.

### Follow-up Verification Results
- `bundle install`: passed and loaded `redis`, `redis-store`, and `redis-rack`.
- App load check: `bundle exec ruby -e "require './require_app'; require_app; puts FaceCloak::App.environment"` printed `development`.
- `rake spec`: 9 runs, 12 assertions, 0 failures, 0 errors.
- `rake style`: 27 files inspected, no offenses.
- `rake run:dev`: Puma started successfully on `http://0.0.0.0:9292`; verification server was stopped afterward.
