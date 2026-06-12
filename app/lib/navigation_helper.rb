# frozen_string_literal: true

module FaceCloak
  # Helpers for navigation and URL logic
  module NavigationHelper
    MAX_NAV_NOTIFICATIONS = 8

    def parent_path(path)
      parts = path.to_s.split('/').reject(&:empty?)
      return '/' if parts.length <= 1

      "/#{parts[0...-1].join('/')}"
    end

    def assignment_notifications(account)
      return [] unless account

      current_account = GetAccount.new(FaceCloak::App.config).call(
        username: account.username,
        auth_token: account.auth_token
      )
      account_assignment_notifications(current_account)
    rescue StandardError => e
      App.logger.warn "NAV ACCOUNT NOTIFICATIONS FAILED: #{e.inspect}"
      fallback_notifications = account_assignment_notifications(account)
      fallback_notifications.empty? ? image_assignment_notifications(account) : fallback_notifications
    end

    private

    def account_assignment_notifications(account)
      account.face_assignments.filter_map.with_index do |assignment, index|
        next unless pending_assignment?(assignment)

        account_assignment_notification(assignment, index)
      end.first(MAX_NAV_NOTIFICATIONS)
    end

    def account_assignment_notification(assignment, index)
      {
        image_id: assignment['image_id'].to_s,
        face_id: assignment['face_id'].to_s,
        face_number: index + 1,
        owner: assignment_owner_label(assignment),
        path: "/images/#{assignment['image_id']}/cloak"
      }
    end

    def assignment_owner_label(assignment)
      owner = FaceCloak::Account.handle_for(assignment['owner_username'])
      owner.empty? ? 'Someone' : owner
    end

    def pending_assignment?(assignment)
      assignment['responded_at'].to_s.empty?
    end

    def image_assignment_notifications(account)
      images = ListImages.new(FaceCloak::App.config).call(auth_token: account.auth_token)
      build_assignment_notifications(images, account)
    rescue StandardError => e
      App.logger.warn "NAV NOTIFICATIONS FAILED: #{e.inspect}"
      []
    end

    def build_assignment_notifications(images, account)
      current_id = account.id.to_s
      current_username = FaceCloak::Account.normalize_username(account.username)

      images.flat_map do |image|
        image.faces.each_with_index.filter_map do |face, index|
          next unless face_assigned_to?(face, current_username, current_id)
          next if face_response_updated?(face)

          assignment_notification(image, face, index)
        end
      end.first(MAX_NAV_NOTIFICATIONS)
    end

    def assignment_notification(image, face, index)
      owner = FaceCloak::Account.handle_for(image_owner_username(image))
      {
        image_id: image.id,
        face_id: face.id.to_s,
        face_number: index + 1,
        owner: owner.empty? ? 'Someone' : owner,
        path: "/images/#{image.id}/cloak"
      }
    end
  end
end
