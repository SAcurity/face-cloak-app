# frozen_string_literal: true

require 'rack/method_override'
require 'roda'
require 'slim'
require 'slim/include'

module FaceCloak
  # Base class for the FaceCloak Web App
  class App < Roda
    include AvatarHelper
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
      @current_account = session[:current_account]

      routing.public
      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        query = routing.params['query'].to_s.strip
        normalized_query = query.downcase
        begin
          images = ListImages.new(FaceCloak::App.config).call
          unless normalized_query.empty?
            images = images.select do |image|
              [
                image['id'],
                image['file_name'],
                image['owner_id']
              ].compact.any? { |value| value.to_s.downcase.include?(normalized_query) }
            end
          end
        rescue StandardError => e
          puts "HOME PAGE ERROR: #{e.inspect}"
          images = []
        end
        view 'home', locals: { current_account: @current_account, images: images, query: query }
      end
    end

    private

    def require_login!(routing)
      return if @current_account

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end
  end
end
