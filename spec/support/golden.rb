# frozen_string_literal: true

require "yaml"
require "digest"

# Helpers for the pinned golden corpus in spec/fixtures/v1/golden.
module GoldenHelpers
  GOLDEN_ROOT = File.expand_path("../fixtures/v1/golden", __dir__)
  REPO_ROOT = File.expand_path("../..", __dir__)

  def golden_manifest
    @golden_manifest ||= YAML.safe_load_file(File.join(GOLDEN_ROOT,
                                                       "manifest.yml"))
  end

  def golden_entries
    golden_manifest.fetch("goldens")
  end

  def entry_named(name)
    golden_entries.find { |e| File.basename(e["path"]) == name }
  end

  def golden_bytes(entry)
    File.binread(File.join(GOLDEN_ROOT, entry["path"]))
  end

  def golden_report(entry)
    LensCore::Parsers::Json.parse(golden_bytes(entry))
  end

  def sha256(bytes)
    Digest::SHA256.hexdigest(bytes)
  end
end

RSpec.configure { |config| config.include GoldenHelpers }
