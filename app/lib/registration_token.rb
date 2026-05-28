# frozen_string_literal: true

module FaceCloak
  # Encrypted email-verification token carrying only the verified email address.
  class RegistrationToken
    class InvalidTokenError < StandardError; end

    def self.load(token_string)
      payload = SecureMessage.new(token_string).decrypt
      new(email: payload.fetch('email'), token: token_string)
    rescue StandardError
      raise InvalidTokenError, 'Invalid or tampered registration token'
    end

    attr_reader :email

    def initialize(email:, token: nil)
      @email = email.to_s.strip
      @token = token || SecureMessage.encrypt(email: @email).to_s
    end

    def to_s
      @token
    end
  end
end
