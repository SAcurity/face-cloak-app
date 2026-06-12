# frozen_string_literal: true

module FaceCloak
  # Presentation helpers for face assignment state.
  module FaceAssignmentHelper
    ASSIGNED_TIME_KEYS = %w[assigned_at assignment_at assigned_time assignment_time assignment_created_at].freeze
    CLOAK_OPTIONS = [
      { value: 'blur', label: 'Blur', icon: 'fa-droplet' },
      { value: 'pixelate', label: 'Pixelate', icon: 'fa-border-all' },
      { value: 'comics', label: 'Comics', icon: 'fa-wand-magic-sparkles' },
      { value: 'sunglasses', label: 'Sunglasses', icon: 'fa-glasses' },
      { value: 'mask', label: 'Mask', icon: 'fa-head-side-mask' },
      { value: 'unveil', label: 'Unveil', icon: 'fa-eye' }
    ].freeze
    DECLINED_USERNAME_KEYS = %w[declined_username declined_by_username declined_by rejected_username rejected_by
                                last_declined_username last_rejected_username failed_assignee
                                failed_assignee_username].freeze
    DECLINED_USERNAME_LIST_KEYS = %w[declined_usernames rejected_usernames declined_by_usernames
                                     rejected_by_usernames failed_assignees].freeze

    def face_assigned_to?(face, username, account_id = nil)
      assigned_id = face_assigned_user_id(face).to_s
      return true if !assigned_id.empty? && !account_id.to_s.empty? && assigned_id == account_id.to_s

      FaceCloak::Account.normalize_username(face_assigned_username(face)) == FaceCloak::Account.normalize_username(username)
    end

    def face_assigned?(face)
      !face_assigned_user_id(face).to_s.empty? || !face_assigned_username(face).to_s.empty?
    end

    def face_assigned_username(face)
      if face.respond_to?(:assigned_user) && face.assigned_user.is_a?(Hash)
        face.assigned_user['username'].to_s.strip
      else
        assigned_user(face)['username'].to_s.strip
      end
    end

    def face_assigned_user_id(face)
      if face.respond_to?(:assigned_user_id)
        return face.assigned_user_id if face.assigned_user_id

        face.respond_to?(:assigned_user) && face.assigned_user.is_a?(Hash) ? face.assigned_user['id'] : nil
      else
        face['assigned_user_id'] || assigned_user(face)['id']
      end
    end

    def face_declined_handles(face)
      declined_usernames(face).map { |username| FaceCloak::Account.handle_for(username) }
    end

    def face_cloak_options
      CLOAK_OPTIONS
    end

    def cloak_option_for(value)
      normalized = value.to_s.strip.downcase
      CLOAK_OPTIONS.find { |option| option[:value] == normalized } ||
        { value: normalized, label: titleize_value(normalized), icon: 'fa-shield-halved' }
    end

    def face_assigned_time_label(face)
      assigned_time = ASSIGNED_TIME_KEYS.filter_map { |key| face[key] }.first
      assigned_time ? format_time(assigned_time) : nil
    end

    private

    def assigned_user(face)
      face['assigned_user'].is_a?(Hash) ? face['assigned_user'] : {}
    end

    def declined_usernames(face)
      declined_values(face).flat_map { |value| value.to_s.split(',') }
                           .map { |username| FaceCloak::Account.normalize_username(username) }
                           .reject(&:empty?)
                           .uniq
    end

    def declined_values(face)
      single_values = DECLINED_USERNAME_KEYS.filter_map { |key| face[key] }
      list_values = DECLINED_USERNAME_LIST_KEYS.flat_map { |key| Array(face[key]) }

      single_values + list_values
    end
  end
end
