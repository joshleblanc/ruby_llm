# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Venice::Chat do
  include_context 'with configured RubyLLM'

  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(described_class)
    end
  end

  describe '#render_payload' do
    let(:messages) { [RubyLLM::Message.new(role: :user, content: 'Hello')] }
    let(:model) { double('Model', id: 'llama-3.3-70b') }
    let(:tools) { {} }
    let(:temperature) { 0.7 }

    it 'creates basic payload without optional parameters' do
      payload = described_class.render_payload(messages, tools: tools, temperature: temperature, model: model)

      expect(payload[:model]).to eq('llama-3.3-70b')
      expect(payload[:stream]).to be false
      expect(payload[:temperature]).to eq(0.7)
      expect(payload[:messages]).to be_an(Array)
    end

    it 'includes stream options when streaming' do
      payload = described_class.render_payload(
        messages,
        tools: tools,
        temperature: temperature,
        model: model,
        stream: true
      )

      expect(payload[:stream]).to be true
      expect(payload[:stream_options]).to eq({ include_usage: true })
    end

    it 'excludes temperature when nil' do
      payload = described_class.render_payload(messages, tools: tools, temperature: nil, model: model)

      expect(payload).not_to have_key(:temperature)
    end

    it 'includes venice_parameters when provided' do
      options = { venice_parameters: { include_venice_system_prompt: false } }
      payload = described_class.render_payload(
        messages,
        tools: tools,
        temperature: temperature,
        model: model,
        **options
      )

      expect(payload[:venice_parameters]).to eq({ include_venice_system_prompt: false })
    end

    it 'enables web_search via venice_parameters' do
      options = { web_search: true }
      payload = described_class.render_payload(
        messages,
        tools: tools,
        temperature: temperature,
        model: model,
        **options
      )

      expect(payload[:venice_parameters][:web_search]).to be true
    end

    it 'includes tools when provided' do
      tool = double('Tool', name: 'test_tool', description: 'Test', parameters: {})
      tools = { 'test_tool' => tool }

      allow(described_class).to receive(:tool_for).and_return({ type: 'function', function: {} })

      payload = described_class.render_payload(
        messages,
        tools: tools,
        temperature: temperature,
        model: model
      )

      expect(payload[:tools]).to be_an(Array)
      expect(payload[:tools].length).to eq(1)
    end

    it 'includes response_format when schema provided' do
      schema = {
        type: 'object',
        properties: {
          answer: { type: 'string' }
        }
      }

      payload = described_class.render_payload(
        messages,
        tools: tools,
        temperature: temperature,
        model: model,
        schema: schema
      )

      expect(payload[:response_format]).to be_a(Hash)
      expect(payload[:response_format][:type]).to eq('json_schema')
      expect(payload[:response_format][:json_schema][:strict]).to be true
    end

    it 'respects strict: false in schema' do
      schema = {
        type: 'object',
        properties: { answer: { type: 'string' } },
        strict: false
      }

      payload = described_class.render_payload(
        messages,
        tools: tools,
        temperature: temperature,
        model: model,
        schema: schema
      )

      expect(payload[:response_format][:json_schema][:strict]).to be false
    end
  end

  describe '#parse_completion_response' do
    it 'parses successful response' do
      response = double(
        'Response',
        body: {
          'choices' => [{
            'message' => {
              'content' => 'Hello world',
              'tool_calls' => nil
            }
          }],
          'usage' => {
            'prompt_tokens' => 10,
            'completion_tokens' => 5
          },
          'model' => 'llama-3.3-70b'
        }
      )

      allow(described_class).to receive(:parse_tool_calls).and_return(nil)

      message = described_class.parse_completion_response(response)

      expect(message).to be_a(RubyLLM::Message)
      expect(message.role).to eq(:assistant)
      expect(message.content).to eq('Hello world')
      expect(message.input_tokens).to eq(10)
      expect(message.output_tokens).to eq(5)
      expect(message.model_id).to eq('llama-3.3-70b')
    end

    it 'returns nil for empty response' do
      response = double('Response', body: {})

      message = described_class.parse_completion_response(response)

      expect(message).to be_nil
    end

    it 'raises error when response contains error' do
      response = double(
        'Response',
        body: {
          'error' => {
            'message' => 'API key invalid'
          }
        }
      )

      expect do
        described_class.parse_completion_response(response)
      end.to raise_error(RubyLLM::Error, 'API key invalid')
    end

    it 'returns nil when message data is missing' do
      response = double(
        'Response',
        body: {
          'choices' => [],
          'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 5 }
        }
      )

      message = described_class.parse_completion_response(response)

      expect(message).to be_nil
    end

    it 'includes tool calls when present' do
      response = double(
        'Response',
        body: {
          'choices' => [{
            'message' => {
              'content' => nil,
              'tool_calls' => [{ 'id' => '123', 'function' => { 'name' => 'test', 'arguments' => '{}' } }]
            }
          }],
          'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 5 },
          'model' => 'llama-3.3-70b'
        }
      )

      message = described_class.parse_completion_response(response)

      expect(message.tool_calls).to be_a(Hash)
      expect(message.tool_calls['123']).to be_a(RubyLLM::ToolCall)
      expect(message.tool_calls['123'].id).to eq('123')
      expect(message.tool_calls['123'].name).to eq('test')
    end
  end

  describe '#format_messages' do
    it 'formats simple text message' do
      messages = [RubyLLM::Message.new(role: :user, content: 'Hello')]

      allow(described_class).to receive_message_chain('Media.format_content').and_return('Hello')
      allow(described_class).to receive(:format_tool_calls).and_return(nil)

      formatted = described_class.format_messages(messages)

      expect(formatted).to be_an(Array)
      expect(formatted.length).to eq(1)
      expect(formatted.first[:role]).to eq('user')
      expect(formatted.first[:content]).to eq('Hello')
    end

    it 'includes tool_calls when present' do
      tool_call = RubyLLM::ToolCall.new(id: '123', name: 'test', arguments: {})
      messages = [RubyLLM::Message.new(role: :assistant, content: nil, tool_calls: { '123' => tool_call })]

      formatted = described_class.format_messages(messages)

      expect(formatted.first[:tool_calls]).to be_an(Array)
      expect(formatted.first[:tool_calls].first[:id]).to eq('123')
      expect(formatted.first[:tool_calls].first[:type]).to eq('function')
      expect(formatted.first[:tool_calls].first[:function][:name]).to eq('test')
    end

    it 'includes tool_call_id for tool responses' do
      messages = [RubyLLM::Message.new(role: :tool, content: 'Result', tool_call_id: '123')]

      allow(described_class).to receive_message_chain('Media.format_content').and_return('Result')
      allow(described_class).to receive(:format_tool_calls).and_return(nil)

      formatted = described_class.format_messages(messages)

      expect(formatted.first[:tool_call_id]).to eq('123')
    end

    it 'preserves all role types' do
      messages = [
        RubyLLM::Message.new(role: :system, content: 'System'),
        RubyLLM::Message.new(role: :user, content: 'User'),
        RubyLLM::Message.new(role: :assistant, content: 'Assistant')
      ]

      allow(described_class).to receive_message_chain('Media.format_content') { |content| content.content }
      allow(described_class).to receive(:format_tool_calls).and_return(nil)

      formatted = described_class.format_messages(messages)

      expect(formatted[0][:role]).to eq('system')
      expect(formatted[1][:role]).to eq('user')
      expect(formatted[2][:role]).to eq('assistant')
    end
  end

  describe '#completion_url' do
    it 'returns chat/completions endpoint' do
      expect(test_obj.completion_url).to eq('chat/completions')
    end
  end
end