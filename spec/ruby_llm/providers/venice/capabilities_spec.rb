# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Venice::Capabilities do
  describe '.normalize_temperature' do
    it 'preserves temperature for all models' do
      models = %w[llama-3.3-70b gpt-4o-mini mistral-large-latest]

      models.each do |model|
        result = described_class.normalize_temperature(0.7, model)
        expect(result).to eq(0.7)
      end
    end

    it 'handles nil temperature' do
      result = described_class.normalize_temperature(nil, 'any-model')
      expect(result).to be_nil
    end

    it 'handles zero temperature' do
      result = described_class.normalize_temperature(0.0, 'any-model')
      expect(result).to eq(0.0)
    end

    it 'handles maximum temperature' do
      result = described_class.normalize_temperature(2.0, 'any-model')
      expect(result).to eq(2.0)
    end
  end

  describe '.supports_vision?' do
    it 'returns true for all models' do
      expect(described_class.supports_vision?('llama-3.3-70b')).to be true
      expect(described_class.supports_vision?('gpt-4o-mini')).to be true
      expect(described_class.supports_vision?('mistral-large-latest')).to be true
    end
  end

  describe '.supports_functions?' do
    it 'returns true for all models' do
      expect(described_class.supports_functions?('llama-3.3-70b')).to be true
      expect(described_class.supports_functions?('gpt-4o-mini')).to be true
      expect(described_class.supports_functions?('mistral-large-latest')).to be true
    end
  end

  describe '.supports_structured_output?' do
    it 'returns true for all models' do
      expect(described_class.supports_structured_output?('llama-3.3-70b')).to be true
      expect(described_class.supports_structured_output?('gpt-4o-mini')).to be true
      expect(described_class.supports_structured_output?('mistral-large-latest')).to be true
    end
  end

  describe '.supports_json_mode?' do
    it 'returns true for all models' do
      expect(described_class.supports_json_mode?('llama-3.3-70b')).to be true
      expect(described_class.supports_json_mode?('gpt-4o-mini')).to be true
      expect(described_class.supports_json_mode?('mistral-large-latest')).to be true
    end
  end

  describe '.supports_web_search?' do
    it 'returns true for all models' do
      expect(described_class.supports_web_search?('llama-3.3-70b')).to be true
      expect(described_class.supports_web_search?('gpt-4o-mini')).to be true
      expect(described_class.supports_web_search?('mistral-large-latest')).to be true
    end
  end

  describe '.format_display_name' do
    it 'formats simple model names' do
      expect(described_class.format_display_name('llama-3.3-70b')).to eq('Llama 3.3 70b')
    end

    it 'formats namespaced model names' do
      expect(described_class.format_display_name('openai/gpt-4o-mini')).to eq('Gpt 4o Mini')
    end

    it 'handles single word model names' do
      expect(described_class.format_display_name('mistral')).to eq('Mistral')
    end
  end

  describe '.modalities_for' do
    it 'returns text and image input with text output' do
      result = described_class.modalities_for('any-model')

      expect(result[:input]).to include('text', 'image')
      expect(result[:output]).to include('text')
    end
  end

  describe '.capabilities_for' do
    it 'returns comprehensive capability list' do
      result = described_class.capabilities_for('any-model')

      expect(result).to include('streaming')
      expect(result).to include('function_calling')
      expect(result).to include('structured_output')
      expect(result).to include('web_search')
      expect(result).to include('vision')
    end
  end

  describe '.pricing_for' do
    it 'returns zero pricing structure' do
      result = described_class.pricing_for('any-model')

      expect(result[:text_tokens][:standard][:input_per_million]).to eq(0.0)
      expect(result[:text_tokens][:standard][:output_per_million]).to eq(0.0)
    end
  end

  describe '.input_price_for' do
    it 'returns 0.0' do
      expect(described_class.input_price_for('any-model')).to eq(0.0)
    end
  end

  describe '.output_price_for' do
    it 'returns 0.0' do
      expect(described_class.output_price_for('any-model')).to eq(0.0)
    end
  end

  describe '.cached_input_price_for' do
    it 'returns nil' do
      expect(described_class.cached_input_price_for('any-model')).to be_nil
    end
  end

  describe '.context_window_for' do
    it 'returns nil' do
      expect(described_class.context_window_for('any-model')).to be_nil
    end
  end

  describe '.max_tokens_for' do
    it 'returns nil' do
      expect(described_class.max_tokens_for('any-model')).to be_nil
    end
  end

  describe '.model_type' do
    it 'returns chat for all models' do
      expect(described_class.model_type('any-model')).to eq('chat')
    end
  end
end