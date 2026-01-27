# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JQ do
  describe '.filter' do
    context 'basic filters' do
      it 'applies identity filter' do
        result = JQ.filter('{"a":1}', '.')
        expect(result).to eq('{"a":1}')
      end

      it 'extracts a simple field' do
        result = JQ.filter('{"name":"Alice"}', '.name')
        expect(result).to eq('"Alice"')
      end

      it 'accesses nested fields' do
        json = '{"user":{"name":"Bob","age":30}}'
        result = JQ.filter(json, '.user.name')
        expect(result).to eq('"Bob"')
      end

      it 'accesses array elements' do
        result = JQ.filter('[1,2,3]', '.[1]')
        expect(result).to eq('2')
      end

      it 'returns first result by default' do
        result = JQ.filter('[1,2,3]', '.[]')
        expect(result).to eq('1')
      end
    end

    context 'with raw_output option' do
      it 'returns raw strings' do
        result = JQ.filter('{"name":"Alice"}', '.name', raw_output: true)
        expect(result).to eq('Alice')
      end

      it 'returns JSON for non-strings' do
        result = JQ.filter('{"age":30}', '.age', raw_output: true)
        expect(result).to eq('30')
      end

      it 'works with multiple outputs' do
        result = JQ.filter('["a","b","c"]', '.[]',
                          raw_output: true, multiple_outputs: true)
        expect(result).to eq(['a', 'b', 'c'])
      end
    end

    context 'with compact_output option' do
      it 'outputs compact JSON by default' do
        json = '{"a": 1, "b": 2}'
        result = JQ.filter(json, '.')
        expect(result).not_to include("\n")
        expect(result).to match(/^\{"[ab]":[12],"[ab]":[12]\}$/)
      end

      it 'outputs pretty JSON when compact_output: false' do
        json = '{"a":1,"b":2}'
        result = JQ.filter(json, '.', compact_output: false)
        expect(result).to include("\n")
        expect(result).to match(/"a": 1/)
      end
    end

    context 'with sort_keys option' do
      it 'sorts object keys' do
        json = '{"z":1,"a":2,"m":3}'
        result = JQ.filter(json, '.', sort_keys: true)
        expect(result).to match(/"a".*"m".*"z"/)
      end
    end

    context 'with multiple_outputs option' do
      it 'returns array of all results' do
        result = JQ.filter('[1,2,3]', '.[]', multiple_outputs: true)
        expect(result).to eq(['1', '2', '3'])
      end

      it 'returns empty array when no results' do
        result = JQ.filter('[1,2,3]', '.[] | select(. > 10)',
                          multiple_outputs: true)
        expect(result).to eq([])
      end

      it 'works with complex filters' do
        json = '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
        result = JQ.filter(json, '.[] | .name', multiple_outputs: true)
        expect(result).to eq(['"Alice"', '"Bob"'])
      end
    end

    context 'complex transformations' do
      it 'applies map operation' do
        json = '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
        result = JQ.filter(json, '[.[] | .name]')
        expect(result).to eq('["Alice","Bob"]')
      end

      it 'applies select operation' do
        json = '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
        result = JQ.filter(json, '[.[] | select(.age > 26)]')
        parsed = JSON.parse(result)
        expect(parsed).to eq([{"name" => "Alice", "age" => 30}])
      end

      it 'chains multiple operations' do
        json = '{"a":1,"b":2,"c":3}'
        result = JQ.filter(json, 'to_entries | map(.value) | add')
        expect(result).to eq('6')
      end

      it 'handles array construction' do
        json = '{"x":1,"y":2}'
        result = JQ.filter(json, '[.x, .y]')
        expect(result).to eq('[1,2]')
      end

      it 'handles object construction' do
        json = '{"name":"Alice","age":30}'
        result = JQ.filter(json, '{user: .name, years: .age}')
        parsed = JSON.parse(result)
        expect(parsed).to eq({"user" => "Alice", "years" => 30})
      end
    end

    context 'edge cases' do
      it 'handles empty object' do
        result = JQ.filter('{}', '.')
        expect(result).to eq('{}')
      end

      it 'handles empty array' do
        result = JQ.filter('[]', '.')
        expect(result).to eq('[]')
      end

      it 'handles null' do
        result = JQ.filter('null', '.')
        expect(result).to eq('null')
      end

      it 'handles boolean values' do
        expect(JQ.filter('true', '.')).to eq('true')
        expect(JQ.filter('false', '.')).to eq('false')
      end

      it 'handles numbers' do
        expect(JQ.filter('42', '.')).to eq('42')
        expect(JQ.filter('3.14', '.')).to eq('3.14')
        expect(JQ.filter('-1', '.')).to eq('-1')
      end

      it 'handles strings with special characters' do
        json = '{"text":"Hello \"world\" with \\n newlines"}'
        result = JQ.filter(json, '.text', raw_output: true)
        expect(result).to include('Hello "world"')
      end

      it 'handles unicode' do
        json = '{"emoji":"🎉","chinese":"你好"}'
        result = JQ.filter(json, '.emoji', raw_output: true)
        expect(result).to eq('🎉')
      end
    end
  end

  describe '.validate_filter!' do
    it 'returns true for valid filters' do
      expect(JQ.validate_filter!('.')).to eq(true)
      expect(JQ.validate_filter!('.name')).to eq(true)
      expect(JQ.validate_filter!('.[] | select(.age > 18)')).to eq(true)
    end

    it 'raises CompileError for invalid filters' do
      expect {
        JQ.validate_filter!('.name |')
      }.to raise_error(JQ::CompileError)
    end

    it 'raises CompileError for syntax errors' do
      expect {
        JQ.validate_filter!('.name |')
      }.to raise_error(JQ::CompileError)
    end

    it 'raises CompileError for undefined functions' do
      expect {
        JQ.validate_filter!('undefined_function()')
      }.to raise_error(JQ::CompileError)
    end
  end

  describe 'exception hierarchy' do
    it 'has correct exception inheritance' do
      expect(JQ::CompileError.ancestors).to include(JQ::Error)
      expect(JQ::RuntimeError.ancestors).to include(JQ::Error)
      expect(JQ::ParseError.ancestors).to include(JQ::Error)
      expect(JQ::Error.ancestors).to include(StandardError)
    end
  end

  describe 'version' do
    it 'has a version number' do
      expect(JQ::VERSION).not_to be_nil
      expect(JQ::VERSION).to match(/^\d+\.\d+\.\d+/)
    end
  end
end
