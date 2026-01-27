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

# Detect the version of libjq we'll actually link against
#
# IMPORTANT: We can ONLY trust pkg-config here. The jq binary in PATH could be
# from a completely different installation than the libjq library we're linking
# against. For example:
#   - /usr/local/bin/jq could be version 1.8.1
#   - /usr/lib/libjq.so could be version 1.6
#   - We'd link against 1.6 but report 1.8.1 (wrong!)
#
# pkg-config tells us about the actual library that will be linked.
#
# If pkg-config is not available:
#   - We cannot reliably determine the version
#   - For miniportile builds, we know the version (we build it ourselves)
#   - For system libraries, we warn the user
def check_jq_version
  version = `pkg-config --modversion libjq 2>/dev/null`.strip

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

    $building_from_source = true
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
# Note: We can only reliably detect the version via pkg-config, which tells us
# about the actual library we'll link against. The jq binary in PATH could be
# from a completely different installation.
version = check_jq_version
version_source = version ? "pkg-config" : "unknown"

if version
  version_str = version.join('.')
  puts "Found libjq version #{version_str} (via #{version_source})"

  unless version_meets_minimum?(version, MINIMUM_JQ_VERSION)
    abort <<~ERROR
      ================================================================================
      ERROR: libjq version #{version_str} is too old.

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
else
  # We couldn't detect the version (no pkg-config available)
  # This is common when using manual library installations
  if use_system_libraries
    puts "WARNING: Could not detect libjq version (pkg-config not available)."
    puts "         Make sure you have libjq 1.7.0 or newer installed."
    puts "         This gem requires jq 1.7+ for thread-safe operation."
  else
    # If we're using miniportile, we know we're building 1.8.1
    if $building_from_source && defined?(JQRecipe)
      puts "Building jq #{JQRecipe::JQ_VERSION} from source (pkg-config not available)"
    end
  end
end

# Verify we can actually link and run against libjq
unless verify_linked_jq_version
  abort "Failed to link against libjq. Please check your jq installation."
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
