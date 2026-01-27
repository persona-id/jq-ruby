# Security

## Thread Safety

**Status: Likely safe with jq 1.7+, but not officially guaranteed**

The jq C library was not originally designed for multi-threading. However, as of jq 1.7 (PR #2546), a critical segfault bug in multi-threaded environments was fixed.

**Current Safety Profile:**
- ✅ Each `JQ.filter` call creates its own isolated `jq_state` (no shared state between calls)
- ✅ jq 1.7+ fixed the thread-local storage segfault (included in your jq 1.8.1)
- ✅ Ruby's GVL (MRI) prevents true parallel execution, providing additional serialization
- ⚠️ jq developers have not made formal thread-safety guarantees beyond fixing the segfault
- ⚠️ Other global state issues may exist but are unconfirmed

**Practical Recommendation:**
- **Probably safe** to call `JQ.filter` from multiple Ruby threads in MRI Ruby with jq 1.7+
- **Use caution** with JRuby or TruffleRuby where threads can run truly in parallel
- **Safest approach** for heavy parallel processing: use separate processes (e.g., `parallel` gem)

**Version Requirements:**
- jq 1.7+ strongly recommended for any multi-threaded use
- Check your jq version: `jq --version`

## Input Validation

- **JSON input** is parsed by jq's built-in parser. There is no eval or code injection risk.
- **Filter expressions** are compiled by jq's compiler. They cannot execute system commands or access the filesystem (safe by design).
- All inputs are validated for type before processing in the Ruby C extension.

## Memory Safety

The extension uses proper jv lifecycle management to prevent memory leaks and buffer overflows:

- Every `jv` value is tracked and freed appropriately
- Error paths ensure cleanup before raising Ruby exceptions
- The jq library's "consume" pattern is followed correctly

### Testing for Memory Issues

Run tests with AddressSanitizer to detect memory errors:

```bash
bundle exec rake compile CFLAGS="-fsanitize=address -g"
bundle exec rspec
```

Or use valgrind:

```bash
valgrind --leak-check=full bundle exec rspec
```

Run the memory test suite:

```bash
bundle exec rspec spec/memory_spec.rb
```

## Known Limitations

- **Very large JSON documents** (>100MB) may cause high memory usage. The entire document is parsed into memory before processing.
- **Deeply nested structures** may hit stack limits (typically ~1000 levels depending on system).
- **Complex filters** may be slow. There is no timeout mechanism in v1.0 - long-running filters will block.
- **No sandboxing** - While jq filters cannot execute arbitrary code, complex filters can consume significant CPU and memory.

## Security Best Practices

1. **Validate input size** - If processing untrusted JSON, check the size before passing to `JQ.filter`:

   ```ruby
   MAX_JSON_SIZE = 10 * 1024 * 1024 # 10MB
   raise "JSON too large" if json_string.bytesize > MAX_JSON_SIZE
   ```

2. **Validate filter** - If using user-provided filters, validate them first:

   ```ruby
   begin
     JQ.validate_filter!(user_filter)
   rescue JQ::CompileError => e
     # Handle invalid filter
   end
   ```

3. **Set timeouts** - Use Ruby's `Timeout` module for long-running operations (note: this may not interrupt C code immediately):

   ```ruby
   require 'timeout'

   begin
     Timeout.timeout(5) do
       JQ.filter(json, filter)
     end
   rescue Timeout::Error
     # Handle timeout
   end
   ```

4. **Limit nesting depth** - Pre-validate JSON nesting if processing untrusted input:

   ```ruby
   def check_nesting_depth(json_string, max_depth = 100)
     depth = 0
     max_seen = 0
     json_string.each_char do |c|
       depth += 1 if c == '{' || c == '['
       depth -= 1 if c == '}' || c == ']'
       max_seen = [max_seen, depth].max
       raise "Nesting too deep" if max_seen > max_depth
     end
   end
   ```

## Reporting Security Issues

If you discover a security vulnerability, please email security@persona.com with details. Do not open a public issue.

## Acknowledgments

This gem wraps the jq library (https://github.com/jqlang/jq), which is maintained by the jq authors and community.
