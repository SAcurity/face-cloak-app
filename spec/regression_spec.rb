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

describe 'Regression: image detail template renders in app context' do
  it 'renders without unqualified model constants' do
    account = FaceCloak::Account.from_api(
      {
        'attributes' => { 'id' => 1, 'username' => 'alice', 'email' => 'alice@example.com' },
        'capabilities' => { 'is_admin' => true },
        'include' => { 'face_assignments' => [] }
      },
      'auth-token'
    )
    image = FaceCloak::Image.from_api(
      {
        'attributes' => {
          'id' => 'img-1',
          'file_name' => 'sample.png',
          'owner' => { 'id' => 1, 'username' => 'alice' }
        },
        'policies' => { 'can_manage_faces' => true, 'can_delete' => false },
        'include' => { 'faces' => [], 'logs' => [] }
      }
    )
    app_instance = FaceCloak::App.new({})
    app_instance.instance_variable_set(:@current_account, account)
    app_instance.instance_variable_set(:@routing, Struct.new(:path, :params).new('/images/img-1/raw', {}))

    html = app_instance.render(
      'images/show',
      locals: { image:, image_logs: [], accounts_by_id: {}, is_owner: true, view_type: 'raw' }
    )

    _(html).must_include 'image-detail-page'
  end
end

describe 'Regression: assigned faces remain revisitable after response' do
  it 'navigation notifications only include pending assignments' do
    source = File.read(File.expand_path('../app/lib/navigation_helper.rb', __dir__))

    _(source).must_match(/next unless pending_assignment\?/)
    _(source).must_match(/next if face_response_updated\?/)
  end

  it 'edit mode face overlay keeps self-assigned faces selectable' do
    source = File.read(File.expand_path('../app/presentation/views/images/show.slim', __dir__))

    _(source).must_include "    - if assignment_mode\n      - overlay_faces = box_faces"
  end

  it 'response mode only exposes faces assigned to the current account' do
    source = File.read(File.expand_path('../app/presentation/views/images/show.slim', __dir__))

    _(source).must_include 'my_assigned_faces = faces.select { |face| face_assigned_to?(face, current_username, current_account_id) }'
    _(source).wont_match(/my_assigned_faces = .*can_respond/)
  end

  it 'raw assignment mode is reserved for the image owner or admin' do
    source = File.read(File.expand_path('../app/presentation/views/images/show.slim', __dir__))
    route_source = File.read(File.expand_path('../app/lib/image_route_helper.rb', __dir__))

    _(source).must_match(/can_manage_all_faces = is_owner && \(current_is_image_owner \|\| current_is_admin\)/)
    _(source).must_include "assignment_mode = can_manage_all_faces && view_type == 'raw'"
    _(route_source).wont_match(/policies\.can_manage_faces \|\|/)
  end
end

describe 'Regression: notification unread controls' do
  it 'layout exposes notification IDs and bulk read controls' do
    source = File.read(File.expand_path('../app/presentation/views/layout.slim', __dir__))

    _(source).must_match(/data-notification-count/)
    _(source).must_match(/data-notification-read-all/)
    _(source).wont_match(/data-notification-unread-all/)
    _(source).must_match(/data-notification-id=notification_id/)
  end

  it 'common UI stores read notification state locally' do
    source = File.read(File.expand_path('../app/presentation/assets/js/modules/common-ui.js', __dir__))

    _(source).must_match(/facecloak\.notification\.read/)
    _(source).must_match(/updateNotificationState/)
    _(source).must_match(/readIds\.add\(itemId\(item\)\)/)
    _(source).wont_match(/readIds\.delete\(itemId\(item\)\)/)
  end
end

describe 'Regression: face assignment ownership checks' do
  it 'does not treat unassigned faces as assigned to an empty username' do
    helper = Object.new.extend(FaceCloak::FaceAssignmentHelper)
    face = FaceCloak::Face.from_api('attributes' => { 'id' => 'face-1' })

    _(helper.face_assigned_to?(face, '', '')).must_equal false
  end
end

describe 'Regression: username assignment accepts exact handles' do
  it 'face assignment form posts the typed username as a fallback' do
    source = File.read(File.expand_path('../app/presentation/views/images/show.slim', __dir__))

    _(source.scan(/name="assigned_username"/).length).must_be :>=, 2
  end

  it 'face assignment script resolves exact handle matches before submit' do
    source = File.read(File.expand_path('../app/presentation/assets/js/modules/face-assignment.js', __dir__))

    _(source).must_match(/function exactAccountMatch/)
    _(source).must_match(/function syncExactAccount/)
    _(source).must_match(/syncExactAccount\(input\);\n\s+clearAssignmentError\(form\)/)
  end

  it 'face assignment suggestions stay visible while accounts load' do
    source = File.read(File.expand_path('../app/presentation/assets/js/modules/face-assignment.js', __dir__))
    css = File.read(File.expand_path('../app/presentation/assets/css/style.css', __dir__))

    _(source).must_match(/usernamesLoading/)
    _(source).must_match(/Loading accounts/)
    _(source).must_match(/function positionSuggestionMenu/)
    _(css).must_match(/\.username-suggestion-menu \{\n\s+position: fixed/)
  end

  it 'controller can resolve assignment by username when the hidden id is missing' do
    source = File.read(File.expand_path('../app/controllers/images.rb', __dir__))

    _(source).must_match(/assigned_user_id_for_username/)
    _(source).must_match(/assignment_input\[:assigned_username\]/)
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
