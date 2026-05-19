# frozen_string_literal: true

require 'roda'
require_relative 'app'

module FaceCloak
  # Web controller for the FaceCloak Web App
  class App < Roda
    route('auth') do |routing|
      @login_route = '/auth/login'
      @register_route = '/auth/register'

      routing.is 'login' do
        # GET /auth/login
        routing.get do
          view :login
        end

        # POST /auth/login
        routing.post do
          username = routing.params['username'].to_s.strip
          password = routing.params['password'].to_s

          account = AuthenticateAccount.new(App.config).call(
            username: username, password: password
          )

          SecureSession.new(session).set(:current_account, account)
          flash[:notice] = "Welcome back #{account['username']}!"
          routing.redirect '/'
        rescue StandardError => e
          App.logger.warn "LOGIN FAILED: #{e.inspect}"
          flash.now[:error] = 'Username and password did not match our records'
          response.status = 400
          view :login
        end
      end

      routing.on 'logout' do
        # GET /auth/logout
        routing.get do
          SecureSession.new(session).delete(:current_account)
          flash[:notice] = "You've been logged out"
          routing.redirect @login_route
        end
      end

      routing.is 'register' do
        # GET /auth/register
        routing.get do
          view :register
        end

        # POST /auth/register
        routing.post do
          account_data = routing.params.transform_keys(&:to_sym)
                                .slice(:email, :username, :password)
          CreateAccount.new(App.config).call(**account_data)

          flash[:notice] = 'Please sign in with your new account'
          routing.redirect @login_route
        rescue StandardError => e
          App.logger.warn "REGISTRATION FAILED: #{e.inspect}"
          flash.now[:error] = 'Could not create account'
          response.status = 400
          view :register
        end
      end
    end
  end
end
