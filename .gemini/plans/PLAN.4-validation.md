# PLAN: Policies and Validation

This plan implements centralized resource policies and user input validation using `dry-validation` and native parser models.

## Phase 1: Dependencies and Infrastructure

1. [x] **Update Gemfile**: Add `dry-validation` and `ostruct`.
   - `gem 'dry-validation', '~> 1.10'`
   - `gem 'ostruct'` (for Ruby 3.5+ compatibility)
2. [x] **Base Form Class**: Create `app/forms/form_base.rb`.
   - Define `FaceCloak::Form` module.
   - Add `validation_errors(validation)` and `message_values(validation)` helpers.
   - Define common regex/constants (e.g., `USERNAME_REGEX`).
3. [x] **Validation View Component**: Create `app/presentation/views/_validation_errors.slim`.
   - Render Hash-shaped `flash[:error]`.
4. [x] **Update Flash Bar**: Modify `app/presentation/views/flash_bar.slim`.
   - Ensure it only renders string-shaped errors, letting `_validation_errors.slim` handle Hash errors on specific pages.

## Phase 2: Input Validation (Forms)

1. [x] **Auth Forms**: Create `app/forms/auth.rb`.
   - `LoginCredentials`: Validate presence of `username` and `password`.
   - `Registration`: Validate `username` (regex) and `email` (presence/format).
2. [x] **Image Forms**:
   - Create `app/forms/image_upload.rb` (if needed, or just validate in controller if simple).
   - Create `app/forms/face_assignment.rb` for assigning faces.
3. [x] **Update Controllers**:
   - `app/controllers/auth.rb`: Use `LoginCredentials` and `Registration` contracts.
   - `app/controllers/images.rb`: Use `FaceAssignment` contract for POST `/images/:id/faces`.

## Phase 3: Parser Models (App Models)

1. [x] **Refactor Account Model**: Update `app/models/account.rb`.
   - Implement `Account.from_api(envelope, auth_token)`.
   - Wrap `envelope['policies']` in an `OpenStruct`.
   - Ensure no API parsing logic remains in controllers or services.
2. [x] **Create Image Model**: Create `app/models/image.rb`.
   - Implement `Image.from_api(envelope)`.
   - Parse `attributes` and `policies` (including `can_view_raw`, `can_delete`).
   - Handle nested `includes` by converting them to models.
3. [x] **Create Face Model**: Create `app/models/face.rb`.
   - Parser for `FaceRecord` with its own `policies` (`can_assign`, `can_respond`).
4. [x] **Create ImageLog Model**: Create `app/models/image_log.rb`.
   - Simple parser for log entries.
5. [x] **Refactor Services**:
   - Update `ListImages`, `GetImage`, `ListAccounts`, etc., to return Model objects instead of raw Hashes.

## Phase 4: Policy-based Authorization (Views)

1. [x] **Home Page**:
   - Use `image.policies.can_view` to filter display in `app.rb`.
2. [x] **Image Details**:
   - Use `image.policies.can_view_raw` to show/hide "Raw" view and assignment features.
3. [x] **Face Actions (Zero-Trust Alignment)**:
   - Use `face.policies.can_assign` to show/hide assignment forms (Owner/Admin only).
   - Use `face.policies.can_respond` to show/hide response buttons (Assignee only).


## Phase 5: Verification

1. [x] **Lint**: Run `bundle exec rake style`.
2. [x] **Manual Test**: 
   - Verify login/registration shows validation errors for invalid input (Logic implemented).
   - Verify buttons only appear for users with correct permissions (Logic implemented via policies).
   - Verify no "parsing" logic remains in controllers (Refactored to Parser Models).
3. [x] **Automated Tests**: Run `bundle exec rake spec` to ensure no regressions.
