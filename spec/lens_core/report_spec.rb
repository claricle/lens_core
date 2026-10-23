# frozen_string_literal: true

RSpec.describe LensCore::Report do
  def diagnostic(severity, **options)
    LensCore::Diagnostic.new(
      severity: severity, kind: "example", requirement_id: "R-#{severity}",
      message: "a #{severity}", **options
    )
  end

  def report(diagnostics: [], valid: false, **options)
    described_class.new(
      producer: LensCore::Producer.new(name: "tool", version: "1.2.3"),
      profile: LensCore::Profile.new(id: "profile-1"),
      valid: valid, diagnostics: diagnostics, **options
    )
  end

  describe "versions" do
    it "exposes the gem version and the schema version separately" do
      expect([LensCore::VERSION, LensCore::SCHEMA_VERSION]).to eq(["0.1.0", 1])
      expect(report.schema_version).to eq(1)
    end

    it "has no runtime dependencies and loads in a clean process" do
      gemspec = File.expand_path("../../lens_core.gemspec", __dir__)
      lib = File.expand_path("../../lib", __dir__)
      script = 'require "lens_core"; print LensCore::SCHEMA_VERSION'
      output = IO.popen(
        ["ruby", "--disable=gems", "-I", lib, "-e", script],
        err: %i[child out], &:read
      )

      expect(Gem::Specification.load(gemspec).runtime_dependencies).to be_empty
      expect(output).to eq("1")
    end
  end

  describe "#summary" do
    it "counts diagnostics by severity" do
      list = %w[error info error warning].map { |s| diagnostic(s) }

      expect(report(diagnostics: list).summary)
        .to eq("errors" => 2, "warnings" => 1, "infos" => 1)
    end

    it "is zero for an empty report" do
      expect(report(valid: true).summary)
        .to eq("errors" => 0, "warnings" => 0, "infos" => 0)
    end
  end

  describe "ordering" do
    it "keeps diagnostics in input order" do
      list = %w[info error warning error].map { |s| diagnostic(s) }
      severities = report(diagnostics: list).to_h["diagnostics"]
        .map { |d| d["severity"] }

      expect(severities).to eq(%w[info error warning error])
    end

    it "emits standard members in schema order, then sorted extensions" do
      r = report(timestamp: "2026-01-02T03:04:05Z",
                 extensions: { "zeta" => 1, "alpha" => 2 })

      expect(r.to_h.keys).to eq(
        %w[schema_version producer profile timestamp valid summary diagnostics
           alpha zeta],
      )
    end

    it "sorts context keys lexically at every depth" do
      context = { "b" => 1,
                  "a" => { "d" => 1, "c" => [{ "y" => 1, "x" => 2 }] } }
      d = diagnostic("info", context: context)

      expect(JSON.generate(d.context))
        .to eq('{"a":{"c":[{"x":2,"y":1}],"d":1},"b":1}')
    end
  end

  describe "timestamp" do
    it "is omitted unless the caller supplies one" do
      expect(report.timestamp).to be_nil
      expect(report.to_h).not_to have_key("timestamp")
    end

    it "is rendered as UTC, keeping sub-second digits only when present" do
      offset = Time.new(2026, 10, 23, 12, 0, 0, "+02:00")

      expect(report(timestamp: offset).to_h["timestamp"])
        .to eq("2026-10-23T10:00:00Z")
      expect(report(timestamp: "2026-10-23T10:00:00.250+00:00").to_h)
        .to include("timestamp" => "2026-10-23T10:00:00.25Z")
    end

    it "rejects text that is not an RFC 3339 timestamp with an offset" do
      ["yesterday", "2026-10-23", "2026-10-23T10:00:00",
       "2026-13-40T10:00:00Z", 5].each do |bad|
        expect { report(timestamp: bad) }
          .to raise_error(LensCore::SchemaError, /timestamp/)
      end
    end
  end

  describe "validity" do
    it "cannot be true while an error is present" do
      expect { report(valid: true, diagnostics: [diagnostic("error")]) }
        .to raise_error(LensCore::SchemaError, /valid: cannot be true/)
    end

    it "is the producer's call when only warnings exist" do
      warnings = [diagnostic("warning")]

      expect([true, false].map do |v|
        report(valid: v, diagnostics: warnings).valid
      end)
        .to eq([true, false])
    end
  end

  describe LensCore::Location do
    it "keeps only the coordinates it was given" do
      expect(described_class.xml(line: 3, path: "/svg").to_h)
        .to eq("type" => "xml", "line" => 3, "path" => "/svg")
      expect(described_class.binary(byte_offset: 0).to_h)
        .to eq("type" => "binary", "byte_offset" => 0)
      expect(described_class.xml.to_h).to eq("type" => "xml")
    end

    it "keeps a legitimate zero instead of treating it as absent" do
      location = described_class.binary(byte_offset: 0, record_index: 0)

      expect(location.to_h.values_at("byte_offset", "record_index"))
        .to eq([0, 0])
    end

    it "rejects coordinates of the other type" do
      expect { described_class.new(type: "xml", byte_offset: 1) }
        .to raise_error(LensCore::SchemaError, /byte_offset/)
    end

    it "rejects out-of-range values and unknown types" do
      expect { described_class.xml(line: 0) }
        .to raise_error(LensCore::SchemaError, /line: must be >= 1/)
      expect { described_class.binary(byte_length: -1) }
        .to raise_error(LensCore::SchemaError, /byte_length/)
      expect { described_class.new(type: "svg") }
        .to raise_error(LensCore::SchemaError, /type: must be one of/)
    end
  end

  describe LensCore::Citation do
    it "requires an absolute URI" do
      expect { described_class.new(uri: "spec/section-1") }
        .to raise_error(LensCore::SchemaError, /absolute URI/)
      expect { described_class.new(uri: "urn:iso:std:iso:8601") }
        .not_to raise_error
    end
  end

  describe LensCore::Diagnostic do
    it "accepts kinds it has never heard of" do
      expect(diagnostic("info", kind: "brand_new_kind").kind)
        .to eq("brand_new_kind")
    end

    it "rejects a severity outside error, warning and info" do
      expect { diagnostic("fatal") }
        .to raise_error(LensCore::SchemaError, /severity: must be one of/)
    end

    it "accepts severity as a symbol" do
      expect(diagnostic(:warning).severity).to eq("warning")
    end

    it "rejects context that JSON cannot carry" do
      [{ "f" => Float::NAN }, { "o" => Object.new }, { 1 => "x" },
       { "s" => :sym }].each do |bad|
        expect { diagnostic("info", context: bad) }
          .to raise_error(LensCore::SchemaError)
      end
    end

    it "rejects text that is not UTF-8" do
      latin1 = (+"caf\xE9").force_encoding("ISO-8859-1")

      expect { diagnostic("info", message: latin1) }
        .to raise_error(LensCore::InvalidEncodingError)
    end

    it "rejects an extension that shadows a standard member" do
      expect { diagnostic("info", extensions: { "message" => "x" }) }
        .to raise_error(LensCore::SchemaError, /standard member/)
    end
  end

  describe "value semantics" do
    it "is immutable and compares by content" do
      a = report(diagnostics: [diagnostic("info")])
      b = report(diagnostics: [diagnostic("info")])

      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
      expect(a).to be_frozen
      expect(a.diagnostics).to be_frozen
    end
  end
end
