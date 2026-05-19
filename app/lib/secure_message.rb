# frozen_string_literal: true

require 'base64'
require 'json'
require 'rbnacl'

module FaceCloak
  # Encrypts/decrypts JSON-serializable values with NaCl SimpleBox.
  class SecureMessage
    class << self
      attr_reader :key

      def encoded_random_bytes(length)
        Base64.strict_encode64(RbNaCl::Random.random_bytes(length))
      end

      def generate_key
        encoded_random_bytes(RbNaCl::SecretBox.key_bytes)
      end

      def setup(msg_key)
        raise 'MSG_KEY missing' if msg_key.to_s.empty?

        @key = Base64.strict_decode64(msg_key)
      end

      def encrypt(message)
        raise 'message missing' unless message

        simple_box = RbNaCl::SimpleBox.from_secret_key(key)
        ciphertext = simple_box.encrypt(message.to_json)
        new(Base64.urlsafe_encode64(ciphertext))
      end
    end

    def initialize(ciphertext64)
      @message_secure = ciphertext64
    end

    def to_s
      @message_secure
    end

    def decrypt
      ciphertext = Base64.urlsafe_decode64(@message_secure)
      simple_box = RbNaCl::SimpleBox.from_secret_key(self.class.key)
      JSON.parse(simple_box.decrypt(ciphertext))
    end
  end
end
