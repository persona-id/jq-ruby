# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-26

### Added

- Initial release of jq-ruby gem
- `JQ.filter` method for applying jq filters to JSON
  - Support for `raw_output` option (jq -r)
  - Support for `compact_output` option (jq -c)
  - Support for `sort_keys` option (jq -S)
  - Support for `multiple_outputs` option to return all results
- `JQ.validate_filter!` method for validating jq filter expressions
- Exception hierarchy:
  - `JQ::Error` - Base exception class
  - `JQ::CompileError` - Invalid jq filter
  - `JQ::RuntimeError` - Runtime execution error
  - `JQ::ParseError` - Invalid JSON input
- System library detection with miniportile fallback
  - Automatic detection of system jq library via pkg-config
  - Falls back to building jq 1.7.1 from source if needed
  - Support for `--use-system-libraries` flag
- Comprehensive test suite with >95% coverage
  - Core functionality tests
  - Filter validation tests
  - Error handling tests
  - Security tests
  - Memory leak detection tests
- Complete documentation
  - README with usage examples
  - SECURITY.md with security considerations
  - RBS type signatures
- Ruby 3.3+ required
- Thread safety documentation (jq is NOT thread-safe)

### Security

- Proper jv memory lifecycle management prevents buffer overflows
- All inputs validated for type before processing
- JSON parsed by jq's built-in parser (no eval/injection risk)
- Filter expressions cannot execute system commands (safe by design)
- Tested with large inputs, deeply nested structures, and malicious filters

[1.0.0]: https://github.com/persona-id/jq-ruby/releases/tag/v1.0.0
