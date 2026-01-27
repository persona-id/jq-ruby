# frozen_string_literal: true

require 'mkmf'

# Minimum required jq version for thread safety (PR #2546)
MINIMUM_JQ_VERSION = '1.7.0'

# Check for --use-system-libraries flag or env var
use_system_libraries = enable_config('use-system-libraries',
                                     ENV['JQ_USE_SYSTEM_LIBRARIES'])

def have_system_jq?
  # Try pkg-config first
  return true if pkg_config('libjq')

  # Fallback to manual detection
  have_library('jq', 'jq_init') &&
    have_header('jq.h') &&
    have_header('jv.h')
end

def check_jq_version
  # Try pkg-config first
  version = `pkg-config --modversion libjq 2>/dev/null`.strip

  # If pkg-config doesn't work, try jq binary
  if version.empty?
    jq_output = `jq --version 2>/dev/null`.strip
    version = jq_output[/jq[- ](\d+\.\d+(?:\.\d+)?)/, 1]
  end

  # If we still don't have a version, try to parse from jq.h
  if version.empty? || version.nil?
    jq_h_path = find_header('jq.h')
    if jq_h_path
      jq_h_content = File.read(jq_h_path)
      if jq_h_content =~ /JQ_VERSION\s+"([^"]+)"/
        version = $1
      end
    end
  end

  return nil if version.nil? || version.empty?

  # Parse version
  version_parts = version.split('.').map(&:to_i)
  [version_parts[0] || 0, version_parts[1] || 0, version_parts[2] || 0]
end

def version_meets_minimum?(version, minimum)
  return false if version.nil?

  min_parts = minimum.split('.').map(&:to_i)

  version.each_with_index do |part, i|
    min_part = min_parts[i] || 0
    return true if part > min_part
    return false if part < min_part
  end

  true # Equal
end

if use_system_libraries
  abort "System jq not found" unless have_system_jq?
else
  # Try system first, fall back to miniportile
  unless have_system_jq?
    require 'mini_portile2'
    require_relative 'recipes/jq_recipe'

    recipe = JQRecipe.new
    recipe.cook
    recipe.activate

    abort "Failed to build jq" unless have_library('jq', 'jq_init')
  end
end

# Verify we can link against libjq with a test program
def verify_linked_jq_version
  checking_for "ability to link against libjq" do
    # Create a test program that uses core jq functions
    src = <<-SRC
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
    try_link(src)
  end
end

# Check jq version for thread safety
version = check_jq_version
if version
  version_str = version.join('.')
  puts "Found jq version: #{version_str}"

  unless version_meets_minimum?(version, MINIMUM_JQ_VERSION)
    abort <<~ERROR
      ================================================================================
      ERROR: jq version #{version_str} is too old.

      This gem requires jq #{MINIMUM_JQ_VERSION} or newer for thread-safe operation.
      jq 1.7+ includes a critical fix (PR #2546) for multi-threaded environments.

      Please upgrade jq:
        macOS:         brew upgrade jq
        Ubuntu/Debian: apt-get install libjq-dev
        Fedora/RHEL:   yum install jq-devel

      Or let the gem build jq from source:
        gem install jq  # (without --use-system-libraries)
      ================================================================================
    ERROR
  end

  # Verify we can actually link and run against libjq
  unless verify_linked_jq_version
    abort "Failed to link against libjq or runtime test failed. Please check your jq installation."
  end
else
  puts "WARNING: Could not detect jq version. Proceeding with build, but jq 1.7+ is required for thread safety."

  # Still try to verify linking works
  unless verify_linked_jq_version
    abort "Failed to link against libjq or runtime test failed. Please check your jq installation."
  end
end

# Add compiler flags
$CFLAGS << " -Wall -Wextra -Wno-unused-parameter"

# Enable debug symbols if requested
if ENV['DEBUG']
  $CFLAGS << " -g -O0"
else
  $CFLAGS << " -O2"
end

create_makefile('jq/jq_ext')
