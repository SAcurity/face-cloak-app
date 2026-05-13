# GEMINI.md

This file provides guidance to Gemini CLI when working with code in this repository.

## Project Overview

`face-cloak-app` is the server-rendered web frontend for FaceCloak, an application for privacy controls on detected faces. It is a thin presentation layer over the `face-cloak-api`.

The repo follows a branch-by-branch progression where each numbered branch introduces new functionality and a new security concern.

- **Language/runtime:** Ruby 4.0.2
- **Framework:** Roda
- **Templating:** Slim
- **Config/secrets:** Figaro (`config/secrets.yml`, gitignored)
- **Session:** Rack-session (Cookie-based, encrypted)
- **Styling**: Vanilla CSS (Apple-inspired aesthetic via `DESIGN.md`)

## Commands

- **Install dependencies:** `bundle install`
- **Run server:** `bundle exec rake run:dev` (starts Puma on port 9292)
- **Lint:** `bundle exec rake style` (RuboCop)
- **Generate Session Secret:** `bundle exec rake generate:session_secret`
- **Console:** `bundle exec rake console`

## Architecture

### Layout
```text
.
├── Gemfile / Gemfile.lock
├── Rakefile
├── require_app.rb          # autoloader for config / app/services / app/controllers
├── config.ru
├── DESIGN.md               # Visual style guide and design tokens
├── config/
│   ├── environments.rb     # Figaro + Session setup
│   └── secrets.yml         # gitignored — API_URL and SESSION_SECRET
├── app/
│   ├── controllers/        # Roda routing tree (app.rb, auth.rb, images.rb)
│   ├── services/           # Business logic and API communication (ApiClient, AuthenticateAccount)
│   └── presentation/       # Assets and Slim views
│       ├── assets/css/     # Custom CSS (style.css)
│       └── views/          # Slim templates and layouts
└── .gemini/
    ├── plans/              # Branch-specific implementation plans
    └── GEMINI.md           # This file
```

### Communication Pattern

The app communicates with the `face-cloak-api` using the `ApiClient` service:
- **X-Actor-Id Header**: Authenticated requests MUST pass the `current_account['id']` in the `X-Actor-Id` header to satisfy the API's RBAC requirements.
- **JSON Envelope**: The app expects the API to return data in a `{ data: { attributes: { ... } } }` envelope and flattens it for the views.

### Security Conventions

#### 1. Authenticated Sessions
- Use `Rack::Session::Cookie` for encrypted, server-side session storage.
- Store only essential account attributes in the session.
- Enforce login via the `require_login!` helper in controllers.

#### 2. Zero-Trust Frontend
- The frontend does not enforce authorization; it relies on the API to return 403 Forbidden for unauthorized requests.
- Handle `ApiClient::ApiError` gracefully and display user-friendly flash messages.

#### 3. Secret Hygiene
- Sensitive environment variables (e.g., `SESSION_SECRET`) MUST be managed via Figaro and never committed to source control.

## Style & Verification
- **RuboCop**: Follow idiomatic Ruby. Targets version 4.0. No offenses allowed.
- **Visuals**: Adhere strictly to the design tokens and principles in `DESIGN.md`.
- **Validation**: Perform manual verification against a running `face-cloak-api` instance.
