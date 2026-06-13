# frozen_string_literal: true

require 'json'
require 'roda'
require_relative 'app'

module FaceCloak
  # Actions for account settings and admin account management.
  module AccountSettingsActions
    private

    def delete_account_response(routing, target_username)
      target = FaceCloak::Account.normalize_username(target_username)
      delete_account(target)
      return deleted_self_response(routing) if target == @current_account.username

      flash[:notice] = 'Account deleted'
      routing.redirect '/account/settings'
    rescue StandardError => e
      flash[:error] = "Could not delete account: #{e.message}"
      routing.redirect '/account/settings'
    end

    def deleted_self_response(routing)
      CurrentSession.new(session).delete
      flash[:notice] = 'Account deleted'
      routing.redirect '/auth/login'
    end

    def delete_account(target)
      DeleteAccount.new(App.config).call(
        username: target,
        auth_token: @current_account.auth_token
      )
    end

    def update_username_response(routing)
      sync_current_account(update_username(routing.params['username']))
      flash[:notice] = 'Username updated'
      routing.redirect '/account/settings'
    rescue StandardError => e
      flash[:error] = "Could not update username: #{e.message}"
      routing.redirect '/account/settings'
    end

    def update_password_response(routing)
      update_password(routing.params)
      flash[:notice] = 'Password updated'
      routing.redirect '/account/settings?tab=security'
    rescue StandardError => e
      flash[:error] = "Could not update password: #{e.message}"
      routing.redirect '/account/settings?tab=security'
    end

    def update_identity_response(routing, target_username)
      target = FaceCloak::Account.normalize_username(target_username)
      update_identity(target, routing.params['identity'])
      flash[:notice] = 'Identity updated'
      routing.redirect '/account/settings?tab=admin'
    rescue StandardError => e
      flash[:error] = "Could not update identity: #{e.message}"
      routing.redirect '/account/settings?tab=admin'
    end

    def render_account_settings
      status_data = ListAccountStatuses.new(App.config).call(auth_token: @current_account.auth_token)
      view 'account/settings',
           locals: {
             accounts: status_data[:accounts],
             capabilities: status_data[:capabilities],
             api_key: settings_api_key
           }
    end

    def settings_api_key
      account = GetAccount.new(App.config).call(
        username: @current_account.username,
        auth_token: @current_account.auth_token
      )
      account.auth_token
    end

    def update_username(username)
      UpdateAccount.new(App.config).call(
        username: @current_account.username,
        updates: { username: FaceCloak::Account.normalize_username(username) },
        auth_token: @current_account.auth_token
      )
    end

    def update_password(params)
      UpdateAccount.new(App.config).call(
        username: @current_account.username,
        updates: password_updates(params),
        auth_token: @current_account.auth_token
      )
    end

    def update_identity(username, identity)
      raise ArgumentError, 'Admins cannot change their own identity' if username == @current_account.username

      UpdateAccount.new(App.config).call(
        username: username,
        updates: { identity: identity.to_s },
        auth_token: @current_account.auth_token
      )
    end

    def password_updates(params)
      {
        current_password: params['current_password'].to_s,
        new_password: params['new_password'].to_s
      }
    end

    def sync_current_account(updated)
      CurrentSession.new(session).current_account = FaceCloak::Account.from_api(updated, @current_account.auth_token)
      @current_account = CurrentSession.new(session).current_account
    end
  end

  # Routes for account settings and admin account management.
  module AccountSettingsRoute
    include AccountSettingsActions

    private

    def route_account_settings(routing)
      require_login!(routing)

      routing.on('username') { routing.post { update_username_response(routing) } }
      routing.on('password') { routing.post { update_password_response(routing) } }
      route_delete_account(routing)
      account_settings_response(routing)
    end

    def route_delete_account(routing)
      routing.on String do |target_username|
        routing.on('identity') { routing.post { update_identity_response(routing, target_username) } }
        routing.on('delete') { routing.post { delete_account_response(routing, target_username) } }
      end
    end

    def account_settings_response(routing)
      routing.get do
        render_account_settings
      rescue StandardError => e
        App.logger.warn "ACCOUNT SETTINGS FAILED: #{e.inspect}"
        flash[:error] = 'Could not load account settings'
        routing.redirect '/'
      end
    end
  end

  # Helpers for current-account profile image buckets.
  module AccountProfileActions
    private

    def account_profile_images(auth_token)
      image_lookup = GetImage.new(App.config)
      images = ListImages.new(App.config).call(auth_token: auth_token)
      images.each_with_object({ owned: [], assigned: [] }) do |img, grouped|
        append_profile_image(grouped, img, image_lookup, auth_token)
      end
    end

    def append_profile_image(grouped, image, image_lookup, auth_token)
      if image.owner_id.to_s == @current_account.id.to_s
        grouped[:owned] << image
      elsif image_assigned_to_current?(image_lookup.call(image.id, auth_token: auth_token))
        grouped[:assigned] << image
      end
    end

    def image_assigned_to_current?(image)
      current_user_id = @current_account.id.to_s
      current_username = FaceCloak::Account.normalize_username(@current_account.username).downcase
      Array(image&.faces).any? do |face|
        assigned_user = face['assigned_user'] || {}
        face['assigned_user_id'].to_s == current_user_id ||
          FaceCloak::Account.normalize_username(assigned_user['username']).downcase == current_username
      end
    end
  end

  # Web controller for the FaceCloak Web App
  class App < Roda
    include AccountSettingsRoute
    include AccountProfileActions

    route('account') do |routing|
      routing.on('settings') { route_account_settings(routing) }

      routing.is 'usernames' do
        require_login!(routing)

        routing.get do
          response['Content-Type'] = 'application/json'
          accounts = ListAccounts.new(App.config).call(auth_token: @current_account.auth_token)
          current_account_id = @current_account.id.to_s
          visible_accounts = accounts.reject { |account| account['id'].to_s == current_account_id }
          {
            accounts: visible_accounts.map do |account|
              { id: account['id'], username: account['username'], handle: FaceCloak::Account.handle_for(account['username']) }
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
          params['username'] = FaceCloak::Account.normalize_username(params['username'])

          completion_input = FaceCloak::Form::AccountCompletion.new.call(params)

          if completion_input.failure?
            flash.now[:error] = FaceCloak::Form.validation_errors(completion_input)
            response.status = 400
            next view(:register_confirm,
                      locals: {
                        registration_token: username_or_token,
                        email: token.email,
                        username: FaceCloak::Account.handle_for(completion_input[:username])
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
                      username: FaceCloak::Account.handle_for(username)
                    })
        rescue StandardError => e
          App.logger.error "ERROR CREATING ACCOUNT: #{e.inspect}"
          flash[:error] = 'Could not create account'
          routing.redirect '/auth/register'
        end

        require_login!(routing)
        username = FaceCloak::Account.normalize_username(username_or_token)

        # GET /account/[username]
        routing.get do
          if username == @current_account.username
            begin
              profile_images = account_profile_images(@current_account.auth_token)

              view 'account/show',
                   locals: { username: @current_account.handle,
                             owned_images: profile_images[:owned],
                             assigned_images: profile_images[:assigned] }
            rescue ApiClient::ApiError => e
              raise unless stale_session_error?(e)

              clear_stale_session!(routing)
            end
          else
            flash[:error] = 'Profile view for other users not implemented yet'
            routing.redirect '/'
          end
        end
      end
    end
  end
end
