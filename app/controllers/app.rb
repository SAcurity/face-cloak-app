# frozen_string_literal: true

require 'rack/method_override'
require 'roda'
require 'slim'
require 'slim/include'

module FaceCloak
  # Base class for the FaceCloak Web App
  class App < Roda
    include AvatarHelper
    include FaceAssignmentHelper
    include ImageDetailHelper
    include ImageRouteHelper
    include NavigationHelper

    use Rack::MethodOverride

    plugin :render, engine: 'slim', views: 'app/presentation/views'
    plugin :assets, css: 'style.css', js: 'main.js', path: 'app/presentation/assets'
    plugin :public, root: 'app/presentation/public'
    plugin :multi_route
    plugin :flash
    plugin :all_verbs

    route do |routing|
      @routing = routing
      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_account = current_account_from_session

      routing.public
      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        query = routing.params['query'].to_s.strip
        normalized_query = query.downcase
        begin
          list_images = ListImages.new(FaceCloak::App.config)
          images = list_images.call(auth_token: @current_account&.auth_token)

          # Filter images based on policy if provided by API
          images = images.reject { |image| image.policies.can_view == false }

          unless normalized_query.empty?
            images = images.select do |image|
              [
                image.id,
                image.file_name,
                image.owner_id,
                image_owner_username(image)
              ].compact.any? { |value| value.to_s.downcase.include?(normalized_query) }
            end
          end
          images = images_with_upload_logs(images, @current_account&.auth_token)
        rescue StandardError => e
          puts "HOME PAGE ERROR: #{e.inspect}"
          images = []
        end
        view 'home', locals: { current_account: @current_account, images: images, query: query }
      end
    end

    private

    def current_account_from_session
      CurrentSession.new(session).current_account
    rescue StandardError => e
      App.logger.warn "SESSION READ FAILED: #{e.inspect}"
      CurrentSession.new(session).delete
      nil
    end

    def require_login!(routing)
      return if @current_account

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end

    def images_with_upload_logs(images, auth_token)
      return images unless auth_token

      images.each do |image|
        next if image_upload_time_label(image) != '-'

        image.logs = image_logs(image.id, auth_token)
      end
      images
    end
  end
end
