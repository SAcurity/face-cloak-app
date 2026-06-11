# frozen_string_literal: true

require 'roda'
require 'secure_headers'
require 'uri'
require_relative 'app'

module FaceCloak
  # Browser-facing security headers and CSP reporting for the web app.
  class App < Roda
    plugin :environments
    plugin :multi_route

    CDN_SCRIPT_SRC = %w[https://cdn.jsdelivr.net].freeze
    CDN_STYLE_SRC = %w[https://cdn.jsdelivr.net https://cdnjs.cloudflare.com].freeze
    CDN_FONT_SRC = %w[https://cdnjs.cloudflare.com].freeze

    def self.api_origin
      uri = URI(config.API_URL.to_s)
      return nil unless uri.scheme && uri.host

      "#{uri.scheme}://#{uri.host}#{api_port_suffix(uri)}"
    rescue URI::InvalidURIError
      nil
    end

    def self.api_port_suffix(uri)
      return '' if (uri.scheme == 'http' && uri.port == 80) || (uri.scheme == 'https' && uri.port == 443)

      ":#{uri.port}"
    end

    use SecureHeaders::Middleware

    api_image_origin = api_origin

    SecureHeaders::Configuration.default do |config|
      config.cookies = {
        secure: true,
        httponly: true,
        samesite: {
          lax: true
        }
      }

      config.x_frame_options = 'DENY'
      config.x_content_type_options = 'nosniff'
      config.x_xss_protection = '1'
      config.x_permitted_cross_domain_policies = 'none'
      config.referrer_policy = 'origin-when-cross-origin'

      # rubocop:disable Lint/PercentStringArray
      config.csp = {
        report_only: false,
        preserve_schemes: true,
        default_src: %w['self'],
        child_src: %w['self'],
        connect_src: %w['self'],
        img_src: %w['self' data:] + [api_image_origin].compact,
        font_src: %w['self'] + CDN_FONT_SRC,
        script_src: %w['self'] + CDN_SCRIPT_SRC,
        style_src: %w['self'] + CDN_STYLE_SRC,
        form_action: %w['self'],
        frame_ancestors: %w['none'],
        object_src: %w['none'],
        report_uri: %w[/security/report_csp_violation]
      }
      # rubocop:enable Lint/PercentStringArray
    end

    route('security') do |routing|
      routing.post 'report_csp_violation' do
        App.logger.warn "CSP VIOLATION: #{request.body.read}"
        response.status = 204
        nil
      end
    end
  end
end
