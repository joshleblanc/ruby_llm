# frozen_string_literal: true

module RubyLLM
  module Providers
    class Venice
      # Models methods of the Venice API integration
      module Models
        MODEL_TYPES = %w[text image embedding].freeze

        def list_models
          all_models = []

          MODEL_TYPES.each do |model_type|
            response = @connection.get(models_url) do |req|
              req.params = { type: model_type }
            end

            models = parse_list_models_response(response, slug, capabilities)
            all_models.concat(models)
          rescue StandardError => e
            RubyLLM.logger.warn "Failed to fetch #{model_type} models from Venice: #{e.message}"
          end

          all_models
        end

        module_function

        def models_url
          "models"
        end

        def parse_list_models_response(response, slug, _capabilities)
          Array(response.body["data"]).map do |model_data|
            model_spec = model_data["model_spec"]
            capabilities = model_spec["capabilities"]
            pricing = model_spec["pricing"]
            modalities = {}
            pricing_info = {}

            case model_data["type"]
            when "image"
              modalities = { input: ["text"], output: ["image"] }
              # Pricing for images is not documented, so we leave it empty
            when "embedding"
              modalities = { input: ["text"], output: ["embeddings"] }
              pricing_info = {
                text_tokens: {
                  standard: {
                    input_per_million: pricing["input"]["usd"].to_f * 1_000_000
                  }
                }
              }
            else # text
              modalities = { input: ["text", "image"], output: ["text"] }
              pricing_info = {
                text_tokens: {
                  standard: {
                    input_per_million: pricing["input"]["usd"].to_f * 1_000_000,
                    output_per_million: pricing["output"]["usd"].to_f * 1_000_000
                  }
                }
              }
            end

            Model::Info.new(
              id: model_data["id"],
              name: model_spec["name"],
              provider: slug,
              created_at: Time.at(model_data["created"]),
              context_window: model_spec["availableContextTokens"],
              capabilities: supported_parameters_to_capabilities(capabilities),
              modalities: modalities,
              pricing: pricing_info,
              metadata: model_data
            )
          end
        end

        def supported_parameters_to_capabilities(capabilities)
          return [] unless capabilities

          caps = []
          caps << "function_calling" if capabilities["supportsFunctionCalling"]
          caps << "web_search" if capabilities["supportsWebSearch"]
          caps
        end
      end
    end
  end
end
