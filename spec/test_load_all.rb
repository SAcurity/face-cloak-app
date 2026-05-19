# frozen_string_literal: true

require_relative '../require_app'
require_app

def app = FaceCloak::App

unless app.environment == :production
  require 'rack/test'
  include Rack::Test::Methods # rubocop:disable Style/MixinUsage
end
