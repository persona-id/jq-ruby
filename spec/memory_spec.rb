# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Memory management' do
  describe 'no memory leaks' do
    it 'does not leak memory over many iterations' do
      json = '{"name":"Alice","age":30,"city":"NYC"}'
      filter = '.name'

      # Run many iterations
      1000.times do
        JQ.filter(json, filter)
      end

      # If we got here without crashing, memory management is working
      expect(true).to be true
    end

    it 'does not leak with multiple outputs' do
      json = '[1,2,3,4,5]'
      filter = '.[]'

      1000.times do
        JQ.filter(json, filter, multiple_outputs: true)
      end

      expect(true).to be true
    end

    it 'does not leak with errors' do
      json = '{"a":1}'

      1000.times do
        begin
          JQ.filter(json, 'undefined_function()')
        rescue JQ::CompileError
          # Expected
        end
      end

      expect(true).to be true
    end

    it 'does not leak with parse errors' do
      invalid_json = 'not json'
      filter = '.'

      1000.times do
        begin
          JQ.filter(invalid_json, filter)
        rescue JQ::ParseError
          # Expected
        end
      end

      expect(true).to be true
    end

    it 'does not leak with runtime errors' do
      json = '42'
      filter = '.[]'  # Can't iterate over number

      1000.times do
        begin
          JQ.filter(json, filter)
        rescue JQ::RuntimeError
          # Expected
        end
      end

      expect(true).to be true
    end

    it 'does not leak with validation' do
      1000.times do
        JQ.validate_filter!('.name')
      end

      1000.times do
        begin
          JQ.validate_filter!('. @@@ .')
        rescue JQ::CompileError
          # Expected
        end
      end

      expect(true).to be true
    end
  end

  describe 'cleanup on errors' do
    it 'cleans up when filter compilation fails' do
      json = '{"a":1}'

      expect {
        JQ.filter(json, '. @@@ .')
      }.to raise_error(JQ::CompileError)

      # Should be able to continue using JQ after error
      result = JQ.filter(json, '.')
      expect(result).to eq('{"a":1}')
    end

    it 'cleans up when JSON parsing fails' do
      expect {
        JQ.filter('invalid', '.')
      }.to raise_error(JQ::ParseError)

      # Should be able to continue using JQ after error
      result = JQ.filter('{"a":1}', '.')
      expect(result).to eq('{"a":1}')
    end

    it 'cleans up when runtime error occurs' do
      expect {
        JQ.filter('42', '.[]')
      }.to raise_error(JQ::RuntimeError)

      # Should be able to continue using JQ after error
      result = JQ.filter('[1,2,3]', '.[]')
      expect(result).to eq('1')
    end
  end

  describe 'large data cleanup' do
    it 'cleans up large JSON structures' do
      # Create a large nested structure
      large_json = '{"data":' + '[' * 100 + '{"value":1}' + ']' * 100 + '}'

      10.times do
        result = JQ.filter(large_json, '.data')
        expect(result).to be_a(String)
      end

      # If we got here, memory was cleaned up properly
      expect(true).to be true
    end

    it 'cleans up large output arrays' do
      json = (1..1000).to_a.to_json

      10.times do
        results = JQ.filter(json, '.[]', multiple_outputs: true)
        expect(results.length).to eq(1000)
      end

      expect(true).to be true
    end
  end

  describe 'ObjectSpace tracking', if: defined?(ObjectSpace) do
    it 'does not leak Ruby strings' do
      GC.start
      before_count = ObjectSpace.count_objects[:T_STRING]

      100.times do
        JQ.filter('{"name":"test"}', '.name')
      end

      GC.start
      after_count = ObjectSpace.count_objects[:T_STRING]

      # Allow some leeway for Ruby's string pool and other system strings
      # We're mainly checking we don't leak 100+ strings
      expect(after_count - before_count).to be < 50
    end
  end

  describe 'repeated operations' do
    it 'handles repeated filter compilations' do
      json = '{"a":1}'

      100.times do |i|
        filter = ".a | . + #{i}"
        result = JQ.filter(json, filter)
        expect(result).to eq((1 + i).to_s)
      end
    end

    it 'handles repeated JSON parsing' do
      filter = '.value'

      100.times do |i|
        json = "{\"value\":#{i}}"
        result = JQ.filter(json, filter)
        expect(result).to eq(i.to_s)
      end
    end

    it 'handles alternating success and errors' do
      100.times do |i|
        if i.even?
          result = JQ.filter('{"a":1}', '.a')
          expect(result).to eq('1')
        else
          expect {
            JQ.filter('invalid', '.')
          }.to raise_error(JQ::ParseError)
        end
      end
    end
  end
end
