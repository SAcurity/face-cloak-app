# frozen_string_literal: true

require 'roda'
require_relative 'app'

module FaceCloak
  # Web controller for the FaceCloak Web App
  class App < Roda
    route('account') do |routing|
      routing.on String do |username_or_token|
        # POST /account/[registration_token]
        routing.post do
          token = RegistrationToken.load(username_or_token)
          username = Account.normalize_username(routing.params['username'])
          password = routing.params['password'].to_s
          password_confirm = routing.params['password_confirm'].to_s
          errors = completion_errors(username, password, password_confirm)

          unless errors.empty?
            response.status = 400
            next view(:register_confirm,
                      locals: completion_locals(username_or_token, token.email, username, errors))
          end

          CreateAccount.new(App.config).call(email: token.email, username: username, password: password)
          flash[:notice] = 'Account created -- please log in'
          routing.redirect '/auth/login'
        rescue RegistrationToken::InvalidTokenError
          flash[:error] = 'Verification link is invalid or expired'
          routing.redirect '/auth/register'
        rescue CreateAccount::InvalidAccount => e
          response.status = 400
          next view(:register_confirm,
                    locals: completion_locals(username_or_token, token.email, username,
                                              api_completion_errors(e.message)))
        rescue StandardError => e
          App.logger.error "ERROR CREATING ACCOUNT: #{e.inspect}"
          flash[:error] = 'Could not create account'
          routing.redirect '/auth/register'
        end

        require_login!(routing)
        username = Account.normalize_username(username_or_token)

        # GET /account/[username]
        routing.get do
          if username == @current_account.username
            images = ListImages.new(App.config).call(auth_token: @current_account.auth_token)
            view 'account/show', locals: { username: @current_account.handle, images: images }
          else
            flash[:error] = 'Profile view for other users not implemented yet'
            routing.redirect '/'
          end
        end
      end
    end

    private

    def completion_errors(username, password, password_confirm)
      {}.tap do |errors|
        errors[:username] = 'Enter your username' if username.empty?
        errors[:password] = 'Enter your password' if password.empty?
        errors[:password_confirm] = 'Confirm your password' if password_confirm.empty?

        if password_confirm && !password_confirm.empty? && password != password_confirm
          errors[:password_confirm] = 'Passwords did not match'
        end
      end
    end

    def completion_locals(token, email, username, errors)
      {
        registration_token: token,
        email: email,
        username: Account.handle_for(username),
        username_error: errors[:username],
        password_error: errors[:password],
        password_confirm_error: errors[:password_confirm]
      }
    end

    def api_completion_errors(error)
      return { username: error } if error.to_s.downcase.include?('username')

      { password_confirm: error }
    end
  end
end
