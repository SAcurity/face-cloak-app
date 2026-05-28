# frozen_string_literal: true

require 'json'
require 'roda'
require_relative 'app'

module FaceCloak
  # Field-level error helpers for auth forms
  module AuthFieldErrors
    private

    def login_field_errors(username, password)
      {}.tap do |errors|
        errors[:username] = 'Enter your username' if username.empty?
        errors[:password] = 'Enter your password' if password.empty?
      end
    end

    def login_failed_errors
      {
        username: '',
        password: 'Login failed. Check your username and password.'
      }
    end
  end

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

  # Web controller for the FaceCloak Web App
  class App < Roda
    include AuthFieldErrors
    include RegistrationFlowState
    include AuthUsernameAvailabilityRoute

    route('auth') do |routing|
      @login_route = '/auth/login'
      @register_route = '/auth/register'

      routing.is 'login' do
        routing.get do
          view :login, locals: { field_errors: {} }
        end

        routing.post do
          username = Account.normalize_username(routing.params['username'])
          password = routing.params['password'].to_s

          login_errors = login_field_errors(username, password)

          if login_errors.empty?
            authed = AuthenticateAccount.new(App.config).call(
              username: username, password: password
            )
            account = Account.new(authed[:account], authed[:auth_token])

            CurrentSession.new(session).current_account = account
            flash[:notice] = "Welcome back #{account.handle}!"
            routing.redirect '/'
          end

          response.status = 400
          view :login, locals: { field_errors: login_errors }
        rescue AuthenticateAccount::UnauthorizedError
          response.status = 400
          view :login, locals: { field_errors: login_failed_errors }
        rescue AuthenticateAccount::ApiServerError => e
          App.logger.warn "API server error: #{e.inspect}"
          flash[:error] = 'Our servers are not responding -- please try later'
          response.status = 500
          routing.redirect @login_route
        rescue StandardError => e
          App.logger.warn "LOGIN FAILED: #{e.inspect}"
          response.status = 400
          view :login, locals: { field_errors: login_failed_errors }
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

      routing.on 'register' do
        routing.is String do |registration_token|
          token = RegistrationToken.load(registration_token)
          view :register_confirm, locals: {
            registration_token: registration_token,
            email: token.email,
            username: '',
            username_error: nil,
            password_error: nil,
            password_confirm_error: nil
          }
        rescue RegistrationToken::InvalidTokenError
          flash[:error] = 'Verification link is invalid or expired'
          routing.redirect @register_route
        end

        routing.is do
          routing.get do
            clear_email_verification_pending
            view :register, locals: { field_error: nil }
          end

          routing.post do
            email = routing.params['email'].to_s.strip
            if email.empty?
              response.status = 400
              next view(:register, locals: { field_error: 'Enter your email address' })
            end

            VerifyRegistration.new(App.config).call(email: email)
            mark_email_verification_pending(email)

            routing.redirect '/auth/email_verification'
          rescue VerifyRegistration::VerificationError => e
            response.status = 400
            view :register, locals: { field_error: e.message }
          rescue VerifyRegistration::ApiServerError => e
            App.logger.warn "API server error: #{e.inspect}"
            flash[:error] = 'Our servers are not responding -- please try later'
            response.status = 500
            routing.redirect @register_route
          rescue StandardError => e
            App.logger.warn "REGISTRATION FAILED: #{e.inspect}"
            response.status = 400
            view :register, locals: { field_error: 'Could not start registration' }
          end
        end
      end
    end
  end
end
