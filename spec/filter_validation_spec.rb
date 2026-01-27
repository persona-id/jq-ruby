# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Filter validation' do
  describe 'valid filters' do
    it 'accepts identity filter' do
      expect { JQ.validate_filter!('.') }.not_to raise_error
    end

    it 'accepts field access' do
      expect { JQ.validate_filter!('.name') }.not_to raise_error
      expect { JQ.validate_filter!('.user.name') }.not_to raise_error
    end

    it 'accepts array operations' do
      expect { JQ.validate_filter!('.[]') }.not_to raise_error
      expect { JQ.validate_filter!('.[0]') }.not_to raise_error
      expect { JQ.validate_filter!('.[1:3]') }.not_to raise_error
    end

    it 'accepts pipe operations' do
      expect { JQ.validate_filter!('. | .name') }.not_to raise_error
      expect { JQ.validate_filter!('.[] | select(.age > 18)') }.not_to raise_error
    end

    it 'accepts builtin functions' do
      expect { JQ.validate_filter!('length') }.not_to raise_error
      expect { JQ.validate_filter!('keys') }.not_to raise_error
      expect { JQ.validate_filter!('map(.name)') }.not_to raise_error
      expect { JQ.validate_filter!('select(.active)') }.not_to raise_error
    end

    it 'accepts complex expressions' do
      expect {
        JQ.validate_filter!('[.[] | {name: .name, age: .age}]')
      }.not_to raise_error
    end
  end

  describe 'invalid filters' do
    it 'rejects empty filter' do
      expect {
        JQ.validate_filter!('')
      }.to raise_error(JQ::CompileError)
    end

    it 'rejects syntax errors' do
      expect {
        JQ.validate_filter!('. @@@ .')
      }.to raise_error(JQ::CompileError)
    end

    it 'rejects incomplete pipes' do
      expect {
        JQ.validate_filter!('. |')
      }.to raise_error(JQ::CompileError)
    end

    it 'rejects unmatched brackets' do
      expect {
        JQ.validate_filter!('[.name')
      }.to raise_error(JQ::CompileError)
    end

    it 'rejects undefined functions' do
      expect {
        JQ.validate_filter!('this_function_does_not_exist()')
      }.to raise_error(JQ::CompileError)
    end

    it 'rejects invalid operators' do
      expect {
        JQ.validate_filter!('. @@@ .')
      }.to raise_error(JQ::CompileError)
    end
  end

  describe 'error messages' do
    it 'includes helpful error message' do
      expect {
        JQ.validate_filter!('. @@@ .')
      }.to raise_error(JQ::CompileError, /syntax error/i)
    end
  end
end
