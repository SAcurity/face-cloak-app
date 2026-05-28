# frozen_string_literal: true

module FaceCloak
  # Helper to generate avatar placeholders
  module AvatarHelper
    def avatar_for(username, size: 40)
      normalized = Account.normalize_username(username)
      initial = normalized[0]&.upcase || '?'

      "<div class='avatar-circle' style='#{avatar_style(normalized, size)};'>
        #{initial}
      </div>"
    end

    private

    def avatar_style(username, size)
      [
        "width: #{size}px",
        "height: #{size}px",
        "background-color: #{color_for(username)} !important",
        "font-size: #{size / 2}px",
        'border: 1px solid rgba(255,255,255,0.12)'
      ].join('; ')
    end

    def color_for(username)
      # Deterministic, muted palette that avoids using the primary action color
      sum = username.to_s.each_byte.sum
      colors = %w[
        #6b6f77
        #7f8a92
        #9aa3ab
        #a08d79
        #8aa28a
        #b29aa6
      ]
      colors[sum % colors.length]
    end
  end
end
