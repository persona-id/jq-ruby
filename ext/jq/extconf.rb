# frozen_string_literal: true

ENV["RC_ARCHS"] = "" if RUBY_PLATFORM.include?("darwin")

require 'mkmf'
require 'mini_portile2'

class JQRecipe < MiniPortile
  JQ_VERSION = '1.8.1'
  JQ_SHA256 = '2be64e7129cecb11d5906290eba10af694fb9e3e7f9fc208a311dc33ca837eb0'

  def initialize
    super('jq', JQ_VERSION)
    self.files << {
      url: "https://github.com/jqlang/jq/releases/download/jq-#{JQ_VERSION}/jq-#{JQ_VERSION}.tar.gz",
      sha256: JQ_SHA256
    }    
    self.configure_options += [
      # "--enable-shared",
      "--enable-static",
      "--enable-all-static",
      "--disable-maintainer-mode",
      "--with-oniguruma=builtin",  # Use bundled oniguruma
      "CFLAGS=-fPIC -DJQ_VERSION=\\\"#{JQRecipe::JQ_VERSION}\\\"",
    ]
  end

  def configure
    return if configured?

    execute('autoreconf', 'autoreconf -i')
    super
  end
end


recipe = JQRecipe.new
recipe.cook
recipe.activate
recipe.mkmf_config(pkg: 'oniguruma', static: 'onig')
recipe.mkmf_config(pkg: 'libjq', static: 'jq')

# Verify we can link against libjq with a test program
checking_for "ability to link against libjq" do
  # Create a test program that uses core jq functions
  src = <<~SRC
    #include <jv.h>
    #include <jq.h>

    int main(void) {
      // Test that we can link against jq_init, jq_compile, jv_parse, etc.
      jq_state *jq = jq_init();
      if (!jq) return 1;

      // Test basic jv operations (thread-safe in jq 1.7+)
      jv input = jv_parse("{}");
      int valid = jv_is_valid(input);
      jv_free(input);

      jq_teardown(&jq);
      return valid ? 0 : 1;
    }
  SRC

  # Try to link the test program (don't need to run it)
  try_link(src) or abort "Failed to link against libjq"
end

# Add compiler flags
$CFLAGS << " -Wall -Wextra -Wno-unused-parameter -fPIC"

# Enable debug symbols if requested
if ENV['DEBUG']
  $CFLAGS << " -g -O0"
else
  $CFLAGS << " -O2"
end

create_makefile('jq/jq_ext')
