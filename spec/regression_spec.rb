# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Regression: Google SSO routes are wired through redirect callback flow' do
  let(:auth_source) { File.read(File.expand_path('../app/controllers/auth.rb', __dir__)) }

  it 'login view links to Google SSO start route' do
    source = File.read(File.expand_path('../app/presentation/views/login.slim', __dir__))

    _(source).must_match(%r{href=["']/auth/sso/google["']})
  end

  it 'auth controller defines Google SSO start and callback routes' do
    _(auth_source).must_match(%r{GET /auth/sso/google})
    _(auth_source).must_match(/routing\.is\('callback'\)/)
  end

  it 'auth controller validates state before exchanging the code' do
    state_position = auth_source.index('valid_google_sso_state?')
    exchange_position = auth_source.index('exchange_code')

    _(state_position).wont_be_nil
    _(exchange_position).wont_be_nil
    _(state_position).must_be :<, exchange_position
  end
end

describe 'Regression: account API key is limited and self-view only' do
  it 'account controller passes api_key from fetched profile account' do
    source = File.read(File.expand_path('../app/controllers/account.rb', __dir__))

    _(source).must_match(/api_key:\s*profile_account\.auth_token/)
  end

  it 'account view gates API Access on self-view and api_key' do
    source = File.read(File.expand_path('../app/presentation/views/account/show.slim', __dir__))

    _(source).must_match(/if profile_is_self && profile_api_key/)
  end

  it 'account view never renders the full session token directly' do
    source = File.read(File.expand_path('../app/presentation/views/account/show.slim', __dir__))

    _(source).wont_match(/@current_account\.auth_token/)
  end
end

describe 'Regression: SSO-only accounts do not show password form' do
  it 'settings view gates Change password on has_password' do
    source = File.read(File.expand_path('../app/presentation/views/account/settings.slim', __dir__))

    _(source).must_match(/can_change_password = current_account\.fetch\('has_password', true\) != false/)
    _(source).must_match(/if can_change_password/)
  end
end
