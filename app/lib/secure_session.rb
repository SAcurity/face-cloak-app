# frozen_string_literal: true

require 'redis'
require_relative 'secure_message'

module FaceCloak
  # Stores session values as SecureMessage ciphertexts.
  class SecureSession
    SESSION_SECRET_BYTES = 64

    class << self
      def setup(redis_server)
        @redis_opts = redis_server.is_a?(Hash) ? redis_server : { url: redis_server }
      end

      def generate_secret
        SecureMessage.encoded_random_bytes(SESSION_SECRET_BYTES)
      end

      def wipe_redis_sessions
        raise 'REDISCLOUD_URL or REDIS_URL missing' unless @redis_opts&.fetch(:url, nil)

        redis = Redis.new(**@redis_opts)
        # rubocop:disable Style/HashEachMethods -- Redis#keys returns an Array, not a Hash
        redis.keys.each { |session_id| redis.del session_id }
        # rubocop:enable Style/HashEachMethods
      end
    end

    def initialize(session)
      @session = session
    end

    def set(key, value)
      @session[key] = SecureMessage.encrypt(value).to_s
    end

    def get(key)
      return nil unless @session && @session[key]

      SecureMessage.new(@session[key]).decrypt
    end

    def delete(key)
      @session.delete(key)
    end
  end
end
