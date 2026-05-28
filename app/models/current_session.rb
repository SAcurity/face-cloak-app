# frozen_string_literal: true

module FaceCloak
  # Stores authenticated API account data and bearer token in SecureSession.
  class CurrentSession
    def initialize(session)
      @secure_session = SecureSession.new(session)
    end

    def current_account
      account_info = @secure_session.get(:account)
      auth_token = @secure_session.get(:auth_token)
      return nil unless account_info && auth_token

      Account.from_api(account_info, auth_token)
    end

    def current_account=(account)
      @secure_session.set(:account, account.account_info)
      @secure_session.set(:auth_token, account.auth_token)
    end

    def delete
      @secure_session.delete(:account)
      @secure_session.delete(:auth_token)
      @secure_session.delete(:current_account)
    end
  end
end
