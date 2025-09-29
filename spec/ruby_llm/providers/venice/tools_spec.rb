# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Venice::Tools do
  describe '#tool_for' do
    it 'converts tool to OpenAI format' do
      tool = double('Tool',
                    name: 'get_weather',
                    description: 'Get weather for location',
                    parameters: {
                      'location' => double('Param', type: 'string', description: 'City name', required: true),
                      'units' => double('Param', type: 'string', description: 'Temperature units', required: false)
                    })

      result = described_class.tool_for(tool)

      expect(result[:type]).to eq('function')
      expect(result[:function][:name]).to eq('get_weather')
      expect(result[:function][:description]).to eq('Get weather for location')
      expect(result[:function][:parameters][:type]).to eq('object')
      expect(result[:function][:parameters][:properties]).to be_a(Hash)
      expect(result[:function][:parameters][:required]).to eq(['location'])
    end

    it 'handles tools with no required parameters' do
      tool = double('Tool',
                    name: 'roll_dice',
                    description: 'Roll a die',
                    parameters: {
                      'sides' => double('Param', type: 'integer', description: 'Number of sides', required: false)
                    })

      result = described_class.tool_for(tool)

      expect(result[:function][:parameters][:required]).to eq([])
    end

    it 'handles tools with no parameters' do
      tool = double('Tool',
                    name: 'get_time',
                    description: 'Get current time',
                    parameters: {})

      result = described_class.tool_for(tool)

      expect(result[:function][:parameters][:properties]).to eq({})
      expect(result[:function][:parameters][:required]).to eq([])
    end
  end

  describe '#param_schema' do
    it 'converts parameter to schema' do
      param = double('Param', type: 'string', description: 'A string parameter')

      result = described_class.param_schema(param)

      expect(result[:type]).to eq('string')
      expect(result[:description]).to eq('A string parameter')
    end

    it 'excludes nil description' do
      param = double('Param', type: 'integer', description: nil)

      result = described_class.param_schema(param)

      expect(result[:type]).to eq('integer')
      expect(result).not_to have_key(:description)
    end
  end

  describe '#format_tool_calls' do
    it 'formats tool calls to OpenAI format' do
      tool_calls = {
        'call_123' => double('ToolCall', id: 'call_123', name: 'get_weather', arguments: { 'location' => 'Paris' }),
        'call_456' => double('ToolCall', id: 'call_456', name: 'roll_dice', arguments: {})
      }

      result = described_class.format_tool_calls(tool_calls)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)

      expect(result[0][:id]).to eq('call_123')
      expect(result[0][:type]).to eq('function')
      expect(result[0][:function][:name]).to eq('get_weather')
      expect(result[0][:function][:arguments]).to eq('{"location":"Paris"}')

      expect(result[1][:id]).to eq('call_456')
      expect(result[1][:function][:name]).to eq('roll_dice')
      expect(result[1][:function][:arguments]).to eq('{}')
    end

    it 'returns nil for nil tool_calls' do
      result = described_class.format_tool_calls(nil)

      expect(result).to be_nil
    end

    it 'returns nil for empty tool_calls' do
      result = described_class.format_tool_calls({})

      expect(result).to be_nil
    end
  end

  describe '#parse_tool_call_arguments' do
    it 'parses JSON arguments' do
      tool_call = {
        'function' => {
          'arguments' => '{"location":"Paris","units":"celsius"}'
        }
      }

      result = described_class.parse_tool_call_arguments(tool_call)

      expect(result).to eq({ 'location' => 'Paris', 'units' => 'celsius' })
    end

    it 'returns empty hash for nil arguments' do
      tool_call = {
        'function' => {
          'arguments' => nil
        }
      }

      result = described_class.parse_tool_call_arguments(tool_call)

      expect(result).to eq({})
    end

    it 'returns empty hash for empty arguments' do
      tool_call = {
        'function' => {
          'arguments' => ''
        }
      }

      result = described_class.parse_tool_call_arguments(tool_call)

      expect(result).to eq({})
    end

    it 'handles empty JSON object' do
      tool_call = {
        'function' => {
          'arguments' => '{}'
        }
      }

      result = described_class.parse_tool_call_arguments(tool_call)

      expect(result).to eq({})
    end
  end

  describe '#parse_tool_calls' do
    it 'parses tool calls with parsed arguments' do
      tool_calls = [
        {
          'id' => 'call_123',
          'function' => {
            'name' => 'get_weather',
            'arguments' => '{"location":"Paris"}'
          }
        }
      ]

      result = described_class.parse_tool_calls(tool_calls, parse_arguments: true)

      expect(result).to be_a(Hash)
      expect(result['call_123']).to be_a(RubyLLM::ToolCall)
      expect(result['call_123'].id).to eq('call_123')
      expect(result['call_123'].name).to eq('get_weather')
      expect(result['call_123'].arguments).to eq({ 'location' => 'Paris' })
    end

    it 'parses tool calls without parsing arguments' do
      tool_calls = [
        {
          'id' => 'call_123',
          'function' => {
            'name' => 'get_weather',
            'arguments' => '{"location":"Paris"}'
          }
        }
      ]

      result = described_class.parse_tool_calls(tool_calls, parse_arguments: false)

      expect(result['call_123'].arguments).to eq('{"location":"Paris"}')
    end

    it 'parses multiple tool calls' do
      tool_calls = [
        { 'id' => 'call_1', 'function' => { 'name' => 'tool1', 'arguments' => '{}' } },
        { 'id' => 'call_2', 'function' => { 'name' => 'tool2', 'arguments' => '{}' } },
        { 'id' => 'call_3', 'function' => { 'name' => 'tool3', 'arguments' => '{}' } }
      ]

      result = described_class.parse_tool_calls(tool_calls)

      expect(result.keys).to contain_exactly('call_1', 'call_2', 'call_3')
    end

    it 'returns nil for nil tool_calls' do
      result = described_class.parse_tool_calls(nil)

      expect(result).to be_nil
    end

    it 'returns nil for empty tool_calls' do
      result = described_class.parse_tool_calls([])

      expect(result).to be_nil
    end
  end
end