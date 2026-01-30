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

// Initialization
void Init_jq_ext(void);

#endif /* JQ_EXT_H */
