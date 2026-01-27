# frozen_string_literal: true

require 'mini_portile2'

class JQRecipe < MiniPortile
  JQ_VERSION = '1.8.1'
  JQ_SHA256 = '2be64e7129cecb11d5906290eba10af694fb9e3e7f9fc208a311dc33ca837eb0'

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
