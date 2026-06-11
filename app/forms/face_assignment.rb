# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module FaceCloak
  module Form
    # FaceAssignment: Validate user being assigned to a face.
    class FaceAssignment < Dry::Validation::Contract
      params do
        required(:assigned_user_id).filled(:string)
        optional(:assign_self).maybe(:string)
        optional(:cloak_type).maybe(:string)
      end
    end
  end
end
