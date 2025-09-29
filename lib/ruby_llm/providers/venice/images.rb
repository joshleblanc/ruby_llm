# frozen_string_literal: true

module RubyLLM
  module Providers
    class Venice
      module Images
        module_function

        def images_url
          'image/generate'
        end

        def render_image_payload(prompt, model:, size:, **options)
          payload = {
            model: model,
            prompt: prompt,
          }

          if size
            width, height = size.split('x').map(&:to_i)
            payload[:width] = width
            payload[:height] = height
          end

          payload[:negative_prompt] = options[:negative_prompt] if options[:negative_prompt]
          payload[:style_preset] = options[:style_preset] if options[:style_preset]
          payload[:safe_mode] = options[:safe_mode] if options.key?(:safe_mode)
          payload[:seed] = options[:seed] if options[:seed]

          venice_params = options[:venice_parameters] || {}
          payload.merge!(venice_params) if venice_params.any?

          payload
        end

        def parse_image_response(response, model:)
          body = response.body
          # Venice API returns images array where each element is a base64 string
          b64_data = body['images'].first

          mime_type = determine_mime_type_from_base64(b64_data)

          Image.new(
            url: nil,
            data: b64_data,
            mime_type: mime_type,
            revised_prompt: nil,
            model_id: model
          )
        end

        def determine_mime_type_from_base64(base64_string)
          return 'image/png' unless base64_string

          decoded = Base64.decode64(base64_string[0..100])
          case decoded
          when /\A\x89PNG/n then 'image/png'
          when /\AJFIF|Exif/n then 'image/jpeg'
          when /\AGIF8/n then 'image/gif'
          when /\ARIFF.*WEBP/nm then 'image/webp'
          else 'image/png'
          end        end
      end
    end
  end
end