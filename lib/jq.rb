# frozen_string_literal: true

##
# JQ provides Ruby bindings for the jq JSON processor.
#
# This gem wraps the jq C library, allowing you to apply jq filters to JSON
# strings directly from Ruby. It supports all standard jq operations and
# provides a clean Ruby API with proper error handling.
#
# === Thread Safety
#
# This gem requires jq 1.7+ for safe multi-threaded operation. Each method
# call creates an isolated jq_state, and jq 1.7+ includes critical thread
# safety fixes (PR #2546). Safe to use from multiple threads in MRI Ruby.
#
# === Basic Usage
#
#   require 'jq'
#
#   # Simple filtering
#   JQ.filter('{"name":"Alice"}', '.name')
#   # => "\"Alice\""
#
#   # With options
#   JQ.filter('{"name":"Alice"}', '.name', raw_output: true)
#   # => "Alice"
#
#   # Multiple outputs
#   JQ.filter('[1,2,3]', '.[]', multiple_outputs: true)
#   # => ["1", "2", "3"]
#
# === Error Handling
#
# All jq-related errors inherit from JQ::Error:
#
#   begin
#     JQ.filter('invalid', '.')
#   rescue JQ::ParseError => e
#     puts "Invalid JSON: #{e.message}"
#   end
#
# @see https://jqlang.github.io/jq/ jq documentation
#
module JQ
  ##
  # The gem version number
  #
  VERSION = "1.0.0"

  ##
  # Base exception class for all jq-related errors.
  #
  # All other jq exception classes inherit from this, allowing you to
  # rescue all jq errors with a single rescue clause:
  #
  #   begin
  #     JQ.filter(json, filter)
  #   rescue JQ::Error => e
  #     puts "JQ error: #{e.message}"
  #   end
  #
  class Error < StandardError; end

  ##
  # Raised when a jq filter expression fails to compile.
  #
  # This typically indicates a syntax error in the filter expression:
  #
  #   JQ.filter('{}', '. @@@ .')
  #   # raises JQ::CompileError: Syntax error in jq filter
  #
  class CompileError < Error; end

  ##
  # Raised when a jq filter fails during execution.
  #
  # This typically indicates a type mismatch or invalid operation:
  #
  #   JQ.filter('42', '.[]')
  #   # raises JQ::RuntimeError: Cannot iterate over number
  #
  class RuntimeError < Error; end

  ##
  # Raised when JSON input is invalid or malformed.
  #
  # This indicates the input string is not valid JSON:
  #
  #   JQ.filter('not json', '.')
  #   # raises JQ::ParseError: Invalid JSON input
  #
  class ParseError < Error; end
end

begin
  require_relative "jq/jq_ext"
rescue LoadError => e
  raise LoadError, "Failed to load jq extension. " \
                   "Please run 'rake compile' to build the extension. " \
                   "Original error: #{e.message}"
end
