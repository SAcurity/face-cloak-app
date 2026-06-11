# frozen_string_literal: true

require_relative '../spec_helper'

describe 'ImageLog' do
  it 'HAPPY: reads top-level and nested log fields' do
    log = FaceCloak::ImageLog.from_api(
      'id' => 'log-1',
      'attributes' => {
        'action' => 'respond',
        'actor' => { 'id' => 'user-1', 'username' => 'alice' },
        'metadata' => {
          'face_record_id' => 'face-1',
          'cloak_type' => 'pixelate'
        }
      }
    )

    _(log['id']).must_equal 'log-1'
    _(log.action).must_equal 'respond'
    _(log.actor_id).must_equal 'user-1'
    _(log.actor_username).must_equal 'alice'
    _(log.face_record_id).must_equal 'face-1'
    _(log.cloak_type).must_equal 'pixelate'
  end

  it 'HAPPY: reads assigned user details from nested payloads' do
    log = FaceCloak::ImageLog.from_api(
      'attributes' => {
        'action' => 'assign',
        'details' => {
          'assigned_user' => {
            'id' => 'user-2',
            'username' => 'bob'
          }
        }
      }
    )

    _(log.assigned_user_id).must_equal 'user-2'
    _(log.assigned_username).must_equal 'bob'
  end

  it 'SAD: tolerates missing optional fields' do
    log = FaceCloak::ImageLog.from_api('attributes' => { 'action' => 'create' })

    _(log['missing']).must_be_nil
    _(log.actor_username).must_be_nil
    _(log.cloak_type).must_be_nil
  end
end
