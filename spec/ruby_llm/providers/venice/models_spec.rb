# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Venice::Models do
  let(:slug) { 'venice' }
  let(:capabilities) { RubyLLM::Providers::Venice::Capabilities }

  describe '#models_url' do
    it 'returns models endpoint' do
      expect(described_class.models_url).to eq('models')
    end
  end

  describe '#parse_list_models_response' do
    context 'with text model' do
      let(:response) do
        double('Response', body: {
                 'data' => [{
                   'id' => 'llama-3.3-70b',
                   'type' => 'text',
                   'created' => 1_704_067_200,
                   'model_spec' => {
                     'name' => 'Llama 3.3 70B',
                     'availableContextTokens' => 128_000,
                     'capabilities' => {
                       'supportsFunctionCalling' => true,
                       'supportsWebSearch' => true
                     },
                     'pricing' => {
                       'input' => { 'usd' => 0.0000005 },
                       'output' => { 'usd' => 0.0000015 }
                     }
                   }
                 }]
               })
      end

      it 'parses text model correctly' do
        models = described_class.parse_list_models_response(response, slug, capabilities)

        expect(models.length).to eq(1)
        model = models.first

        expect(model.id).to eq('llama-3.3-70b')
        expect(model.name).to eq('Llama 3.3 70B')
        expect(model.provider).to eq(slug)
        expect(model.context_window).to eq(128_000)
        expect(model.modalities.input).to include('text', 'image')
        expect(model.modalities.output).to include('text')
        expect(model.capabilities).to include('function_calling', 'web_search')
        expect(model.pricing.text_tokens.standard.input_per_million).to eq(0.5)
        expect(model.pricing.text_tokens.standard.output_per_million).to eq(1.5)
      end
    end

    context 'with embedding model' do
      let(:response) do
        double('Response', body: {
                 'data' => [{
                   'id' => 'text-embedding-ada-002',
                   'type' => 'embedding',
                   'created' => 1_704_067_200,
                   'model_spec' => {
                     'name' => 'Text Embedding Ada 002',
                     'availableContextTokens' => 8191,
                     'capabilities' => {},
                     'pricing' => {
                       'input' => { 'usd' => 0.0000001 },
                       'output' => { 'usd' => 0.0 }
                     }
                   }
                 }]
               })
      end

      it 'parses embedding model correctly' do
        models = described_class.parse_list_models_response(response, slug, capabilities)

        expect(models.length).to eq(1)
        model = models.first

        expect(model.id).to eq('text-embedding-ada-002')
        expect(model.modalities.input).to include('text')
        expect(model.modalities.output).to include('embeddings')
        expect(model.pricing.text_tokens.standard.input_per_million).to be_within(0.01).of(0.1)
      end
    end

    context 'with image model' do
      let(:response) do
        double('Response', body: {
                 'data' => [{
                   'id' => 'dall-e-3',
                   'type' => 'image',
                   'created' => 1_704_067_200,
                   'model_spec' => {
                     'name' => 'DALL-E 3',
                     'availableContextTokens' => nil,
                     'capabilities' => {},
                     'pricing' => {
                       'input' => { 'usd' => 0.0 },
                       'output' => { 'usd' => 0.0 }
                     }
                   }
                 }]
               })
      end

      it 'parses image model correctly' do
        models = described_class.parse_list_models_response(response, slug, capabilities)

        expect(models.length).to eq(1)
        model = models.first

        expect(model.id).to eq('dall-e-3')
        expect(model.modalities.input).to include('text')
        expect(model.modalities.output).to include('image')
      end
    end

    context 'with multiple models' do
      let(:response) do
        double('Response', body: {
                 'data' => [
                   {
                     'id' => 'model-1',
                     'type' => 'text',
                     'created' => 1_704_067_200,
                     'model_spec' => {
                       'name' => 'Model 1',
                       'availableContextTokens' => 4096,
                       'capabilities' => {},
                       'pricing' => {
                         'input' => { 'usd' => 0.0000001 },
                         'output' => { 'usd' => 0.0000002 }
                       }
                     }
                   },
                   {
                     'id' => 'model-2',
                     'type' => 'text',
                     'created' => 1_704_067_300,
                     'model_spec' => {
                       'name' => 'Model 2',
                       'availableContextTokens' => 8192,
                       'capabilities' => {},
                       'pricing' => {
                         'input' => { 'usd' => 0.0000003 },
                         'output' => { 'usd' => 0.0000004 }
                       }
                     }
                   }
                 ]
               })
      end

      it 'parses all models' do
        models = described_class.parse_list_models_response(response, slug, capabilities)

        expect(models.length).to eq(2)
        expect(models.map(&:id)).to contain_exactly('model-1', 'model-2')
      end
    end

    context 'with model without capabilities' do
      let(:response) do
        double('Response', body: {
                 'data' => [{
                   'id' => 'basic-model',
                   'type' => 'text',
                   'created' => 1_704_067_200,
                   'model_spec' => {
                     'name' => 'Basic Model',
                     'availableContextTokens' => 4096,
                     'capabilities' => nil,
                     'pricing' => {
                       'input' => { 'usd' => 0.0000001 },
                       'output' => { 'usd' => 0.0000002 }
                     }
                   }
                 }]
               })
      end

      it 'returns empty capabilities array' do
        models = described_class.parse_list_models_response(response, slug, capabilities)

        expect(models.first.capabilities).to eq([])
      end
    end
  end

  describe '#supported_parameters_to_capabilities' do
    it 'converts function calling capability' do
      capabilities = { 'supportsFunctionCalling' => true }

      result = described_class.supported_parameters_to_capabilities(capabilities)

      expect(result).to include('function_calling')
    end

    it 'converts web search capability' do
      capabilities = { 'supportsWebSearch' => true }

      result = described_class.supported_parameters_to_capabilities(capabilities)

      expect(result).to include('web_search')
    end

    it 'converts multiple capabilities' do
      capabilities = {
        'supportsFunctionCalling' => true,
        'supportsWebSearch' => true
      }

      result = described_class.supported_parameters_to_capabilities(capabilities)

      expect(result).to contain_exactly('function_calling', 'web_search')
    end

    it 'ignores false capabilities' do
      capabilities = {
        'supportsFunctionCalling' => false,
        'supportsWebSearch' => true
      }

      result = described_class.supported_parameters_to_capabilities(capabilities)

      expect(result).to contain_exactly('web_search')
    end

    it 'returns empty array for nil capabilities' do
      result = described_class.supported_parameters_to_capabilities(nil)

      expect(result).to eq([])
    end

    it 'returns empty array for empty capabilities' do
      result = described_class.supported_parameters_to_capabilities({})

      expect(result).to eq([])
    end
  end
end