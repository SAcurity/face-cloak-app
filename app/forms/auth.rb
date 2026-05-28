# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module FaceCloak
  module Form
    # Login: username + password presence only.
    LoginCredentials = Dry::Validation.Contract do
      params do
        required(:username).filled(:string)
        required(:password).filled(:string)
      end
    end

    # Registration: email only (Step 1)
    Registration = Dry::Validation.Contract do
      params do
        required(:email).filled(:string)
      end

      rule(:email) do
        key.failure('must contain an @ sign') unless EMAIL_REGEX.match?(value)
      end
    end

    # AccountCompletion: username + password + password_confirm (Step 2)
    AccountCompletion = Dry::Validation.Contract do
      params do
        required(:username).filled(:string, min_size?: 4)
        required(:password).filled(:string)
        required(:password_confirm).filled(:string)
      end

      rule(:username) do
        key.failure('must contain only ASCII letters, digits, dots, underscores') unless
          USERNAME_REGEX.match?(value)
      end

      rule(:password_confirm, :password) do
        key.failure('does not match password') if values[:password] != values[:password_confirm]
      end
    end
  end
end
