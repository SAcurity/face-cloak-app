# frozen_string_literal: true

require 'roda'
require_relative 'app'

module FaceCloak
  # Routes for face-record operations (respond, decline, assign).
  module ImagesFaceRecordRoute
    private

    def route_face_records(routing, image_id, auth_token)
      routing.on 'faces', String do |face_id|
        routing.on('respond') { route_respond_face(routing, image_id, face_id, auth_token) }
        routing.on('decline') { route_decline_face(routing, image_id, face_id, auth_token) }
        routing.on('unassign') { route_unassign_face(routing, image_id, face_id, auth_token) }
        routing.post { route_assign_face(routing, image_id, face_id, auth_token) }
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def route_respond_face(routing, image_id, face_id, auth_token)
      routing.post do
        return_view = safe_image_return_view(routing.params)
        RespondFaceAssignment.new(FaceCloak::App.config).call(
          face_id: face_id, cloak_type: routing.params['cloak_type'], auth_token: auth_token
        )
        flash[:notice] = 'Masking preference saved'
        routing.redirect "/images/#{image_id}/#{return_view}"
      rescue StandardError => e
        flash[:error] = "Could not save masking preference: #{e.message}"
        routing.redirect "/images/#{image_id}/#{safe_image_return_view(routing.params)}"
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def route_decline_face(routing, image_id, face_id, auth_token)
      routing.post do
        return_view = safe_image_return_view(routing.params)
        DeclineFaceAssignment.new(FaceCloak::App.config).call(face_id: face_id, auth_token: auth_token)
        flash[:notice] = 'Assignment declined'
        routing.redirect "/images/#{image_id}/#{return_view}"
      rescue StandardError => e
        flash[:error] = "Could not decline assignment: #{e.message}"
        routing.redirect "/images/#{image_id}/#{safe_image_return_view(routing.params)}"
      end
    end

    def route_unassign_face(routing, image_id, face_id, auth_token)
      routing.post do
        UnassignFace.new(FaceCloak::App.config).call(face_id: face_id, auth_token: auth_token)
        flash[:notice] = 'Assignment removed'
        routing.redirect "/images/#{image_id}/raw"
      rescue StandardError => e
        flash[:error] = "Could not remove assignment: #{e.message}"
        routing.redirect "/images/#{image_id}/raw"
      end
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def route_assign_face(routing, image_id, face_id, auth_token)
      assignment_input = FaceCloak::Form::FaceAssignment.new.call(routing.params)
      if assignment_input.failure?
        flash[:error] = FaceCloak::Form.validation_errors(assignment_input).values.join(', ')
        return routing.redirect "/images/#{image_id}/raw"
      end

      uid = assignment_input[:assigned_user_id].to_s.strip
      self_assign = assignment_input[:assign_self].to_s == 'true'

      if uid == @current_account.id.to_s && !self_assign
        flash[:error] = 'Use [Myself] button to assign your own face'
        return routing.redirect "/images/#{image_id}/raw"
      end

      AssignFace.new(FaceCloak::App.config).call(face_id: face_id, assigned_user_id: uid, auth_token: auth_token)
      
      if self_assign && !assignment_input[:cloak_type].to_s.empty?
        RespondFaceAssignment.new(FaceCloak::App.config).call(
          face_id: face_id,
          cloak_type: assignment_input[:cloak_type],
          auth_token: auth_token
        )
        flash[:notice] = 'Masking preference saved'
        routing.redirect "/images/#{image_id}/#{safe_image_return_view(routing.params)}"
      else
        flash[:notice] = routing.params['action'] == 'remind' ? 'Notification sent' : 'Face assigned successfully'
        routing.redirect "/images/#{image_id}/raw"
      end
    rescue StandardError => e
      flash[:error] = "Could not assign face: #{e.message}"
      routing.redirect "/images/#{image_id}/raw"
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end

  # Web controller for the FaceCloak Web App
  class App < Roda
    include ImagesFaceRecordRoute

    route('images') do |routing|
      require_login!(routing)
      auth_token = @current_account.auth_token

      # GET /images/new
      routing.is 'new' do
        view 'images/new'
      end

      routing.on String do |image_id|
        routing.on 'delete' do
          routing.post { delete_image_response(routing, image_id, auth_token) }
        end

        %w[cloak raw].each do |variant|
          routing.on variant do
            routing.get do
              if image_asset_request?
                image_variant_response(routing, image_id, variant, auth_token)
              else
                image_detail_response(routing, image_id, variant, auth_token)
              end
            end
          end
        end

        # GET /images/[image_id]/logs
        routing.on 'logs' do
          routing.get do
            logs = GetImageLogs.new(FaceCloak::App.config).call(
              image_id: image_id,
              auth_token: auth_token
            )
            view 'images/logs', locals: {
              image_id: image_id,
              logs: logs,
              accounts_by_id: log_accounts_by_id(auth_token)
            }
          rescue StandardError => e
            flash[:error] = "Could not load logs: #{e.message}"
            routing.redirect '/'
          end
        end

        route_face_records(routing, image_id, auth_token)

        # GET /images/[image_id]
        routing.is do
          routing.get do
            requested_view = routing.params['view'].to_s
            requested_view = nil unless %w[cloak raw].include?(requested_view)
            image_detail_redirect(routing, image_id, requested_view, auth_token)
          end
        end
      end

      # GET /images
      routing.get do
        routing.redirect '/'
      end

      # POST /images
      routing.post do
        image_file = routing.params['file']
        UploadImage.new(FaceCloak::App.config).call(
          auth_token: auth_token,
          file_path: image_file[:tempfile].path,
          file_name: image_file[:filename]
        )
        flash[:notice] = 'Image posted successfully'
        routing.redirect '/'
      rescue StandardError => e
        flash[:error] = "Could not post image: #{e.message}"
        routing.redirect '/images/new'
      end
    end

    private

    def log_accounts_by_id(auth_token)
      ListAccounts.new(FaceCloak::App.config).call(auth_token: auth_token).to_h do |account|
        [account['id'].to_s, account['username']]
      end
    rescue StandardError => e
      App.logger.warn "LOG ACCOUNT LOOKUP FAILED: #{e.inspect}"
      {}
    end

    def delete_image_response(routing, image_id, auth_token)
      DeleteImage.new(FaceCloak::App.config).call(image_id: image_id, auth_token: auth_token)
      flash[:notice] = 'Image deleted'
      routing.redirect '/'
    rescue StandardError => e
      flash[:error] = "Could not delete image: #{e.message}"
      routing.redirect "/images/#{image_id}/cloak"
    end
  end
end
