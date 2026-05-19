# frozen_string_literal: true

require 'roda'
require_relative 'app'

module FaceCloak
  # Web controller for the FaceCloak Web App
  class App < Roda
    route('account') do |routing|
      require_login!(routing)

      routing.on String do |username|
        # GET /account/[username]
        routing.get do
          # We'd normally look up the account by username via API
          # For now, let's assume we're looking at our own profile
          # Or if we're looking at someone else's, we need their ID
          # Simplification for demo: only show own profile images

          if username == @current_account['username']
            images = ListImages.new(App.config).call(owner_id: @current_account['id'])
            view 'account/show', locals: { username: username, images: images }
          else
            flash[:error] = 'Profile view for other users not implemented yet'
            routing.redirect '/'
          end
        end
      end
    end
  end
end
