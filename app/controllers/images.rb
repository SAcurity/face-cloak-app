# frozen_string_literal: true

require 'roda'
require_relative 'app'

module FaceCloak
  # Web controller for the FaceCloak Web App
  class App < Roda
    route('images') do |routing|
      require_login!(routing)
      current_account_id = @current_account['id']

      # GET /images/new
      routing.is 'new' do
        view 'images/new'
      end

      routing.on String do |image_id|
        # GET /images/[image_id]/raw_image
        routing.on 'raw_image' do
          routing.get do
            response = HTTP.headers('X-Actor-Id' => current_account_id.to_s)
                          .get("#{FaceCloak::App.config.API_URL}/images/#{image_id}/raw")
            
            routing.halt(response.code, response.body.to_s) unless response.code == 200
            
            response['Content-Type'].each { |ct| response['Content-Type'] = ct }
            response.body.to_s
          end
        end

        # GET /images/[image_id]/logs
        routing.on 'logs' do
          routing.get do
            logs = GetImageLogs.new(FaceCloak::App.config).call(
              image_id: image_id,
              current_account_id: current_account_id
            )
            view 'images/logs', locals: { image_id: image_id, logs: logs }
          rescue StandardError => e
            flash[:error] = "Could not load logs: #{e.message}"
            routing.redirect '/images'
          end
        end

        # GET /images/[image_id]
        routing.is do
          routing.get do
            image_data = GetImage.new(FaceCloak::App.config).call(image_id)
            routing.halt 404, "Image #{image_id} not found in API" unless image_data

            is_owner = image_data['owner_id'].to_i == current_account_id.to_i
            view_type = routing.params['view'] || 'protected'

            view 'images/show', locals: { 
              image: image_data, 
              is_owner: is_owner, 
              view_type: view_type 
            }
          end
        end
      end

      # GET /images
      routing.get do
        images_list = ListImages.new(FaceCloak::App.config).call
        view 'images/index', locals: { images: images_list }
      end

      # POST /images
      routing.post do
        image_file = routing.params['file']
        UploadImage.new(FaceCloak::App.config).call(
          current_account_id: current_account_id,
          file_path: image_file[:tempfile].path,
          file_name: image_file[:filename]
        )
        flash[:notice] = 'Image posted successfully'
        routing.redirect '/images'
      rescue StandardError => e
        flash[:error] = "Could not post image: #{e.message}"
        routing.redirect '/images/new'
      end
    end
  end
end
