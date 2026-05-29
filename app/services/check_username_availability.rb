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

      # Use the new search endpoint logic: find account by username
      # If found (200 OK), then the username is NOT available (taken)
      @client.post('/accounts/search', { username: username })
      false
    rescue ApiClient::ApiError => e
      # If not found (404), then the username IS available
      return true if e.status == 404
      raise ApiServerError, e.message if e.status >= 500

      false
    end
  end
end
