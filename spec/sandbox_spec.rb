# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'sandbox mode' do
  describe 'default behavior (sandbox enabled)' do
    it 'env returns an empty object' do
      result = JQ.filter('null', 'env')
      expect(JSON.parse(result)).to eq({})
    end

    it '$ENV returns an empty object' do
      result = JQ.filter('null', '$ENV')
      expect(JSON.parse(result)).to eq({})
    end

    it 'env.PATH returns null' do
      result = JQ.filter('null', 'env.PATH')
      expect(result).to eq("null")
    end

    it '$ENV.HOME returns null' do
      result = JQ.filter('null', '$ENV.HOME')
      expect(result).to eq("null")
    end

    it 'normal filters still work' do
      expect(JQ.filter('{"a":1}', '.a')).to eq("1")
      expect(JQ.filter('[1,2,3]', 'map(. * 2)')).to eq("[2,4,6]")
      expect(JQ.filter('{"name":"Alice"}', '.name', raw_output: true)).to eq("Alice")
    end
  end

  describe 'explicit sandbox: false' do
    around do |example|
      ENV["JQ_RUBY_TEST_VAR"] = "test_value_123"
      example.run
    ensure
      ENV.delete("JQ_RUBY_TEST_VAR")
    end

    it 'env returns real environment variables' do
      result = JQ.filter('null', 'env', sandbox: false)
      parsed = JSON.parse(result)
      expect(parsed).to be_a(Hash)
      expect(parsed).to include("JQ_RUBY_TEST_VAR" => "test_value_123")
    end

    it '$ENV returns real environment variables' do
      result = JQ.filter('null', '$ENV', sandbox: false)
      parsed = JSON.parse(result)
      expect(parsed).to be_a(Hash)
      expect(parsed).to include("JQ_RUBY_TEST_VAR" => "test_value_123")
    end

    it 'accesses a specific environment variable via env' do
      result = JQ.filter('null', 'env.JQ_RUBY_TEST_VAR', raw_output: true, sandbox: false)
      expect(result).to eq("test_value_123")
    end

    it 'accesses a specific environment variable via $ENV' do
      result = JQ.filter('null', '$ENV.JQ_RUBY_TEST_VAR', raw_output: true, sandbox: false)
      expect(result).to eq("test_value_123")
    end

    it 'returns null for an unset variable via $ENV' do
      result = JQ.filter('null', '$ENV.JQ_RUBY_NONEXISTENT_VAR_12345', sandbox: false)
      expect(result).to eq("null")
    end
  end

  describe 'include/import blocked' do
    it 'raises JQ::Error when using include' do
      expect {
        JQ.filter('null', 'include "foo"; .')
      }.to raise_error(JQ::Error)
    end

    it 'raises JQ::Error when using import' do
      expect {
        JQ.filter('null', 'import "foo" as f; .')
      }.to raise_error(JQ::Error)
    end
  end

  describe 'input/inputs' do
    it 'input returns an error (no input callback configured)' do
      result = JQ.filter('null', 'try input catch "no input"', raw_output: true)
      expect(result).to eq("no input")
    end

    it 'inputs returns empty (no input callback configured)' do
      result = JQ.filter('null', '[inputs]')
      expect(result).to eq("[]")
    end
  end

  describe 'debug/stderr' do
    it 'debug passes through the input value' do
      expect(JQ.filter('{"a":1}', '. | debug | .a')).to eq("1")
    end

    it 'stderr passes through the input value' do
      expect(JQ.filter('{"a":1}', '. | stderr | .a')).to eq("1")
    end
  end

  describe 'validate_filter!' do
    it 'works for normal filters under sandbox' do
      expect(JQ.validate_filter!('.name')).to eq(true)
      expect(JQ.validate_filter!('.[] | select(.age > 18)')).to eq(true)
    end
  end
end
