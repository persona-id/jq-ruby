# jq-ruby

A minimal, security-focused Ruby gem that wraps the jq C library for JSON transformation.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jq'
```

And then execute:

```bash
bundle install
```

Or install it yourself:

```bash
gem install jq
```

**Note:** This gem bundles jq 1.8.1 and builds it from source automatically during installation. No system dependencies are required.

## Usage

### Basic Filtering

```ruby
require 'jq'

# Basic filter
result = JQ.filter('{"name":"Alice","age":30}', '.name')
# => "\"Alice\""

# Identity filter (compact output is the default)
result = JQ.filter('{"a":1}', '.')
# => "{\"a\":1}"

# Nested access
result = JQ.filter('{"user":{"name":"Bob"}}', '.user.name')
# => "\"Bob\""

# Array operations
result = JQ.filter('[1,2,3]', '.[1]')
# => "2"
```

### Options

#### Raw Output

Get raw strings without JSON encoding (equivalent to `jq -r`):

```ruby
result = JQ.filter('{"name":"Alice"}', '.name', raw_output: true)
# => "Alice" (not "\"Alice\"")
```

#### Compact Output

**Compact output is the default.** JSON is returned on a single line without extra whitespace:

```ruby
result = JQ.filter('{"a":1,"b":2}', '.')
# => "{\"a\":1,\"b\":2}" (default)

# To get pretty-printed output, set compact_output: false
result = JQ.filter('{"a":1,"b":2}', '.', compact_output: false)
# => "{\n  \"a\": 1,\n  \"b\": 2\n}"
```

#### Sort Keys

Sort object keys for deterministic output (equivalent to `jq -S`):

```ruby
result = JQ.filter('{"z":1,"a":2}', '.', sort_keys: true)
# => "{\"a\":2,\"z\":1}"
```

#### Multiple Outputs

Return an array of all results instead of just the first:

```ruby
result = JQ.filter('[1,2,3]', '.[]', multiple_outputs: true)
# => ["1", "2", "3"]

# Combining with raw_output
result = JQ.filter('["a","b","c"]', '.[]', multiple_outputs: true, raw_output: true)
# => ["a", "b", "c"]
```

### Complex Transformations

```ruby
# Map operation
json = '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
result = JQ.filter(json, '[.[] | .name]')
# => "[\"Alice\",\"Bob\"]"

# Select operation
result = JQ.filter(json, '[.[] | select(.age > 26)]')
# => "[{\"name\":\"Alice\",\"age\":30}]"

# Multiple transformations
result = JQ.filter('{"a":1,"b":2,"c":3}', 'to_entries | map(.value) | add')
# => "6"
```

### Filter Validation

Validate a filter before using it:

```ruby
JQ.validate_filter!('.name')
# => true

JQ.validate_filter!('...invalid')
# raises JQ::CompileError
```

### Error Handling

The gem defines four exception classes:

```ruby
begin
  JQ.filter('invalid json', '.')
rescue JQ::ParseError => e
  puts "Invalid JSON: #{e.message}"
end

begin
  JQ.filter('{}', '...invalid filter')
rescue JQ::CompileError => e
  puts "Invalid filter: #{e.message}"
end

begin
  JQ.filter('{}', '.nonexistent.deeply.nested')
rescue JQ::RuntimeError => e
  puts "Runtime error: #{e.message}"
end
```

Exception hierarchy:

- `JQ::Error` - Base class for all jq-related errors
  - `JQ::ParseError` - Invalid JSON input
  - `JQ::CompileError` - Invalid jq filter
  - `JQ::RuntimeError` - Runtime execution error

## Thread Safety

**Status: Likely safe with jq 1.7+, but not officially guaranteed**

This gem creates an isolated `jq_state` for each call, and jq 1.7+ fixed a critical thread-safety bug (PR #2546). Multi-threaded use is **probably safe** in MRI Ruby where the GVL serializes execution, but jq hasn't made formal thread-safety guarantees.

**Recommendations:**
- ✅ Use with jq 1.7+ (check: `jq --version`)
- ✅ MRI Ruby (standard Ruby) - likely safe due to GVL
- ⚠️ JRuby/TruffleRuby - use with caution (true parallel threads)
- 🛡️ Safest for heavy parallel workloads: separate processes

See [SECURITY.md](SECURITY.md) for detailed thread safety information.

## Memory Considerations

- The gem uses proper jv lifecycle management to prevent memory leaks
- Very large JSON documents (>100MB) may cause high memory usage
- Deeply nested structures may hit stack limits
- Complex filters may be slow - there is no timeout mechanism in v1.0

## Security

See [SECURITY.md](SECURITY.md) for detailed security information.

Key points:

- JSON input is parsed by jq's parser (no eval/injection risk)
- Filter expressions cannot execute system commands (safe by design)
- All inputs are validated for type before processing
- The extension uses proper memory management to prevent buffer overflows

## Development

After checking out the repo, run:

```bash
bundle install
bundle exec rake compile
bundle exec rake spec
```

To check for memory leaks:

```bash
bundle exec rake compile CFLAGS="-fsanitize=address -g"
bundle exec rspec spec/memory_spec.rb
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/persona-id/jq-ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

jq itself is licensed under the MIT License. See https://github.com/jqlang/jq for details.
