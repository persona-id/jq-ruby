# frozen_string_literal: true

require 'mini_portile2'

class JQRecipe < MiniPortile
  JQ_VERSION = '1.7.1'
  JQ_SHA256 = '478c9ca129fd2e3443fe27314b455e211e0d8c60bc8ff7df703873deeee580c2'

  def initialize
    super('jq', JQ_VERSION)
    @files << {
      url: "https://github.com/jqlang/jq/releases/download/jq-#{JQ_VERSION}/jq-#{JQ_VERSION}.tar.gz",
      sha256: JQ_SHA256
    }
    @target = File.join(Dir.pwd, "ports")
  end

  def configure_options
    [
      "--disable-maintainer-mode",
      "--disable-docs",
      "--with-oniguruma=builtin"  # Use bundled oniguruma
    ]
  end

  def configured?
    File.exist?(File.join(work_path, 'Makefile'))
  end

  def compile
    execute('compile', ['make', '-j', ENV.fetch('MAKEFLAGS', '4')])
  end
end
