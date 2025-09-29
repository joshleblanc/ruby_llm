# frozen_string_literal: true

module RubyLLM
  module Providers
    class Venice
      module Capabilities
        module_function

        def supports_vision?(model_id)
          true
        end

        def supports_functions?(model_id)
          true
        end

        def supports_structured_output?(model_id)
          true
        end

        def supports_json_mode?(model_id)
          supports_structured_output?(model_id)
        end

        def supports_web_search?(model_id)
          true
        end

        def normalize_temperature(temperature, _model_id)
          temperature
        end

        def context_window_for(model_id)
          nil
        end

        def max_tokens_for(model_id)
          nil
        end

        def input_price_for(model_id)
          0.0
        end

        def cached_input_price_for(model_id)
          nil
        end

        def output_price_for(model_id)
          0.0
        end

        def model_type(model_id)
          'chat'
        end

        def default_input_price
          0.0
        end

        def default_output_price
          0.0
        end

        def format_display_name(model_id)
          model_id.split('/').last
                  .split('-')
                  .map(&:capitalize)
                  .join(' ')
        end

        def modalities_for(model_id)
          {
            input: ['text', 'image'],
            output: ['text']
          }
        end

        def capabilities_for(model_id)
          [
            'streaming',
            'function_calling',
            'structured_output',
            'web_search',
            'vision'
          ]
        end

        def pricing_for(model_id)
          {
            text_tokens: {
              standard: {
                input_per_million: input_price_for(model_id),
                output_per_million: output_price_for(model_id)
              }
            }
          }
        end
      end
    end
  end
end