# frozen_string_literal: true

require_relative '../spec_helper'

describe 'FindAccount service' do
  after do
    WebMock.reset!
  end

  it 'HAPPY: finds account id and username by exact username' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/search")
           .with(body: FaceCloak::SignedMessage.sign({ username: 'alice' }).to_json)
           .to_return(status: 200, body: { id: 1, attributes: { username: 'alice' } }.to_json)

    result = FaceCloak::FindAccount.new(app.config).call(username: '@alice')

    _(result).must_equal({ 'id' => 1, 'username' => 'alice' })
  end

  it 'HAPPY: returns nil when username is not found' do
    WebMock.stub_request(:post, "#{API_URL}/accounts/search")
           .with(body: FaceCloak::SignedMessage.sign({ username: 'alice' }).to_json)
           .to_return(status: 404, body: { message: 'Account not found' }.to_json)

    result = FaceCloak::FindAccount.new(app.config).call(username: 'alice')

    _(result).must_be_nil
  end
end
