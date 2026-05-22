# frozen_string_literal: true

require 'uri'

module FaceCloak
  # Checks whether a canonical username is already present in the API.
  class CheckUsernameAvailability
    class ApiServerError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:)
      username = Account.normalize_username(username)
      return false if username.empty?

      @client.get("/accounts/#{URI.encode_www_form_component(username)}")
      false
    rescue ApiClient::ApiError => e
      return true if e.status == 404
      raise ApiServerError, e.message if e.status >= 500

      false
    end
  end
end
