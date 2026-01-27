# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Thread safety', :slow do
  describe 'concurrent operations' do
    it 'handles concurrent filter calls without crashes' do
      json = '{"name":"Alice","age":30,"city":"NYC"}'
      filter = '.name'

      threads = 20.times.map do
        Thread.new do
          100.times do
            result = JQ.filter(json, filter, raw_output: true)
            expect(result).to eq('Alice')
          end
        end
      end

      threads.each(&:join)
    end

    it 'handles concurrent calls with different filters' do
      json = '{"a":1,"b":2,"c":3}'

      filters = ['.a', '.b', '.c', 'keys', 'values', 'to_entries']

      threads = 10.times.flat_map do |i|
        filters.map do |filter|
          Thread.new do
            50.times do
              result = JQ.filter(json, filter)
              expect(result).to be_a(String)
              expect(result.length).to be > 0
            end
          end
        end
      end

      threads.each(&:join)
    end

    it 'handles concurrent calls with different JSON inputs' do
      jsons = [
        '{"name":"Alice"}',
        '{"name":"Bob"}',
        '{"name":"Charlie"}',
        '[1,2,3]',
        '{"x":{"y":{"z":1}}}'
      ]

      threads = 20.times.map do |i|
        Thread.new do
          json = jsons[i % jsons.length]
          50.times do
            result = JQ.filter(json, '.')
            expect(result).to be_a(String)
          end
        end
      end

      threads.each(&:join)
    end

    it 'handles concurrent validation calls' do
      filters = ['.name', '.[]', 'keys', 'map(.x)', 'select(.y)']

      threads = 20.times.map do |i|
        Thread.new do
          filter = filters[i % filters.length]
          100.times do
            result = JQ.validate_filter!(filter)
            expect(result).to eq(true)
          end
        end
      end

      threads.each(&:join)
    end

    it 'handles concurrent errors without corruption' do
      threads = 20.times.map do
        Thread.new do
          50.times do
            # Should raise ParseError, not crash
            expect {
              JQ.filter('invalid json', '.')
            }.to raise_error(JQ::ParseError)
          end
        end
      end

      threads.each(&:join)
    end

    it 'handles mixed success and errors concurrently' do
      threads = 20.times.map do |i|
        Thread.new do
          50.times do
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

      threads.each(&:join)
    end

    it 'maintains correct results under concurrent load' do
      test_cases = [
        ['{"a":1}', '.a', '1'],
        ['{"b":2}', '.b', '2'],
        ['[1,2,3]', '.[0]', '1'],
        ['{"x":"hello"}', '.x', '"hello"']
      ]

      threads = 20.times.flat_map do |i|
        test_cases.map do |json, filter, expected|
          Thread.new do
            100.times do
              result = JQ.filter(json, filter)
              expect(result).to eq(expected),
                "Thread #{i} got wrong result: #{result} != #{expected}"
            end
          end
        end
      end

      threads.each(&:join)
    end

    it 'handles concurrent multiple_outputs calls' do
      json = '[1,2,3,4,5]'
      filter = '.[]'

      threads = 10.times.map do
        Thread.new do
          50.times do
            results = JQ.filter(json, filter, multiple_outputs: true)
            expect(results).to eq(['1', '2', '3', '4', '5'])
          end
        end
      end

      threads.each(&:join)
    end
  end

  describe 'stress test' do
    it 'survives sustained concurrent load', :stress do
      json = '{"data":{"nested":{"value":42}}}'
      filter = '.data.nested.value'

      start_time = Time.now
      errors = []
      mutex = Mutex.new

      threads = 50.times.map do |i|
        Thread.new do
          begin
            200.times do
              result = JQ.filter(json, filter)
              unless result == '42'
                mutex.synchronize do
                  errors << "Thread #{i} got wrong result: #{result}"
                end
              end
            end
          rescue => e
            mutex.synchronize do
              errors << "Thread #{i} crashed: #{e.class}: #{e.message}"
            end
          end
        end
      end

      threads.each(&:join)
      duration = Time.now - start_time

      expect(errors).to be_empty, "Errors occurred:\n#{errors.join("\n")}"

      puts "\nStress test completed:"
      puts "  #{50 * 200} operations across 50 threads"
      puts "  Duration: #{duration.round(2)}s"
      puts "  Rate: #{(50 * 200 / duration).round(0)} ops/sec"
    end
  end
end
