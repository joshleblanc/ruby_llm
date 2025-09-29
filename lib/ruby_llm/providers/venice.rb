# frozen_string_literal: true

module RubyLLM
  module Providers
    # Venice API integration.
    class Venice < OpenAI
      include Venice::Chat
      include Venice::Embeddings
      include Venice::Images
      include Venice::Media
      include Venice::Models
      include Venice::Streaming
      include Venice::Tools

      def api_base
        'https://api.venice.ai/api/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.venice_api_key}"
        }.compact
      end

      def maybe_normalize_temperature(temperature, model)
        Venice::Capabilities.normalize_temperature(temperature, model.id)
      end

      class << self
        def capabilities
          Venice::Capabilities
        end

        def configuration_requirements
          %i[venice_api_key]
        end
      end

      def parse_error(response)
        return if response.body.empty?
  
        body = try_parse_json(response.body)
        case body
        when Hash
          body.dig('error')
        when Array
          body.map do |part|
            part.dig('error')
          end.join('. ')
        else
          body
        end
      end
    end
  end
end
