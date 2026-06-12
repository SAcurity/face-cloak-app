# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module FaceCloak
  module Form
    # FaceAssignment: Validate user being assigned to a face.
    class FaceAssignment < Dry::Validation::Contract
      params do
        optional(:assigned_user_id).maybe(:string)
        optional(:assigned_username).maybe(:string)
        optional(:assign_self).maybe(:string)
        optional(:cloak_type).maybe(:string)
      end

      rule(:assigned_user_id, :assigned_username) do
        next unless values[:assigned_user_id].to_s.strip.empty? && values[:assigned_username].to_s.strip.empty?

        key(:assigned_user_id).failure('is missing')
      end
    end
  end
end
