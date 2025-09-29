# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Venice::Streaming do
  describe '#stream_url' do
    it 'returns chat/completions endpoint' do
      expect(described_class.stream_url).to eq('chat/completions')
    end
  end

  describe '#build_chunk' do
    it 'builds chunk with content' do
      data = {
        'model' => 'llama-3.3-70b',
        'choices' => [{
          'delta' => {
            'content' => 'Hello'
          }
        }]
      }

      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      chunk = described_class.build_chunk(data)

      expect(chunk).to be_a(RubyLLM::Chunk)
      expect(chunk.role).to eq(:assistant)
      expect(chunk.model_id).to eq('llama-3.3-70b')
      expect(chunk.content).to eq('Hello')
    end

    it 'builds chunk with token usage' do
      data = {
        'model' => 'llama-3.3-70b',
        'choices' => [{ 'delta' => {} }],
        'usage' => {
          'prompt_tokens' => 10,
          'completion_tokens' => 5
        }
      }

      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      chunk = described_class.build_chunk(data)

      expect(chunk.input_tokens).to eq(10)
      expect(chunk.output_tokens).to eq(5)
    end

    it 'builds chunk with tool calls' do
      data = {
        'model' => 'llama-3.3-70b',
        'choices' => [{
          'delta' => {
            'tool_calls' => [{ 'id' => '123', 'function' => { 'name' => 'test', 'arguments' => '{}' } }]
          }
        }]
      }

      chunk = described_class.build_chunk(data)

      expect(chunk.tool_calls).to be_a(Hash)
      expect(chunk.tool_calls['123']).to be_a(RubyLLM::ToolCall)
      expect(chunk.tool_calls['123'].id).to eq('123')
      expect(chunk.tool_calls['123'].name).to eq('test')
    end

    it 'handles empty delta' do
      data = {
        'model' => 'llama-3.3-70b',
        'choices' => [{ 'delta' => {} }]
      }

      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      chunk = described_class.build_chunk(data)

      expect(chunk.content).to be_nil
      expect(chunk.tool_calls).to be_nil
    end

    it 'handles missing usage data' do
      data = {
        'model' => 'llama-3.3-70b',
        'choices' => [{ 'delta' => { 'content' => 'test' } }]
      }

      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      chunk = described_class.build_chunk(data)

      expect(chunk.input_tokens).to be_nil
      expect(chunk.output_tokens).to be_nil
    end
  end

  describe '#parse_streaming_error' do
    it 'parses server error' do
      data = JSON.generate({
                             'error' => {
                               'type' => 'server_error',
                               'message' => 'Internal server error'
                             }
                           })

      status, message = described_class.parse_streaming_error(data)

      expect(status).to eq(500)
      expect(message).to eq('Internal server error')
    end

    it 'parses rate limit error' do
      data = JSON.generate({
                             'error' => {
                               'type' => 'rate_limit_exceeded',
                               'message' => 'Too many requests'
                             }
                           })

      status, message = described_class.parse_streaming_error(data)

      expect(status).to eq(429)
      expect(message).to eq('Too many requests')
    end

    it 'parses insufficient quota error' do
      data = JSON.generate({
                             'error' => {
                               'type' => 'insufficient_quota',
                               'message' => 'Quota exceeded'
                             }
                           })

      status, message = described_class.parse_streaming_error(data)

      expect(status).to eq(429)
      expect(message).to eq('Quota exceeded')
    end

    it 'parses authentication error' do
      data = JSON.generate({
                             'error' => {
                               'type' => 'authentication_error',
                               'message' => 'Invalid API key'
                             }
                           })

      status, message = described_class.parse_streaming_error(data)

      expect(status).to eq(401)
      expect(message).to eq('Invalid API key')
    end

    it 'parses invalid_api_key error' do
      data = JSON.generate({
                             'error' => {
                               'type' => 'invalid_api_key',
                               'message' => 'API key is invalid'
                             }
                           })

      status, message = described_class.parse_streaming_error(data)

      expect(status).to eq(401)
      expect(message).to eq('API key is invalid')
    end

    it 'defaults unknown errors to 400' do
      data = JSON.generate({
                             'error' => {
                               'type' => 'unknown_error',
                               'message' => 'Something went wrong'
                             }
                           })

      status, message = described_class.parse_streaming_error(data)

      expect(status).to eq(400)
      expect(message).to eq('Something went wrong')
    end

    it 'returns nil for non-error data' do
      data = JSON.generate({ 'choices' => [{ 'delta' => { 'content' => 'test' } }] })

      result = described_class.parse_streaming_error(data)

      expect(result).to be_nil
    end

    it 'handles malformed JSON' do
      data = 'not valid json'

      expect do
        described_class.parse_streaming_error(data)
      end.to raise_error(JSON::ParserError)
    end
  end
end