# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Error handling' do
  describe 'ParseError' do
    it 'raises on invalid JSON' do
      expect {
        JQ.filter('not json', '.')
      }.to raise_error(JQ::ParseError)
    end

    it 'raises on malformed JSON' do
      expect {
        JQ.filter('{"incomplete":', '.')
      }.to raise_error(JQ::ParseError)
    end

    it 'raises on unmatched brackets' do
      expect {
        JQ.filter('[1,2,3', '.')
      }.to raise_error(JQ::ParseError)
    end

    it 'raises on trailing comma' do
      expect {
        JQ.filter('{"a":1,}', '.')
      }.to raise_error(JQ::ParseError)
    end
  end

  describe 'CompileError' do
    it 'raises on invalid filter' do
      expect {
        JQ.filter('{}', '. @@@ .')
      }.to raise_error(JQ::CompileError)
    end

    it 'raises on undefined function' do
      expect {
        JQ.filter('{}', 'nonexistent_function()')
      }.to raise_error(JQ::CompileError)
    end

    it 'raises on syntax error in filter' do
      expect {
        JQ.filter('{}', '. |')
      }.to raise_error(JQ::CompileError)
    end
  end

  describe 'RuntimeError' do
    it 'raises on type mismatch operations' do
      # Trying to iterate over a non-array/object
      expect {
        JQ.filter('42', '.[]')
      }.to raise_error(JQ::RuntimeError)
    end

    it 'raises on invalid array access' do
      # While jq returns null for missing keys, some operations can fail
      expect {
        JQ.filter('null', '.[]')
      }.to raise_error(JQ::RuntimeError)
    end
  end

  describe 'type validation' do
    it 'raises TypeError when json is not a string' do
      expect {
        JQ.filter(nil, '.')
      }.to raise_error(TypeError)
    end

    it 'raises TypeError when filter is not a string' do
      expect {
        JQ.filter('{}', nil)
      }.to raise_error(TypeError)
    end

    it 'raises TypeError when json is a number' do
      expect {
        JQ.filter(123, '.')
      }.to raise_error(TypeError)
    end

    it 'raises TypeError when filter is a symbol' do
      expect {
        JQ.filter('{}', :name)
      }.to raise_error(TypeError)
    end

    it 'raises ArgumentError when too many positional arguments' do
      expect {
        JQ.filter('{}', '.', "extra arg")
      }.to raise_error(ArgumentError)
    end
  end

  describe 'validate_filter! type validation' do
    it 'raises TypeError when filter is not a string' do
      expect {
        JQ.validate_filter!(nil)
      }.to raise_error(TypeError)
    end

    it 'raises TypeError when filter is a number' do
      expect {
        JQ.validate_filter!(123)
      }.to raise_error(TypeError)
    end
  end

  describe 'error messages' do
    it 'provides helpful parse error messages' do
      expect {
        JQ.filter('invalid', '.')
      }.to raise_error(JQ::ParseError, /parse|invalid|json/i)
    end

    it 'provides helpful compile error messages' do
      expect {
        JQ.filter('{}', 'undefined_func()')
      }.to raise_error(JQ::CompileError, /syntax error/i)
    end
  end

  describe 'exception rescue' do
    it 'can rescue specific exceptions' do
      begin
        JQ.filter('invalid', '.')
      rescue JQ::ParseError => e
        expect(e).to be_a(JQ::ParseError)
        expect(e).to be_a(JQ::Error)
        expect(e).to be_a(StandardError)
      end
    end

    it 'can rescue base JQ::Error' do
      caught = false

      begin
        JQ.filter('invalid', '.')
      rescue JQ::Error
        caught = true
      end

      expect(caught).to be true
    end
  end
end
