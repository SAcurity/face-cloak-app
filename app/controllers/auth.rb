# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'roda'
require_relative 'app'

module FaceCloak
  # Tracks the short-lived register-to-email-verification page flow.
  module RegistrationFlowState
    PENDING_REGISTRATION_EMAIL_KEY = :pending_registration_email

    private

    def mark_email_verification_pending(email)
      SecureSession.new(session).set(PENDING_REGISTRATION_EMAIL_KEY, email)
    end

    def email_verification_pending?
      !SecureSession.new(session).get(PENDING_REGISTRATION_EMAIL_KEY).to_s.empty?
    end

    def clear_email_verification_pending
      SecureSession.new(session).delete(PENDING_REGISTRATION_EMAIL_KEY)
    end
  end

  # Public JSON endpoint for post-verification username checks.
  module AuthUsernameAvailabilityRoute
    private

    def route_username_availability(routing)
      routing.on 'username_available', String do |raw_username|
        routing.get do
          response['Content-Type'] = 'application/json'
          username_availability_response(raw_username)
        end
      end
    end

    def username_availability_response(raw_username)
      username = FaceCloak::Account.normalize_username(raw_username)
      return invalid_username_response if username.empty?

      {
        username: username,
        available: CheckUsernameAvailability.new(App.config).call(username: username)
      }.to_json
    rescue CheckUsernameAvailability::ApiServerError => e
      App.logger.warn "USERNAME AVAILABILITY CHECK FAILED: #{e.inspect}"
      response.status = 503
      { available: false, message: 'Could not check username right now.' }.to_json
    end

    def invalid_username_response
      response.status = 400
      { available: false, message: 'Enter your username' }.to_json
    end
  end

  # Routes for registration flow (email verification, token verification, and initial POST).
  module AuthRegistrationRoute
    private

    def route_registration(routing)
      routing.on 'register' do
        routing.is String do |registration_token|
          route_verify_token(registration_token)
        end

        routing.is do
          routing.get { route_get_registration }
          routing.post { route_post_registration(routing) }
        end
      end
    end

    def route_verify_token(registration_token)
      token = RegistrationToken.load(registration_token)
      view :register_confirm, locals: {
        registration_token: registration_token,
        email: token.email, username: '',
        username_error: nil, password_error: nil, password_confirm_error: nil
      }
    rescue RegistrationToken::InvalidTokenError
      flash[:error] = 'Verification link is invalid or expired'
      routing.redirect @register_route
    end

    def route_get_registration
      clear_email_verification_pending
      view :register
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def route_post_registration(routing)
      registration_input = FaceCloak::Form::Registration.new.call(routing.params)
      if registration_input.failure?
        flash.now[:error] = FaceCloak::Form.validation_errors(registration_input)
        response.status = 400
        return view(:register)
      end

      email = registration_input[:email]
      VerifyRegistration.new(App.config).call(email: email)
      mark_email_verification_pending(email)
      routing.redirect '/auth/email_verification'
    rescue VerifyRegistration::VerificationError => e
      response.status = 400
      flash.now[:error] = { email: e.message }
      view :register
    rescue StandardError => e
      handle_registration_error(e)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize
    def handle_registration_error(err)
      if err.is_a?(VerifyRegistration::ApiServerError)
        App.logger.warn "API server error: #{err.inspect}"
        flash[:error] = 'Our servers are not responding -- please try later'
        response.status = 500
      else
        App.logger.warn "REGISTRATION FAILED: #{err.inspect}"
        response.status = 400
        flash[:error] = 'Could not start registration'
      end
      routing.redirect @register_route
    end
    # rubocop:enable Metrics/AbcSize
  end

  # Routes for Google OAuth/OIDC SSO.
  module AuthSsoRoute
    GOOGLE_SSO_STATE_KEY = :google_sso_state

    private

    def route_sso(routing)
      routing.on 'sso' do
        routing.on 'google' do
          # GET /auth/sso/google
          routing.is { routing.get { start_google_sso(routing) } }
          # GET /auth/sso/google/callback
          routing.is('callback') { routing.get { complete_google_sso(routing) } }
        end
      end
    end

    def start_google_sso(routing)
      state = SecureRandom.urlsafe_base64(32)
      secure_session.set(GOOGLE_SSO_STATE_KEY, state)
      routing.redirect GoogleOauthClient.new(App.config).authorization_url(state: state)
    rescue GoogleOauthClient::OAuthError => e
      App.logger.warn "GOOGLE SSO START FAILED: #{e.message}"
      flash[:error] = 'Could not start Google sign-in'
      routing.redirect @login_route
    end

    def complete_google_sso(routing)
      return google_sso_denied(routing) if routing.params['error']
      return google_sso_state_failed(routing) unless valid_google_sso_state?(routing.params['state'])

      finish_google_sso(routing, google_sso_account(routing.params['code'].to_s))
    rescue GoogleOauthClient::OAuthError, AuthenticateSsoAccount::UnauthorizedError => e
      google_sso_auth_failed(routing, e)
    rescue AuthenticateSsoAccount::ApiServerError => e
      google_sso_api_failed(routing, e)
    end

    def google_sso_account(code)
      oauth = GoogleOauthClient.new(App.config)
      AuthenticateSsoAccount.new(App.config).call(
        provider: 'google',
        id_token: oauth.exchange_code(code: code),
        jwks: oauth.jwks
      )
    end

    def finish_google_sso(routing, account)
      secure_session.delete(GOOGLE_SSO_STATE_KEY)
      CurrentSession.new(session).current_account = account
      flash[:notice] = "Welcome back #{account.handle}!"
      routing.redirect '/'
    end

    def google_sso_auth_failed(routing, error)
      App.logger.warn "GOOGLE SSO FAILED: #{error.message}"
      secure_session.delete(GOOGLE_SSO_STATE_KEY)
      flash[:error] = 'Google sign-in failed'
      routing.redirect @login_route
    end

    def google_sso_api_failed(routing, error)
      App.logger.warn "API server error: #{error.inspect}"
      secure_session.delete(GOOGLE_SSO_STATE_KEY)
      flash[:error] = 'Our servers are not responding -- please try later'
      routing.redirect @login_route
    end

    def google_sso_denied(routing)
      secure_session.delete(GOOGLE_SSO_STATE_KEY)
      flash[:error] = 'Google sign-in was cancelled'
      routing.redirect @login_route
    end

    def google_sso_state_failed(routing)
      App.logger.warn 'GOOGLE SSO STATE MISMATCH'
      secure_session.delete(GOOGLE_SSO_STATE_KEY)
      flash[:error] = 'Google sign-in failed'
      routing.redirect @login_route
    end

    def valid_google_sso_state?(actual_state)
      expected_state = secure_session.get(GOOGLE_SSO_STATE_KEY).to_s
      return false if expected_state.empty? || actual_state.to_s.empty?
      return false unless expected_state.bytesize == actual_state.to_s.bytesize

      Rack::Utils.secure_compare(expected_state, actual_state.to_s)
    end

    def secure_session
      SecureSession.new(session)
    end
  end

  # Web controller for the FaceCloak Web App
  class App < Roda
    include RegistrationFlowState
    include AuthUsernameAvailabilityRoute
    include AuthRegistrationRoute
    include AuthSsoRoute

    route('auth') do |routing|
      @login_route = '/auth/login'
      @register_route = '/auth/register'

      routing.is 'login' do
        routing.get do
          view :login
        end

        routing.post do
          login_input = FaceCloak::Form::LoginCredentials.new.call(routing.params)
          if login_input.failure?
            flash.now[:error] = FaceCloak::Form.validation_errors(login_input)
            response.status = 400
            next view(:login)
          end

          # Use to_h to ensure we have a clean hash for service call
          credentials = login_input.to_h
          username = FaceCloak::Account.normalize_username(credentials[:username])
          password = credentials[:password]

          account = AuthenticateAccount.new(App.config).call(
            username: username, password: password
          )

          CurrentSession.new(session).current_account = account
          flash[:notice] = "Welcome back #{account.handle}!"
          routing.redirect '/'
        rescue AuthenticateAccount::UnauthorizedError
          flash.now[:error] = { username: '', password: 'Login failed. Check your username and password.' }
          response.status = 400
          view :login
        rescue AuthenticateAccount::ApiServerError => e
          App.logger.warn "API server error: #{e.inspect}"
          flash[:error] = 'Our servers are not responding -- please try later'
          response.status = 500
          routing.redirect @login_route
        rescue StandardError => e
          # CRITICAL: Log the actual error to find the root cause
          App.logger.error "LOGIN CRASHED: #{e.class} - #{e.message}\n#{e.backtrace[0..5].join("\n")}"
          flash.now[:error] = { username: '', password: 'Login failed. Check your username and password.' }
          response.status = 400
          view :login
        end
      end

      routing.on 'logout' do
        routing.get do
          CurrentSession.new(session).delete
          flash[:notice] = "You've been logged out"
          routing.redirect @login_route
        end
      end

      route_sso(routing)
      route_username_availability(routing)

      routing.is 'email_verification' do
        routing.get do
          routing.redirect @register_route unless email_verification_pending?

          view :email_verification
        end
      end

      route_registration(routing)
    end
  end
end
