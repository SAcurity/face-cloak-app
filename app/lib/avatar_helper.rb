# frozen_string_literal: true

module FaceCloak
  # Helper to generate avatar placeholders
  module AvatarHelper
    def avatar_for(username, size: 40)
      normalized = FaceCloak::Account.normalize_username(username)
      initial = normalized[0]&.upcase || '?'

      "<div class='avatar-circle' data-avatar-size='#{size}' data-avatar-color='#{color_for(normalized)}'>
        #{initial}
      </div>"
    end

    private

    def color_for(username)
      first = username.to_s[0]&.upcase
      colors = %w[
        #c0392b #d35400 #f39c12 #27ae60 #16a085 #2980b9 #8e44ad #2c3e50 #7f8c8d
        #b03a2e #af601a #b7950b #1e8449 #117a65 #21618c #6c3483 #34495e #566573
        #e74c3c #e67e22 #f1c40f #2ecc71 #1abc9c #3498db #9b59b6 #5d6d7
      ]
      return colors[first.ord - 'A'.ord] if first&.match?(/[A-Z]/)

      colors[0]
    end
  end
end
