# frozen_string_literal: true

module FaceCloak
  # Parser model for image access logs.
  class ImageLog
    FACE_RECORD_KEYS = %w[face_record_id face_id faceRecordId face_record].freeze
    ACTOR_KEYS = %w[actor user account].freeze
    ACTOR_ID_KEYS = %w[actor_id user_id account_id actorId userId accountId].freeze
    ASSIGNED_USER_KEYS = %w[assigned_user assignee target_user assignedUser assigned_to assignedTo target].freeze
    ASSIGNED_USER_ID_KEYS = %w[assigned_user_id assignee_id target_user_id assignedUserId assigned_to_id
                               assignedToId target_userId targetUserId target_id targetId].freeze
    ASSIGNED_USERNAME_KEYS = %w[assigned_username assignee_username target_username assignedUsername
                                assigned_to_username assignedToUsername targetUsername username].freeze
    CLOAK_TYPE_KEYS = %w[cloak_type cloakType masking_choice mask_choice privacy_choice
                         masking_status protection_status cloak_status mask_status].freeze

    attr_reader :id, :face_record_id, :action, :actor_id, :actor, :assigned_user,
                :assigned_user_id, :assigned_username, :cloak_type, :created_at, :attributes

    def self.from_api(envelope)
      new(envelope)
    end

    def initialize(envelope)
      @envelope = envelope || {}
      @attributes = @envelope['attributes'] || @envelope
      @id = value_for('id')
      @face_record_id = first_value_for(FACE_RECORD_KEYS) || relationship_id('face_record')
      @action = value_for('action')
      assign_actor_fields
      assign_assigned_user_fields
      @cloak_type = first_value_for(CLOAK_TYPE_KEYS)
      @created_at = value_for('created_at')
    end

    private_class_method :new

    def actor_username
      @actor.is_a?(Hash) ? @actor['username'] : nil
    end

    def [](key)
      value_for(key.to_s)
    end

    private

    def assign_actor_fields
      @actor = first_raw_value_for(ACTOR_KEYS)
      @actor_id = first_value_for(ACTOR_ID_KEYS) || hash_value(@actor, 'id') || relationship_id('actor')
    end

    def assign_assigned_user_fields
      @assigned_user = first_raw_value_for(ASSIGNED_USER_KEYS)
      @assigned_user_id = first_value_for(ASSIGNED_USER_ID_KEYS) || hash_value(@assigned_user, 'id') ||
                          relationship_id('assigned_user')
      @assigned_username = first_value_for(ASSIGNED_USERNAME_KEYS) || hash_value(@assigned_user, 'username')
    end

    def value_for(key)
      @attributes[key] || @envelope[key]
    end

    def first_value_for(keys)
      keys.each do |key|
        value = value_for(key) || nested_value_for(@envelope, key)
        return normalize_reference(value) unless blank?(value)
      end
      nil
    end

    def first_raw_value_for(keys)
      keys.each do |key|
        value = value_for(key) || nested_value_for(@envelope, key)
        return value unless blank?(value)
      end
      nil
    end

    def nested_value_for(value, key)
      return value[key] if value.is_a?(Hash) && value.key?(key)

      nested_children(value).each do |nested|
        found = nested_value_for(nested, key)
        return found unless blank?(found)
      end
      nil
    end

    def nested_children(value)
      return value.values if value.is_a?(Hash)
      return value if value.is_a?(Array)

      []
    end

    def relationship_id(name)
      data = @envelope.dig('relationships', name, 'data')
      data.is_a?(Hash) ? data['id'] : nil
    end

    def normalize_reference(value)
      value.is_a?(Hash) ? value['id'] || value.dig('data', 'id') || value : value
    end

    def hash_value(value, key)
      value.is_a?(Hash) ? value[key] : nil
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end
end
