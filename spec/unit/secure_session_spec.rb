# frozen_string_literal: true

require_relative '../spec_helper'

describe 'SecureSession' do
  it 'HAPPY: sets and gets encrypted session values' do
    raw_session = {}
    secure_session = FaceCloak::SecureSession.new(raw_session)
    account = { 'id' => 1, 'username' => 'alice' }

    secure_session.set(:current_account, account)

    _(raw_session[:current_account]).wont_equal account
    _(secure_session.get(:current_account)).must_equal account
  end

  it 'HAPPY: returns nil for missing session values' do
    secure_session = FaceCloak::SecureSession.new({})

    _(secure_session.get(:current_account)).must_be_nil
  end

  it 'HAPPY: deletes session values' do
    raw_session = {}
    secure_session = FaceCloak::SecureSession.new(raw_session)

    secure_session.set(:current_account, { 'id' => 1 })
    secure_session.delete(:current_account)

    _(secure_session.get(:current_account)).must_be_nil
  end
end
