/* frozen_string_literal: true */

#ifndef JQ_EXT_H
#define JQ_EXT_H

#include <ruby.h>
#include <jq.h>
#include <jv.h>

// Ruby module and exception classes
extern VALUE rb_mJQ;
extern VALUE rb_eJQError;
extern VALUE rb_eJQCompileError;
extern VALUE rb_eJQRuntimeError;
extern VALUE rb_eJQParseError;

// Main methods
VALUE rb_jq_filter(int argc, VALUE *argv, VALUE self);
VALUE rb_jq_validate_filter(VALUE self, VALUE filter);

// Helper functions
static VALUE rb_jq_filter_impl(const char *json_str, const char *filter_str,
                                int raw_output, int compact_output,
                                int sort_keys, int multiple_outputs);
static VALUE jv_to_json_string(jv value, int raw, int compact, int sort);
static void raise_jq_error(jv error_value, VALUE exception_class);

// Initialization
void Init_jq_ext(void);

#endif /* JQ_EXT_H */
