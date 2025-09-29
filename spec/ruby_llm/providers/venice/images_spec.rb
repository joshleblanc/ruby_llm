# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Venice::Images do
  describe '#images_url' do
    it 'returns image/generations endpoint' do
      expect(described_class.images_url).to eq('image/generations')
    end
  end

  describe '#render_image_payload' do
    it 'creates basic payload with prompt and model' do
      payload = described_class.render_image_payload('a cat', model: 'dall-e-3', size: nil)

      expect(payload[:model]).to eq('dall-e-3')
      expect(payload[:prompt]).to eq('a cat')
      expect(payload[:n]).to eq(1)
    end

    it 'parses size parameter into width and height' do
      payload = described_class.render_image_payload('a cat', model: 'dall-e-3', size: '1024x768')

      expect(payload[:width]).to eq(1024)
      expect(payload[:height]).to eq(768)
    end

    it 'excludes width and height when size is nil' do
      payload = described_class.render_image_payload('a cat', model: 'dall-e-3', size: nil)

      expect(payload).not_to have_key(:width)
      expect(payload).not_to have_key(:height)
    end

    it 'includes negative_prompt when provided' do
      options = { negative_prompt: 'ugly, blurry' }
      payload = described_class.render_image_payload('a cat', model: 'dall-e-3', size: nil, **options)

      expect(payload[:negative_prompt]).to eq('ugly, blurry')
    end

    it 'includes style_preset when provided' do
      options = { style_preset: 'photographic' }
      payload = described_class.render_image_payload('a cat', model: 'dall-e-3', size: nil, **options)

      expect(payload[:style_preset]).to eq('photographic')
    end

    it 'includes safe_mode when provided' do
      options = { safe_mode: true }
      payload = described_class.render_image_payload('a cat', model: 'dall-e-3', size: nil, **options)

      expect(payload[:safe_mode]).to be true
    end

    it 'includes seed when provided' do
      options = { seed: 12345 }
      payload = described_class.render_image_payload('a cat', model: 'dall-e-3', size: nil, **options)

      expect(payload[:seed]).to eq(12345)
    end

    it 'merges venice_parameters when provided' do
      options = { venice_parameters: { custom_param: 'value' } }
      payload = described_class.render_image_payload('a cat', model: 'dall-e-3', size: nil, **options)

      expect(payload[:custom_param]).to eq('value')
    end

    it 'combines multiple optional parameters' do
      options = {
        negative_prompt: 'ugly',
        style_preset: 'anime',
        safe_mode: false,
        seed: 999,
        venice_parameters: { extra: 'data' }
      }
      payload = described_class.render_image_payload('a cat', model: 'dall-e-3', size: '512x512', **options)

      expect(payload[:width]).to eq(512)
      expect(payload[:height]).to eq(512)
      expect(payload[:negative_prompt]).to eq('ugly')
      expect(payload[:style_preset]).to eq('anime')
      expect(payload[:safe_mode]).to be false
      expect(payload[:seed]).to eq(999)
      expect(payload[:extra]).to eq('data')
    end
  end

  describe '#parse_image_response' do
    it 'parses response with URL' do
      response = double(
        'Response',
        body: {
          'data' => [{
            'url' => 'https://example.com/image.png',
            'revised_prompt' => 'A beautiful cat',
            'b64_json' => nil
          }]
        }
      )

      image = described_class.parse_image_response(response, model: 'dall-e-3')

      expect(image).to be_a(RubyLLM::Image)
      expect(image.url).to eq('https://example.com/image.png')
      expect(image.revised_prompt).to eq('A beautiful cat')
      expect(image.model_id).to eq('dall-e-3')
      expect(image.data).to be_nil
    end

    it 'parses response with base64 data' do
      base64_data = Base64.encode64('fake_image_data')
      response = double(
        'Response',
        body: {
          'data' => [{
            'url' => nil,
            'revised_prompt' => 'A cat',
            'b64_json' => base64_data
          }]
        }
      )

      image = described_class.parse_image_response(response, model: 'dall-e-3')

      expect(image.data).to eq(base64_data)
    end
  end

  describe '#determine_mime_type' do
    it 'detects PNG format' do
      image_data = { 'b64_json' => Base64.encode64("\x89PNG\r\n\x1a\n" + ('x' * 100)) }
      mime_type = described_class.determine_mime_type(image_data)

      expect(mime_type).to eq('image/png')
    end

    it 'detects JPEG format from JFIF marker' do
      image_data = { 'b64_json' => Base64.encode64('JFIFxxxxx' + ('x' * 100)) }
      mime_type = described_class.determine_mime_type(image_data)

      expect(mime_type).to eq('image/jpeg')
    end

    it 'detects JPEG format from Exif marker' do
      image_data = { 'b64_json' => Base64.encode64('Exifxxxxx' + ('x' * 100)) }
      mime_type = described_class.determine_mime_type(image_data)

      expect(mime_type).to eq('image/jpeg')
    end

    it 'detects GIF format' do
      image_data = { 'b64_json' => Base64.encode64('GIF89axxxx' + ('x' * 100)) }
      mime_type = described_class.determine_mime_type(image_data)

      expect(mime_type).to eq('image/gif')
    end

    it 'detects WebP format' do
      image_data = { 'b64_json' => Base64.encode64('RIFFxxxxWEBP' + ('x' * 100)) }
      mime_type = described_class.determine_mime_type(image_data)

      expect(mime_type).to eq('image/webp')
    end

    it 'defaults to PNG when b64_json is missing' do
      image_data = {}
      mime_type = described_class.determine_mime_type(image_data)

      expect(mime_type).to eq('image/png')
    end

    it 'defaults to PNG for unknown formats' do
      image_data = { 'b64_json' => Base64.encode64('unknown_format' + ('x' * 100)) }
      mime_type = described_class.determine_mime_type(image_data)

      expect(mime_type).to eq('image/png')
    end
  end
end