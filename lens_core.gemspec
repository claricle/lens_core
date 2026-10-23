# frozen_string_literal: true

require_relative "lib/lens_core/version"

all_files_in_git = Dir.chdir(File.expand_path(__dir__)) do
  `git ls-files -z`.split("\x0")
end

Gem::Specification.new do |spec|
  spec.name = "lens_core"
  spec.version = LensCore::VERSION
  spec.authors = ["Ribose"]
  spec.email = ["open.source@ribose.com"]

  spec.summary = "Format-neutral conformance diagnostics model and renderers."
  spec.description = "One diagnostics report shape (schema version 1) " \
                     "that any format checker can emit, with JSON and " \
                     "YAML parsers and JSON, YAML and human-readable " \
                     "renderers. No runtime dependencies."
  spec.homepage = "https://github.com/claricle/lens_core"
  spec.license = "BSD-2-Clause"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.1.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = all_files_in_git
    .reject { |f| f.match(%r{\A(?:(?:test|spec|features|bin|script)/|\.)}) }
  spec.require_paths = ["lib"]
end
