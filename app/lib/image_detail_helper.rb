# frozen_string_literal: true

require 'time'

module FaceCloak
  # Presentation helpers for the image detail and face assignment view.
  module ImageDetailHelper
    include FaceBoxHelper

    RESPONSE_TIME_KEYS = %w[responded_at response_at response_time responded_time last_response_at response_updated_at
                            consent_updated_at].freeze
    IMAGE_TIME_KEYS = %w[uploaded_at upload_time uploaded_time created_at createdAt inserted_at insertedAt
                         posted_at postedAt created_on uploaded_on timestamp].freeze
    MASK_CHOICE_KEYS = %w[cloak_type masking_choice mask_choice privacy_choice masking_status protection_status
                          cloak_status mask_status action].freeze
    MASKED_KEYS = %w[is_masked masked blurred].freeze

    def image_owner_handle(image, current_account:, is_owner:)
      owner_username = image_owner_username(image)
      return Account.handle_for(owner_username) unless owner_username.to_s.empty?

      current_username = current_account&.username.to_s.strip
      return Account.handle_for(current_username) if is_owner && !current_username.empty?

      'Unknown username'
    end

    def image_owned_by_current?(image, current_account)
      owner_id = image_owner_id(image)
      account_id = current_account&.id.to_s.strip

      !owner_id.to_s.empty? && !account_id.empty? && owner_id.to_s == account_id
    end

    def image_upload_time_label(image, logs: [])
      time = if image.respond_to?(:attributes)
               first_present(image.attributes, IMAGE_TIME_KEYS)
             elsif image.is_a?(Hash)
               first_present(image, IMAGE_TIME_KEYS)
             end

      time ||= image_log_time(logs)
      time ? format_time(time) : '-'
    end

    def image_log_time(logs)
      logs.filter_map { |log| first_present(log, %w[created_at timestamp]) }
          .min_by { |time| parse_time(time) || Time.now }
    end

    def image_owner_username(image)
      if image.respond_to?(:owner_username)
        image.owner_username.to_s.strip
      else
        owner = image['owner'].is_a?(Hash) ? image['owner'] : {}
        attrs = owner['attributes'].is_a?(Hash) ? owner['attributes'] : owner
        attrs['username'].to_s.strip
      end
    end

    def image_owner_id(image)
      if image.respond_to?(:owner_id)
        image.owner_id.to_s.strip
      else
        owner = image['owner'].is_a?(Hash) ? image['owner'] : {}
        attrs = owner['attributes'].is_a?(Hash) ? owner['attributes'] : owner
        (image['owner_id'] || attrs['id'] || owner['id']).to_s.strip
      end
    end

    def face_box_left(face, image)
      style = face_box_style(face, image)
      style ? style[/left: ([\d.]+)%/, 1].to_f : 0
    end

    def face_latest_update_label(face)
      return '-' unless face_response_updated?(face)

      response_time = first_present(face, RESPONSE_TIME_KEYS)
      response_time ? format_time(response_time) : '-'
    end

    def face_response_updated?(face)
      !!first_present(face, RESPONSE_TIME_KEYS)
    end

    def face_mask_label(face)
      mask_choice = face_cloak_type(face)
      return titleize_value(mask_choice) if mask_choice

      masked = first_present(face, MASKED_KEYS)
      return truthy_value?(masked) ? 'Blur' : 'Visible' unless masked.nil?

      'Blur'
    end

    def face_cloak_type(face)
      value = first_present(face, MASK_CHOICE_KEYS).to_s.strip.downcase
      value.empty? ? nil : value
    end

    def first_present(hash, keys)
      keys.each do |key|
        value = hash[key]
        return value unless value.nil? || value.to_s.strip.empty?
      end
      nil
    end

    def titleize_value(value)
      value.to_s.tr('_-', ' ').split.map(&:capitalize).join(' ')
    end

    def truthy_value?(value)
      !%w[false 0 no].include?(value.to_s.strip.downcase)
    end

    def format_time(value)
      Time.parse(value.to_s).strftime('%Y-%m-%d %H:%M')
    rescue ArgumentError
      value.to_s
    end

    def parse_time(value)
      Time.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
