# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Venice::Embeddings do
  describe '#embedding_url' do
    it 'returns embeddings endpoint' do
      expect(described_class.embedding_url).to eq('embeddings')
    end
  end

  describe '#render_embedding_payload' do
    it 'creates payload with model and input' do
      payload = described_class.render_embedding_payload('test text', model: 'text-embedding-ada-002', dimensions: nil)

      expect(payload[:model]).to eq('text-embedding-ada-002')
      expect(payload[:input]).to eq('test text')
    end

    it 'includes dimensions when provided' do
      payload = described_class.render_embedding_payload(
        'test text',
        model: 'text-embedding-ada-002',
        dimensions: 768
      )

      expect(payload[:dimensions]).to eq(768)
    end

    it 'excludes dimensions when nil' do
      payload = described_class.render_embedding_payload('test text', model: 'text-embedding-ada-002', dimensions: nil)

      expect(payload).not_to have_key(:dimensions)
    end

    it 'handles array input' do
      texts = %w[text1 text2 text3]
      payload = described_class.render_embedding_payload(texts, model: 'text-embedding-ada-002', dimensions: nil)

      expect(payload[:input]).to eq(texts)
    end
  end

  describe '#parse_embedding_response' do
    it 'parses single embedding response' do
      response = double(
        'Response',
        body: {
          'data' => [
            { 'embedding' => [0.1, 0.2, 0.3] }
          ],
          'usage' => { 'prompt_tokens' => 5 }
        }
      )

      embedding = described_class.parse_embedding_response(
        response,
        model: 'text-embedding-ada-002',
        text: 'test'
      )

      expect(embedding).to be_a(RubyLLM::Embedding)
      expect(embedding.vectors).to eq([0.1, 0.2, 0.3])
      expect(embedding.model).to eq('text-embedding-ada-002')
      expect(embedding.input_tokens).to eq(5)
    end

    it 'parses multiple embedding response' do
      response = double(
        'Response',
        body: {
          'data' => [
            { 'embedding' => [0.1, 0.2] },
            { 'embedding' => [0.3, 0.4] },
            { 'embedding' => [0.5, 0.6] }
          ],
          'usage' => { 'prompt_tokens' => 15 }
        }
      )

      embedding = described_class.parse_embedding_response(
        response,
        model: 'text-embedding-ada-002',
        text: %w[text1 text2 text3]
      )

      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.length).to eq(3)
      expect(embedding.vectors[0]).to eq([0.1, 0.2])
      expect(embedding.vectors[1]).to eq([0.3, 0.4])
      expect(embedding.vectors[2]).to eq([0.5, 0.6])
      expect(embedding.input_tokens).to eq(15)
    end

    it 'defaults to 0 tokens when usage missing' do
      response = double(
        'Response',
        body: {
          'data' => [
            { 'embedding' => [0.1, 0.2, 0.3] }
          ]
        }
      )

      embedding = described_class.parse_embedding_response(
        response,
        model: 'text-embedding-ada-002',
        text: 'test'
      )

      expect(embedding.input_tokens).to eq(0)
    end

    it 'handles single-string arrays consistently' do
      response = double(
        'Response',
        body: {
          'data' => [
            { 'embedding' => [0.1, 0.2, 0.3] }
          ],
          'usage' => { 'prompt_tokens' => 5 }
        }
      )

      embedding = described_class.parse_embedding_response(
        response,
        model: 'text-embedding-ada-002',
        text: ['single text']
      )

      expect(embedding.vectors).to be_an(Array)
      expect(embedding.vectors.length).to eq(1)
      expect(embedding.vectors.first).to be_an(Array)
      expect(embedding.vectors.first).to eq([0.1, 0.2, 0.3])
    end
  end
end