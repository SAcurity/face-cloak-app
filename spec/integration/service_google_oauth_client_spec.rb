# frozen_string_literal: true

require 'jwt'
require 'ostruct'
require 'uri'
require_relative '../spec_helper'

describe 'GoogleOauthClient service' do
  before do
    @config = OpenStruct.new( # rubocop:disable Style/OpenStructUse
      {
        'GOOGLE_CLIENT_ID' => 'test-google-client-id',
        'GOOGLE_CLIENT_SECRET' => 'test-google-client-secret',
        'GOOGLE_REDIRECT_URI' => 'http://localhost:9292/auth/sso/google/callback',
        'GOOGLE_OAUTH_SCOPE' => 'openid email profile',
        'APP_URL' => 'http://localhost:9292'
      }
    )
    @client = FaceCloak::GoogleOauthClient.new(@config)
    @id_token = JWT.encode({ sub: 'google-user-123', email: 'alice@example.com' }, nil, 'none')
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: builds the Google authorization URL with configured callback' do
    uri = URI.parse(@client.authorization_url(state: 'state-123'))
    params = URI.decode_www_form(uri.query).to_h

    _(uri.to_s.start_with?(FaceCloak::GoogleOauthClient::AUTHORIZATION_ENDPOINT)).must_equal true
    _(params['client_id']).must_equal @config.GOOGLE_CLIENT_ID
    _(params['redirect_uri']).must_equal 'http://localhost:9292/auth/sso/google/callback'
    _(params['response_type']).must_equal 'code'
    _(params['scope']).must_equal 'openid email profile'
    _(params['state']).must_equal 'state-123'
  end

  it 'HAPPY: exchanges a callback code for an id_token' do
    stub = WebMock.stub_request(:post, FaceCloak::GoogleOauthClient::TOKEN_ENDPOINT)
                  .to_return(status: 200, body: { id_token: @id_token }.to_json,
                             headers: { 'content-type' => 'application/json' })

    result = @client.exchange_code(code: 'callback-code')

    _(result).must_equal @id_token
    assert_requested(:post, FaceCloak::GoogleOauthClient::TOKEN_ENDPOINT) do |request|
      params = URI.decode_www_form(request.body).to_h
      params['code'] == 'callback-code' &&
        params['client_id'] == @config.GOOGLE_CLIENT_ID &&
        params['client_secret'] == @config.GOOGLE_CLIENT_SECRET &&
        params['grant_type'] == 'authorization_code'
    end
    assert_requested(stub)
  end

  it 'HAPPY: fetches Google JWKS' do
    jwks = { keys: [{ kid: 'kid-1', kty: 'RSA' }] }
    WebMock.stub_request(:get, FaceCloak::GoogleOauthClient::JWKS_ENDPOINT)
           .to_return(status: 200, body: jwks.to_json, headers: { 'content-type' => 'application/json' })

    _(FaceCloak::GoogleOauthClient.new(@config).jwks).must_equal('keys' => [{ 'kid' => 'kid-1', 'kty' => 'RSA' }])
  end

  it 'SAD: raises OAuthError on failed Google response' do
    WebMock.stub_request(:post, FaceCloak::GoogleOauthClient::TOKEN_ENDPOINT)
           .to_return(status: 400, body: { error: 'invalid_grant' }.to_json)

    _(proc {
      @client.exchange_code(code: 'bad-code')
    }).must_raise FaceCloak::GoogleOauthClient::OAuthError
  end
end
