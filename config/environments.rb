# frozen_string_literal: true

require 'roda'
require 'figaro'
require 'logger'
require 'openssl'
require 'rack/session'
require 'rack/session/redis'
require './app/lib/secure_message'
require './app/lib/secure_session'
require_relative '../require_app'

module FaceCloak
  # Configuration for the FaceCloak Web App
  class App < Roda
    plugin :environments

    # Environment variables setup
    Figaro.application = Figaro::Application.new(
      environment: environment,
      path: File.expand_path('config/secrets.yml')
    )
    Figaro.load
    def self.config = Figaro.env

    # HTTP Request logging
    configure :development, :production do
      plugin :common_logger, $stdout
    end

    # Custom events logging
    LOGGER = Logger.new($stderr)
    def self.logger = LOGGER

    # Session configuration
    ONE_MONTH = 30 * 24 * 60 * 60

    # Redis Cloud (free tier) exposes REDISCLOUD_URL; Heroku Redis (paid) exposes REDIS_URL.
    @redis_url = ENV.delete('REDISCLOUD_URL') || ENV.delete('REDIS_URL')

    # Heroku Redis
    @redis_server =
      if @redis_url&.start_with?('rediss://')
        { url: @redis_url, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
      else
        @redis_url
      end

    SecureMessage.setup(ENV.delete('MSG_KEY') || config.MSG_KEY)
    SecureSession.setup(@redis_server) # used by `rake session:wipe`

    configure :development, :test do
      logger.level = Logger::ERROR

      use Rack::Session::Pool,
          expire_after: ONE_MONTH

      require 'pry'

      # Allows running reload! in pry to restart entire app
      def self.reload!
        exec 'pry -r ./spec/test_load_all'
      end
    end

    configure :production do
      plugin :redirect_http_to_https
      plugin :hsts

      use Rack::Session::Redis,
          expire_after: ONE_MONTH,
          redis_server: @redis_server
    end
  end
end
