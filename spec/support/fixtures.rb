# frozen_string_literal: true

require "json"

# Helpers for reading spec/fixtures/v1.
module FixtureHelpers
  FIXTURE_ROOT = File.expand_path("../fixtures/v1", __dir__)

  def fixture_path(name)
    File.join(FIXTURE_ROOT, name)
  end

  # Raw bytes, exactly as stored.
  def fixture(name)
    File.binread(fixture_path(name))
  end

  def fixture_names(dir, ext)
    Dir[File.join(FIXTURE_ROOT, dir, "*.#{ext}")].map do |path|
      File.join(dir, File.basename(path))
    end.sort
  end

  # A fixture report parsed from its .json or .yaml form.
  def load_report(name, ext = "json")
    parser = ext == "json" ? LensCore::Parsers::Json : LensCore::Parsers::Yaml
    parser.parse(fixture("valid/#{name}.#{ext}"))
  end

  # A minimal valid report holding the given diagnostics.
  def build_report(diagnostics = [])
    LensCore::Report.new(
      producer: LensCore::Producer.new(name: "n", version: "1"),
      profile: LensCore::Profile.new(id: "p"),
      valid: diagnostics.none?(&:error?), diagnostics: diagnostics
    )
  end

  # A fresh, mutable copy of a JSON fixture as a Hash.
  def fixture_hash(name)
    JSON.parse(fixture(name))
  end
end

RSpec.configure { |config| config.include FixtureHelpers }
