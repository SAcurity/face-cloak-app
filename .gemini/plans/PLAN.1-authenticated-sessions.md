# 1-authenticated-sessions — Bootstrap, Roda/Slim, ApiClient, Auth logic [COMPLETED]

## Goal
Bootstrap the FaceCloak Web App frontend using the Roda/Slim architecture, implement secure session-based authentication, and establish a pattern for communicating with the FaceCloak API.

## Strategy
1. **Architecture Bootstrap**: Set up a modular Roda application with Slim templates, Figaro configuration, and a Rack-session layer.
2. **Authenticated Client**: Create an `ApiClient` service that encapsulates HTTP communication and includes the `X-Actor-Id` header for RBAC-sensitive requests.
3. **Session Management**: Implement a secure login/logout flow that stores account attributes in an encrypted session cookie.
4. **Zero-Trust Logic**: Ensure that views and controllers respect the authenticated state of the user.
5. **Aesthetic Alignment**: Follow the `DESIGN.md` guidelines to implement a clean, "Apple-like" interface using the Slate Bootswatch theme and custom CSS.

## Tasks

### Setup & Configuration
- [x] Initialize `Gemfile` with Roda, Slim, HTTP, and RbNaCl.
- [x] Configure `environments.rb` with Figaro and `Rack::Session::Cookie`.
- [x] Create `require_app.rb` for automatic loading of services and controllers.

### Core Infrastructure
- [x] **ApiClient**: Implement HTTP wrapper with `authenticated_*` methods sending `X-Actor-Id`.
- [x] **AuthenticateAccount Service**: Implement credential verification against the API.

### Controllers
- [x] **App Controller**: Base Roda application with `require_login!` helper.
- [x] **Auth Controller**: Routes for `GET/POST /auth/login` and `GET /auth/logout`.
- [x] **Images Controller**: Routes for `/images` index and audit logs.

### Presentation Layer
- [x] **Layout/Nav**: Standardized UI shell with authenticated/unauthenticated states.
- [x] **Views**: Home, Login, and Image-related pages (Index, Show, Logs).
- [x] **Styling**: Implement base CSS following the `DESIGN.md` tokens.

### Verification
- [x] Manually verify login/logout flow with `face-cloak-api`.
- [x] Confirm that image metadata and audit logs are correctly retrieved and displayed.
- [x] Pass RuboCop linting with project-specific exclusions.

## Key Patterns from Tyto-App
- **Service Object Pattern**: Logic extracted into `app/services` (e.g., `AuthenticateAccount`).
- **Thin Controllers**: Controllers focus on routing and session management.
- **Slim Templates**: Logic-less views using partials and layouts.
- **X-Actor-Id Header**: Pattern for passing the authenticated user's ID to the API.
