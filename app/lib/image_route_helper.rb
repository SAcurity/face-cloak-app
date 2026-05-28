# frozen_string_literal: true

module FaceCloak
  # Shared route helpers for image detail pages and proxied image variants.
  module ImageRouteHelper
    def image_asset_request?
      accept = request.env['HTTP_ACCEPT'].to_s
      accept.include?('image/') && !accept.include?('text/html')
    end

    def image_variant_response(routing, image_id, variant, auth_token)
      api_path = variant == 'raw' ? "/images/#{image_id}/raw" : "/images/#{image_id}"
      api_res = HTTP.auth("Bearer #{auth_token}").get("#{FaceCloak::App.config.API_URL}#{api_path}")

      routing.halt(api_res.code, api_res.body.to_s) unless api_res.code == 200

      response['Content-Type'] = api_res.headers['Content-Type']
      api_res.body.to_s
    end

    def image_detail_redirect(routing, image_id, requested_view, auth_token)
      image_data = find_image_or_not_found(image_id, auth_token)
      return "Image #{image_id} not found in API" unless image_data

      can_view_raw = image_data.policies.can_view_raw
      canonical_view = requested_view || (can_view_raw ? 'raw' : 'protected')
      canonical_view = 'protected' if canonical_view == 'raw' && !can_view_raw

      routing.redirect "/images/#{image_id}/#{canonical_view}"
    end

    def image_detail_response(routing, image_id, view_type, auth_token)
      image_data = find_image_or_not_found(image_id, auth_token)
      return "Image #{image_id} not found in API" unless image_data

      can_view_raw = image_data.policies.can_view_raw
      routing.redirect "/images/#{image_id}/protected" if view_type == 'raw' && !can_view_raw

      view 'images/show', locals: {
        image: image_data,
        image_logs: image_logs(image_id, auth_token),
        is_owner: can_view_raw, # 'is_owner' in view now means 'has raw access'
        view_type: view_type
      }
    end

    def safe_image_return_view(params)
      return_view = params['return_view'].to_s
      %w[raw protected].include?(return_view) ? return_view : 'protected'
    end

    def find_image_or_not_found(image_id, auth_token)
      image_data = GetImage.new(FaceCloak::App.config).call(image_id, auth_token: auth_token)
      response.status = 404 unless image_data
      image_data
    end

    def image_logs(image_id, auth_token)
      GetImageLogs.new(FaceCloak::App.config).call(image_id: image_id, auth_token: auth_token)
    rescue StandardError => e
      App.logger.warn "IMAGE LOG FALLBACK FAILED: #{e.inspect}"
      []
    end
  end
end
