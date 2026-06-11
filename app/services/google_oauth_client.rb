# frozen_string_literal: true

require 'http'
require 'json'
require 'jwt'
require 'uri'

module FaceCloak
  # Performs the app-side Google OAuth/OIDC redirect callback flow.
  class GoogleOauthClient
    AUTHORIZATION_ENDPOINT = 'https://accounts.google.com/o/oauth2/v2/auth'
    TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token'
    JWKS_ENDPOINT = 'https://www.googleapis.com/oauth2/v3/certs'
    DEFAULT_SCOPE = 'openid email profile'

    class OAuthError < StandardError; end

    def initialize(config)
      @config = config
    end

    def authorization_url(state:)
      "#{AUTHORIZATION_ENDPOINT}?#{URI.encode_www_form(authorization_params(state))}"
    end

    def exchange_code(code:)
      response = HTTP.post(TOKEN_ENDPOINT, form: token_params(code))
      token_response = parse(response)
      id_token = token_response.fetch('id_token')
      JWT.decode(id_token, nil, false)
      id_token
    rescue KeyError, JWT::DecodeError => e
      raise OAuthError, "Invalid Google token response: #{e.message}"
    end

    def jwks
      parse(HTTP.get(JWKS_ENDPOINT))
    end

    def redirect_uri
      explicit_uri = @config.GOOGLE_REDIRECT_URI.to_s.strip
      return explicit_uri unless explicit_uri.empty?

      "#{@config.APP_URL}/auth/sso/google/callback"
    end

    private

    def authorization_params(state)
      {
        client_id: @config.GOOGLE_CLIENT_ID,
        redirect_uri: redirect_uri,
        response_type: 'code',
        scope: oauth_scope,
        state: state,
        prompt: 'select_account'
      }
    end

    def token_params(code)
      {
        code: code,
        client_id: @config.GOOGLE_CLIENT_ID,
        client_secret: @config.GOOGLE_CLIENT_SECRET,
        redirect_uri: redirect_uri,
        grant_type: 'authorization_code'
      }
    end

    def oauth_scope
      configured = @config.GOOGLE_OAUTH_SCOPE.to_s.strip
      configured.empty? ? DEFAULT_SCOPE : configured
    end

    def parse(response)
      body = response.body.to_s
      parsed = body.empty? ? {} : JSON.parse(body)
      raise OAuthError, 'Google OAuth request failed' unless (200..299).cover?(response.code)

      parsed
    rescue JSON::ParserError => e
      raise OAuthError, "Invalid Google OAuth response: #{e.message}"
    end
  end
end
