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
          data = response.body
          image_data = data['images'].first

          Image.new(
            url: image_data['url'],
            mime_type: determine_mime_type(image_data),
            revised_prompt: image_data['revised_prompt'],
            model_id: model,
            data: image_data
          )
        end

        def determine_mime_type(image_data)
          return 'image/png' unless image_data

          decoded = Base64.decode64(image_data[0..100])
          case decoded
          when /\A\x89PNG/n then 'image/png'
          when /\AJFIF|Exif/n then 'image/jpeg'
          when /\AGIF8/n then 'image/gif'
          when /\ARIFF.*WEBP/nm then 'image/webp'
          else 'image/png'
          end
        end
      end
    end
  end
end