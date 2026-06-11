# frozen_string_literal: true

require 'ostruct'

module FaceCloak
  # Session identity wrapper for API account data and its bearer token.
  class Account
    attr_reader :account_info, :auth_token, :policies

    def self.from_api(account_info, auth_token = nil)
      new(account_info, auth_token)
    end

    def initialize(account_info, auth_token)
      @account_info = account_info
      @auth_token = auth_token
      @policies = OpenStruct.new(account_info['policies'] || {}) # rubocop:disable Style/OpenStructUse
    end

    private_class_method :new

    def logged_in?
      !@account_info.nil? && !@auth_token.to_s.empty?
    end

    def logged_out?
      !logged_in?
    end

    def id
      attributes&.dig('id')
    end

    def username
      attributes&.dig('username')
    end

    def handle
      self.class.handle_for(username)
    end

    def email
      attributes&.dig('email')
    end

    def face_assignments
      @account_info&.dig('include', 'face_assignments') || []
    end

    def capabilities
      @account_info&.dig('capabilities') || {}
    end

    def [](key)
      attributes&.dig(key.to_s) || @account_info&.dig(key.to_s)
    end

    def self.normalize_username(value)
      value.to_s.strip.sub(/\A@+/, '').strip
    end

    def self.handle_for(value)
      normalized = normalize_username(value)
      normalized.empty? ? '' : "@#{normalized}"
    end

    private

    def attributes
      @account_info&.fetch('attributes', @account_info)
    end
  end
end
