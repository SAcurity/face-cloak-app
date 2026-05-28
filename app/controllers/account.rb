# frozen_string_literal: true

require 'json'
require 'roda'
require_relative 'app'

module FaceCloak
  # Web controller for the FaceCloak Web App
  class App < Roda
    route('account') do |routing|
      routing.is 'usernames' do
        require_login!(routing)

        routing.get do
          response['Content-Type'] = 'application/json'
          accounts = ListAccounts.new(App.config).call(auth_token: @current_account.auth_token)
          current_account_id = @current_account.id.to_s
          visible_accounts = accounts.reject { |account| account['id'].to_s == current_account_id }
          {
            accounts: visible_accounts.map do |account|
              { id: account['id'], username: account['username'], handle: Account.handle_for(account['username']) }
            end
          }.to_json
        rescue StandardError => e
          App.logger.warn "USERNAME LIST FAILED: #{e.inspect}"
          { accounts: [] }.to_json
        end
      end

      routing.on String do |username_or_token|
        # POST /account/[registration_token]
        routing.post do
          token = RegistrationToken.load(username_or_token)

          # Normalize username before validation to match contract expectations
          params = routing.params.dup
          params['username'] = Account.normalize_username(params['username'])

          completion_input = FaceCloak::Form::AccountCompletion.new.call(params)

          if completion_input.failure?
            flash.now[:error] = FaceCloak::Form.validation_errors(completion_input)
            response.status = 400
            next view(:register_confirm,
                      locals: {
                        registration_token: username_or_token,
                        email: token.email,
                        username: Account.handle_for(completion_input[:username])
                      })
          end

          username = completion_input[:username]
          password = completion_input[:password]

          CreateAccount.new(App.config).call(email: token.email, username: username, password: password)
          flash[:notice] = 'Account created -- please log in'
          routing.redirect '/auth/login'
        rescue RegistrationToken::InvalidTokenError
          flash[:error] = 'Verification link is invalid or expired'
          routing.redirect '/auth/register'
        rescue CreateAccount::InvalidAccount => e
          response.status = 400
          api_errors = if e.message.to_s.downcase.include?('username')
                         { username: e.message }
                       else
                         { password_confirm: e.message }
                       end
          flash.now[:error] = api_errors
          next view(:register_confirm,
                    locals: {
                      registration_token: username_or_token,
                      email: token.email,
                      username: Account.handle_for(username)
                    })
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
            images = images.select { |image| image_owned_by_current?(image, @current_account) }
            view 'account/show', locals: { username: @current_account.handle, images: images }
          else
            flash[:error] = 'Profile view for other users not implemented yet'
            routing.redirect '/'
          end
        end
      end
    end

    private

    def some_other_private_method_if_needed
      # This space intentionally left for future private methods
    end
  end
end
