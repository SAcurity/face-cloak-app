# frozen_string_literal: true

require_relative '../spec_helper'

describe 'CheckUsernameAvailability service' do
  after do
    WebMock.reset!
  end

  it 'HAPPY: returns false when username exists' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/search")
           .with(body: { username: 'alice' }.to_json)
           .to_return(status: 200, body: { attributes: { username: 'alice' } }.to_json)

    result = FaceCloak::CheckUsernameAvailability.new(app.config).call(username: 'alice')

    _(result).must_equal false
  end

  it 'HAPPY: returns true when username is not found' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/search")
           .with(body: { username: 'alice' }.to_json)
           .to_return(status: 404, body: { message: 'Account not found' }.to_json)

    result = FaceCloak::CheckUsernameAvailability.new(app.config).call(username: '@alice')

    _(result).must_equal true
  end

  it 'BAD: raises ApiServerError when API fails' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/search")
           .with(body: { username: 'alice' }.to_json)
           .to_return(status: 500, body: { message: 'database unavailable' }.to_json)

    _(proc {
      FaceCloak::CheckUsernameAvailability.new(app.config).call(username: 'alice')
    }).must_raise FaceCloak::CheckUsernameAvailability::ApiServerError
  end
end
