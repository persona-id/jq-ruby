/* frozen_string_literal: true */

#include "jq_ext.h"
#include <string.h>

// Global variables for Ruby module and exception classes
VALUE rb_mJQ;
VALUE rb_eJQError;
VALUE rb_eJQCompileError;
VALUE rb_eJQRuntimeError;
VALUE rb_eJQParseError;

// Forward declarations for static helper functions
static VALUE jv_to_json_string(jv value, int raw, int compact, int sort);
static void raise_jq_error(jv error_value, VALUE exception_class);
static VALUE rb_jq_filter_impl(const char *json_str, const char *filter_str,
                                int raw_output, int compact_output,
                                int sort_keys, int multiple_outputs);

/**
 * Convert a jv value to a Ruby JSON string
 *
 * @param value The jv value to convert (CONSUMED by this function)
 * @param raw If true and value is string, return raw string (jq -r)
 * @param compact If true, use compact JSON output (jq -c)
 * @param sort If true, sort object keys (jq -S)
 * @return Ruby string containing JSON or raw value
 */
static VALUE jv_to_json_string(jv value, int raw, int compact, int sort) {
    int flags = 0;
    // Compact is the default; JV_PRINT_PRETTY makes it non-compact
    if (!compact) flags |= JV_PRINT_PRETTY;
    if (sort) flags |= JV_PRINT_SORTED;

    jv json;
    VALUE result;

    // Raw output - return string directly without JSON encoding
    if (raw && jv_get_kind(value) == JV_KIND_STRING) {
        const char *str = jv_string_value(value);
        size_t len = jv_string_length_bytes(jv_copy(value));
        result = rb_utf8_str_new(str, len);
        jv_free(value);  // Free the string value
        return result;
    }

    // Convert to JSON string
    json = jv_dump_string(value, flags);  // CONSUMES value

    if (!jv_is_valid(json)) {
        jv_free(json);
        rb_raise(rb_eJQRuntimeError, "Failed to convert result to JSON");
    }

    const char *json_str = jv_string_value(json);
    size_t json_len = jv_string_length_bytes(jv_copy(json));
    result = rb_utf8_str_new(json_str, json_len);
    jv_free(json);  // Free the JSON string

    return result;
}

/**
 * Raise a Ruby exception from a jv error value
 *
 * @param error_value The jv error message (CONSUMED by this function)
 * @param exception_class The Ruby exception class to raise
 */
static void raise_jq_error(jv error_value, VALUE exception_class) {
    if (!jv_is_valid(error_value) ||
        jv_get_kind(error_value) != JV_KIND_STRING) {
        jv_free(error_value);
        rb_raise(exception_class, "Unknown jq error");
    }

    const char *msg = jv_string_value(error_value);
    VALUE rb_msg = rb_str_new_cstr(msg);
    jv_free(error_value);  // Free the error message

    // Store C string before rb_raise (StringValueCStr can raise if encoding issues occur)
    const char *msg_cstr = StringValueCStr(rb_msg);
    rb_raise(exception_class, "%s", msg_cstr);
}

/**
 * Implementation of JQ.filter
 *
 * @param json_str JSON input string
 * @param filter_str jq filter expression
 * @param raw_output If true, output raw strings (jq -r)
 * @param compact_output If true, output compact JSON (jq -c)
 * @param sort_keys If true, sort object keys (jq -S)
 * @param multiple_outputs If true, return array of all results
 * @return Ruby string or array of strings
 */
static VALUE rb_jq_filter_impl(const char *json_str, const char *filter_str,
                                int raw_output, int compact_output,
                                int sort_keys, int multiple_outputs) {
    jq_state *jq = NULL;
    jv input = jv_invalid();
    VALUE results = Qnil;
    jv result;

    // Initialize jq
    jq = jq_init();
    if (!jq) {
        rb_raise(rb_eJQError, "Failed to initialize jq");
    }

    // Compile filter
    if (!jq_compile(jq, filter_str)) {
        jv error = jq_get_error_message(jq);

        if (jv_is_valid(error) && jv_get_kind(error) == JV_KIND_STRING) {
            const char *error_msg = jv_string_value(error);
            VALUE rb_error_msg = rb_str_new_cstr(error_msg);
            jv_free(error);
            // Store C string before cleanup (StringValueCStr can raise)
            const char *error_cstr = StringValueCStr(rb_error_msg);
            jq_teardown(&jq);
            rb_raise(rb_eJQCompileError, "%s", error_cstr);
        }

        jv_free(error);
        jq_teardown(&jq);
        rb_raise(rb_eJQCompileError, "Syntax error in jq filter");
    }

    // Parse JSON input
    input = jv_parse(json_str);
    if (!jv_is_valid(input)) {
        if (jv_invalid_has_msg(jv_copy(input))) {
            jv error_msg = jv_invalid_get_msg(input);  // CONSUMES input
            jq_teardown(&jq);
            raise_jq_error(error_msg, rb_eJQParseError);
        }
        jv_free(input);
        jq_teardown(&jq);
        rb_raise(rb_eJQParseError, "Invalid JSON input");
    }

    // Process with jq
    jq_start(jq, input, 0);  // CONSUMES input

    // Collect results
    if (multiple_outputs) {
        results = rb_ary_new();

        while (jv_is_valid(result = jq_next(jq))) {
            VALUE json = jv_to_json_string(result, raw_output,
                                           compact_output, sort_keys);
            rb_ary_push(results, json);
        }

        // Check if the final invalid result has an error message
        if (jv_invalid_has_msg(jv_copy(result))) {
            jv error_msg = jv_invalid_get_msg(result);  // CONSUMES result
            jq_teardown(&jq);
            raise_jq_error(error_msg, rb_eJQRuntimeError);
        }

        jv_free(result);  // Free the invalid/end marker
    } else {
        result = jq_next(jq);

        if (jv_is_valid(result)) {
            results = jv_to_json_string(result, raw_output,
                                       compact_output, sort_keys);
        } else if (jv_invalid_has_msg(jv_copy(result))) {
            jv error_msg = jv_invalid_get_msg(result);  // CONSUMES result
            jq_teardown(&jq);
            raise_jq_error(error_msg, rb_eJQRuntimeError);
        } else {
            jv_free(result);
            // No results - return null
            results = rb_str_new_cstr("null");
        }
    }

    jq_teardown(&jq);
    return results;
}

/*
 * call-seq:
 *   JQ.filter(json, filter, **options) -> String or Array<String>
 *
 * Apply a jq filter to JSON input and return the result.
 *
 * This is the primary method for using jq from Ruby. It parses the JSON input,
 * compiles the filter expression, executes it, and returns the result as a
 * JSON string (or array of strings with +multiple_outputs: true+).
 *
 * === Parameters
 *
 * [json (String)] Valid JSON input string
 * [filter (String)] jq filter expression (e.g., ".name", ".[] | select(.age > 18)")
 *
 * === Options
 *
 * [:raw_output (Boolean)] Return raw strings without JSON encoding (equivalent to jq -r). Default: false
 * [:compact_output (Boolean)] Output compact JSON on a single line. Default: true (set to false for pretty output)
 * [:sort_keys (Boolean)] Sort object keys alphabetically (equivalent to jq -S). Default: false
 * [:multiple_outputs (Boolean)] Return array of all results instead of just the first. Default: false
 *
 * === Returns
 *
 * [String] JSON-encoded result (default), or raw string if +raw_output: true+
 * [Array<String>] Array of results if +multiple_outputs: true+
 *
 * === Raises
 *
 * [JQ::ParseError] If the JSON input is invalid
 * [JQ::CompileError] If the jq filter expression is invalid
 * [JQ::RuntimeError] If the filter execution fails
 * [TypeError] If arguments are not strings
 *
 * === Examples
 *
 *   # Basic filtering
 *   JQ.filter('{"name":"Alice","age":30}', '.name')
 *   # => "\"Alice\""
 *
 *   # Raw output (no JSON encoding)
 *   JQ.filter('{"name":"Alice"}', '.name', raw_output: true)
 *   # => "Alice"
 *
 *   # Pretty output
 *   JQ.filter('{"a":1,"b":2}', '.', compact_output: false)
 *   # => "{\n  \"a\": 1,\n  \"b\": 2\n}"
 *
 *   # Multiple outputs
 *   JQ.filter('[1,2,3]', '.[]', multiple_outputs: true)
 *   # => ["1", "2", "3"]
 *
 *   # Sort keys
 *   JQ.filter('{"z":1,"a":2}', '.', sort_keys: true)
 *   # => "{\"a\":2,\"z\":1}"
 *
 *   # Complex transformation
 *   json = '[{"name":"Alice","age":30},{"name":"Bob","age":25}]'
 *   JQ.filter(json, '[.[] | select(.age > 26) | .name]')
 *   # => "[\"Alice\"]"
 *
 * === Thread Safety
 *
 * This method is thread-safe with jq 1.7+ (required by this gem). Each call
 * creates an isolated jq_state, so concurrent calls do not interfere with
 * each other.
 *
 */
VALUE rb_jq_filter(int argc, VALUE *argv, VALUE self) {
    VALUE json_str, filter_str, opts;
    rb_scan_args(argc, argv, "2:", &json_str, &filter_str, &opts);

    Check_Type(json_str, T_STRING);
    Check_Type(filter_str, T_STRING);

    const char *json_cstr = StringValueCStr(json_str);
    const char *filter_cstr = StringValueCStr(filter_str);

    // Parse options (default to compact output)
    int raw_output = 0, compact_output = 1;
    int sort_keys = 0, multiple_outputs = 0;

    if (!NIL_P(opts)) {
        Check_Type(opts, T_HASH);
        VALUE opt;

        opt = rb_hash_aref(opts, ID2SYM(rb_intern("raw_output")));
        if (RTEST(opt)) raw_output = 1;

        opt = rb_hash_aref(opts, ID2SYM(rb_intern("compact_output")));
        if (!NIL_P(opt)) compact_output = RTEST(opt) ? 1 : 0;

        opt = rb_hash_aref(opts, ID2SYM(rb_intern("sort_keys")));
        if (RTEST(opt)) sort_keys = 1;

        opt = rb_hash_aref(opts, ID2SYM(rb_intern("multiple_outputs")));
        if (RTEST(opt)) multiple_outputs = 1;
    }

    return rb_jq_filter_impl(json_cstr, filter_cstr,
                             raw_output, compact_output,
                             sort_keys, multiple_outputs);
}

/*
 * call-seq:
 *   JQ.validate_filter!(filter) -> true
 *
 * Validate a jq filter expression without executing it.
 *
 * This method compiles the filter to check for syntax errors without requiring
 * any JSON input. Use this to validate user-provided filters before attempting
 * to apply them to data.
 *
 * === Parameters
 *
 * [filter (String)] jq filter expression to validate
 *
 * === Returns
 *
 * [true] Always returns true if the filter is valid
 *
 * === Raises
 *
 * [JQ::CompileError] If the filter expression is invalid
 * [TypeError] If filter is not a string
 *
 * === Examples
 *
 *   # Valid filters return true
 *   JQ.validate_filter!('.name')
 *   # => true
 *
 *   JQ.validate_filter!('.[] | select(.age > 18)')
 *   # => true
 *
 *   # Invalid filters raise CompileError
 *   JQ.validate_filter!('. @@@ .')
 *   # raises JQ::CompileError: Syntax error in jq filter
 *
 *   # Validate user input before use
 *   user_filter = params[:filter]
 *   begin
 *     JQ.validate_filter!(user_filter)
 *     result = JQ.filter(json, user_filter)
 *   rescue JQ::CompileError => e
 *     puts "Invalid filter: #{e.message}"
 *   end
 *
 * === Thread Safety
 *
 * This method is thread-safe with jq 1.7+ (required by this gem).
 *
 */
VALUE rb_jq_validate_filter(VALUE self, VALUE filter) {
    Check_Type(filter, T_STRING);
    const char *filter_cstr = StringValueCStr(filter);

    jq_state *jq = jq_init();
    if (!jq) {
        rb_raise(rb_eJQError, "Failed to initialize jq");
    }

    if (!jq_compile(jq, filter_cstr)) {
        jv error = jq_get_error_message(jq);

        if (jv_is_valid(error) && jv_get_kind(error) == JV_KIND_STRING) {
            const char *error_msg = jv_string_value(error);
            VALUE rb_error_msg = rb_str_new_cstr(error_msg);
            jv_free(error);
            // Store C string before cleanup (StringValueCStr can raise)
            const char *error_cstr = StringValueCStr(rb_error_msg);
            jq_teardown(&jq);
            rb_raise(rb_eJQCompileError, "%s", error_cstr);
        }

        jv_free(error);
        jq_teardown(&jq);
        rb_raise(rb_eJQCompileError, "Syntax error in jq filter");
    }

    jq_teardown(&jq);
    return Qtrue;
}

/**
 * Initialize the jq extension
 */
void Init_jq_ext(void) {
    // Define module
    rb_mJQ = rb_define_module("JQ");

    // Define exception classes
    rb_eJQError = rb_define_class_under(rb_mJQ, "Error", rb_eStandardError);
    rb_eJQCompileError = rb_define_class_under(rb_mJQ, "CompileError", rb_eJQError);
    rb_eJQRuntimeError = rb_define_class_under(rb_mJQ, "RuntimeError", rb_eJQError);
    rb_eJQParseError = rb_define_class_under(rb_mJQ, "ParseError", rb_eJQError);

    // Define methods
    rb_define_singleton_method(rb_mJQ, "filter", rb_jq_filter, -1);
    rb_define_singleton_method(rb_mJQ, "validate_filter!", rb_jq_validate_filter, 1);
}
