# frozen_string_literal: true

require_relative '../spec_helper'

describe 'AssignFace service' do
  it 'posts the assigned user id' do
    stub_request(:post, "#{FaceCloak::App.config.API_URL}/face_records/face-1/assignment")
      .with(
        body: { assigned_user_id: 2 }.to_json,
        headers: {
          'Authorization' => 'Bearer owner-token'
        }
      )
      .to_return(status: 200, body: {}.to_json, headers: { 'content-type' => 'application/json' })

    result = FaceCloak::AssignFace.new(app.config).call(
      face_id: 'face-1',
      assigned_user_id: '2',
      auth_token: 'owner-token'
    )

    _(result).must_equal({})
  end
end
