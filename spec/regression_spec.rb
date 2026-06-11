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
  it 'account controller passes api_key from fetched settings account' do
    source = File.read(File.expand_path('../app/controllers/account.rb', __dir__))

    _(source).must_match(/api_key:\s*settings_api_key/)
    _(source).must_match(/account\.auth_token/)
  end

  it 'settings view gates API Access on api_key' do
    source = File.read(File.expand_path('../app/presentation/views/account/settings.slim', __dir__))

    _(source).must_match(/if api_key/)
  end

  it 'settings view never renders the full session token directly' do
    source = File.read(File.expand_path('../app/presentation/views/account/settings.slim', __dir__))

    _(source).wont_match(/@current_account\.auth_token/)
  end

  it 'settings view switches the key toggle text when expanded' do
    source = File.read(File.expand_path('../app/presentation/views/account/settings.slim', __dir__))

    _(source).must_match(/show-key-label/)
    _(source).must_match(/hide-key-label/)
  end
end

describe 'Regression: SSO-only accounts do not show password form' do
  it 'settings view gates Change password on has_password' do
    source = File.read(File.expand_path('../app/presentation/views/account/settings.slim', __dir__))

    _(source).must_match(/can_change_password = current_account\.fetch\('has_password', true\) != false/)
    _(source).must_match(/if can_change_password/)
  end
end

describe 'Regression: CSP-compatible presentation source' do
  let(:view_sources) do
    Dir[File.expand_path('../app/presentation/views/**/*.slim', __dir__)].to_h do |path|
      [path, File.read(path, mode: 'r:BOM|UTF-8')]
    end
  end

  it 'views do not use inline javascript blocks' do
    offenders = view_sources.select { |_path, source| source.match?(/^\s*javascript:/) }

    _(offenders.keys).must_equal []
  end

  it 'views do not use inline style attributes' do
    offenders = view_sources.select { |_path, source| source.include?('style=') }

    _(offenders.keys).must_equal []
  end

  it 'layout gives every third-party asset an SRI hash' do
    layout = File.read(File.expand_path('../app/presentation/views/layout.slim', __dir__))
    third_party_asset_lines = layout.lines.select { |line| line.include?('https://') }

    _(third_party_asset_lines).wont_be_empty
    third_party_asset_lines.each do |line|
      _(line).must_include 'integrity="sha384-'
      _(line).must_include 'crossorigin="anonymous"'
    end
  end

  it 'layout does not load dynamic Google Fonts CSS' do
    layout = File.read(File.expand_path('../app/presentation/views/layout.slim', __dir__))

    _(layout).wont_match(/fonts\.googleapis\.com/)
    _(layout).wont_match(/Material Symbols/)
  end
end
