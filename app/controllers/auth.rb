# frozen_string_literal: true

require 'json'
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
      username = Account.normalize_username(raw_username)
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

  # Web controller for the FaceCloak Web App
  class App < Roda
    include RegistrationFlowState
    include AuthUsernameAvailabilityRoute
    include AuthRegistrationRoute

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
          username = Account.normalize_username(credentials[:username])
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
