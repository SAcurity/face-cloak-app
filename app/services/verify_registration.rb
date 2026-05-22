# frozen_string_literal: true

module FaceCloak
  # Starts email-only account verification through the API.
  class VerifyRegistration
    class VerificationError < StandardError; end
    class ApiServerError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config)
    end

    def call(email:)
      token = RegistrationToken.new(email: email).to_s
      registration = {
        email: email.to_s.strip,
        verification_url: "#{@config.APP_URL}/auth/register/#{token}"
      }

      @client.post('/auth/register', registration)
      registration
    rescue ApiClient::ApiError => e
      raise ApiServerError, e.message if e.status >= 500

      raise VerificationError, e.message
    end
  end
end
