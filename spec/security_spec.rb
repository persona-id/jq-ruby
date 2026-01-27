# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Security' do
  describe 'large inputs' do
    it 'handles large JSON strings safely' do
      # Create a 1MB string
      large_value = 'x' * 1_000_000
      json = "{\"data\":\"#{large_value}\"}"

      expect {
        result = JQ.filter(json, '.data', raw_output: true)
        expect(result).to eq(large_value)
      }.not_to raise_error
    end

    it 'handles arrays with many elements' do
      # Array with 10,000 elements
      array = (1..10_000).to_a.to_json

      expect {
        result = JQ.filter(array, 'length')
        expect(result).to eq('10000')
      }.not_to raise_error
    end

    it 'handles large numbers' do
      json = '{"num":999999999999999999}'
      expect {
        JQ.filter(json, '.num')
      }.not_to raise_error
    end
  end

  describe 'deeply nested structures' do
    it 'handles moderately nested objects' do
      # Create nested structure: {"a":{"a":{"a":...}}} 50 levels deep
      nested = '{"a":' * 50 + '1' + '}' * 50

      expect {
        result = JQ.filter(nested, '.')
      }.not_to raise_error(SystemStackError)
    end

    it 'handles moderately nested arrays' do
      # Create nested arrays: [[[[...]]]] 50 levels deep
      nested = '[' * 50 + '1' + ']' * 50

      expect {
        result = JQ.filter(nested, '.')
      }.not_to raise_error(SystemStackError)
    end
  end

  describe 'special characters' do
    it 'handles strings with quotes' do
      json = '{"text":"He said \"hello\" to me"}'
      result = JQ.filter(json, '.text', raw_output: true)
      expect(result).to eq('He said "hello" to me')
    end

    it 'handles strings with backslashes' do
      json = '{"path":"C:\\\\Users\\\\test"}'
      result = JQ.filter(json, '.path', raw_output: true)
      expect(result).to eq('C:\\Users\\test')
    end

    it 'handles strings with newlines' do
      json = '{"text":"line1\\nline2\\nline3"}'
      result = JQ.filter(json, '.text', raw_output: true)
      expect(result).to include("\n")
    end

    it 'handles unicode characters' do
      json = '{"emoji":"🎉🎊✨","chinese":"你好世界","arabic":"مرحبا"}'
      result = JQ.filter(json, '.emoji', raw_output: true)
      expect(result).to eq('🎉🎊✨')
    end

    it 'handles zero-width characters' do
      json = '{"text":"hello\u200Bworld"}'  # Zero-width space
      expect {
        JQ.filter(json, '.text')
      }.not_to raise_error
    end

    it 'handles control characters' do
      json = '{"text":"hello\\u0000world"}'  # Null character
      expect {
        JQ.filter(json, '.text')
      }.not_to raise_error
    end
  end

  describe 'malicious filter attempts' do
    it 'prevents system command execution' do
      # jq doesn't have system() by design, but let's verify
      expect {
        JQ.filter('{}', 'system("ls")')
      }.to raise_error(JQ::CompileError)
    end

    it 'prevents eval-like operations' do
      expect {
        JQ.filter('{}', 'eval("dangerous code")')
      }.to raise_error(JQ::CompileError)
    end

    it 'prevents file access' do
      expect {
        JQ.filter('{}', 'input("/etc/passwd")')
      }.to raise_error(JQ::CompileError)
    end
  end

  describe 'null bytes and binary data' do
    it 'handles null bytes in strings' do
      # Note: JSON doesn't support raw null bytes, must be escaped
      json = '{"data":"hello\\u0000world"}'
      expect {
        JQ.filter(json, '.data')
      }.not_to raise_error
    end
  end

  describe 'edge case filters' do
    it 'handles very long filters' do
      # Create a filter with many chained operations
      filter = '. | ' * 100 + '.'

      expect {
        JQ.filter('{}', filter)
      }.not_to raise_error
    end

    it 'handles filters with many parentheses' do
      filter = '(' * 20 + '.' + ')' * 20

      expect {
        JQ.filter('{}', filter)
      }.not_to raise_error
    end
  end

  describe 'resource exhaustion' do
    it 'handles filters that generate many outputs' do
      # This generates 100 outputs
      json = (1..100).to_a.to_json

      expect {
        results = JQ.filter(json, '.[]', multiple_outputs: true)
        expect(results.length).to eq(100)
      }.not_to raise_error
    end

    it 'handles recursive operations' do
      json = '{"a":1,"b":{"c":2,"d":{"e":3}}}'

      expect {
        result = JQ.filter(json, '.. | numbers')
        # Should find at least one number
      }.not_to raise_error
    end
  end

  describe 'empty and minimal inputs' do
    it 'handles empty string as JSON' do
      expect {
        JQ.filter('', '.')
      }.to raise_error(JQ::ParseError)
    end

    it 'handles whitespace-only JSON' do
      expect {
        JQ.filter('   ', '.')
      }.to raise_error(JQ::ParseError)
    end

    it 'handles minimal valid JSON' do
      expect {
        result = JQ.filter('0', '.')
        expect(result).to eq('0')
      }.not_to raise_error
    end
  end
end
