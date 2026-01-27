# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rake/extensiontask"

RSpec::Core::RakeTask.new(:spec)

Rake::ExtensionTask.new("jq_ext") do |ext|
  ext.ext_dir = "ext/jq"
  ext.lib_dir = "lib/jq"
end

task spec: :compile
task default: :spec
