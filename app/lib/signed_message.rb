# frozen_string_literal: true

require 'base64'
require 'json'
require 'rbnacl'

module FaceCloak
  # Signs outgoing unauthenticated API request bodies with this app's private
  # Ed25519 key so the API can verify the body came from this client.
  class SignedMessage
    class KeypairError < StandardError; end

    class << self
      def setup(signing_key64)
        raise KeypairError, 'Signing key not found' if signing_key64.to_s.empty?

        @signing_key = Base64.strict_decode64(signing_key64)
      rescue StandardError
        raise KeypairError, 'Signing key not found'
      end

      def sign(message)
        signing_key = RbNaCl::SigningKey.new(@signing_key)
        raw_signature = signing_key.sign(message.to_json)
        signature = Base64.strict_encode64(raw_signature)

        { data: message, signature: signature }
      end
    end
  end
end
