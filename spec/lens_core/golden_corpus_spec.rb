# frozen_string_literal: true

require "json_schemer"

RSpec.describe "golden corpus" do # rubocop:disable RSpec/DescribeClass
  let(:schemer) { JSONSchemer.schema(LensCore::Schema.document) }
  let(:json) { LensCore::Renderers::Json }
  let(:svg_names) do
    %w[svg-1.1-invalid-grammar.json svg-2-external-reference.json
       svg-four-channel-library.json]
  end

  describe "manifest" do
    it "pins the schema by SHA-256 and names the contract commit" do
      schema = golden_manifest.fetch("schema")

      expect(sha256(File.binread(LensCore::Schema::PATH)))
        .to eq(schema["sha256"])
      expect(schema["schema_version"]).to eq(LensCore::SCHEMA_VERSION)
      expect(schema["lens_core_contract_commit"]).to match(/\A\h{40}\z/)
    end

    it "lists exactly the golden files on disk" do
      root = GoldenHelpers::GOLDEN_ROOT
      on_disk = Dir[File.join(root, "**", "*.json")].map do |path|
        path.delete_prefix("#{root}/")
      end

      expect(golden_entries.map { |e| e["path"] }).to match_array(on_disk)
      expect(golden_entries.map { |e| File.basename(e["path"]) })
        .to include(*svg_names, "xml-location.json", "binary-location.json")
    end

    it "records provenance for every entry and a producer commit for SVG" do
      golden_entries.each do |entry|
        expect(entry.values_at("sha256", "producer", "producer_version",
                               "source", "schema_version")).to all(be_truthy)
        expect(entry["lens_core_contract_commit"]).to match(/\A\h{40}\z/)
      end
      svg, other = golden_entries.partition do |e|
        e["producer"] == "svg_conform"
      end
      expect(svg.map { |e| e["svg_conform_commit"] }.uniq.size).to eq(1)
      expect(svg.first["svg_conform_commit"]).to match(/\A\h{40}\z/)
      expect(other.map { |e| e["svg_conform_commit"] }).to all(be_nil)
    end
  end

  describe "every golden" do
    it "matches its recorded SHA-256" do
      golden_entries.each do |entry|
        expect(sha256(golden_bytes(entry))).to eq(entry["sha256"])
      end
    end

    it "validates against the v1 schema" do
      golden_entries.each do |entry|
        errors = schemer.validate(JSON.parse(golden_bytes(entry))).to_a
        expect(errors).to eq([])
      end
    end

    it "parses and renders back to the input bytes" do
      golden_entries.each do |entry|
        bytes = golden_bytes(entry)

        expect(json.render(golden_report(entry)).b).to eq(bytes)
      end
    end

    it "omits timestamps and has summary counts equal to its diagnostics" do
      golden_entries.each do |entry|
        report = golden_report(entry)
        counts = report.diagnostics.map(&:severity).tally

        expect(report.timestamp).to be_nil
        expect(JSON.parse(golden_bytes(entry))).not_to have_key("timestamp")
        expect(report.summary).to eq(
          "errors" => counts.fetch("error", 0),
          "warnings" => counts.fetch("warning", 0),
          "infos" => counts.fetch("info", 0),
        )
      end
    end
  end

  describe "svg_conform exports" do
    it "keeps profile, citation, remediation and context on the error" do
      report = golden_report(entry_named("svg-1.1-invalid-grammar.json"))
      diagnostic = report.diagnostics.first

      expect(report.profile.id).to eq("svg_1_1_full_static")
      expect(report.profile.citations.map(&:uri))
        .to eq(["https://www.w3.org/TR/2011/REC-SVG11-20110816/"])
      expect(diagnostic.requirement_id).to eq("svg11.document.css2")
      expect(diagnostic.citations.map(&:uri))
        .to eq(["https://www.w3.org/TR/2008/REC-CSS2-20080411/grammar.html"])
      expect(diagnostic.remediation).to be_a(String)
      expect(diagnostic.context).to include("remediation_type" => "promote",
                                            "data" => a_hash_including(
                                              "line" => 3,
                                            ))
    end

    it "keeps the external reference reason, citation and element" do
      report = golden_report(entry_named("svg-2-external-reference.json"))
      diagnostic = report.diagnostics.first

      expect(report.valid).to be(false)
      expect(diagnostic.requirement_id)
        .to eq("svg2.secure_static.external_reference")
      expect(diagnostic.citations.first.uri).to end_with("#secure-static-mode")
      expect(diagnostic.context).to include(
        "element" => "image",
        "data" => a_hash_including(
          "reason" => "network resource is not allowed",
        ),
      )
    end

    it "retains the error, validity error, warning and info channels" do
      report = golden_report(entry_named("svg-four-channel-library.json"))

      expect(report.diagnostics.map { |d| [d.severity, d.kind] }).to eq(
        [%w[error validation], %w[error validity],
         %w[warning validation], %w[info notice]],
      )
      expect(report.summary).to eq("errors" => 2, "warnings" => 1, "infos" => 1)
      expect(report.valid).to be(false)
      expect(report.diagnostics.map { |d| d.location.type }.uniq).to eq(["xml"])
      expect(report.diagnostics.first.location.coordinates)
        .to eq("line" => 3, "column" => 5, "path" => "/svg/rect[1]")
    end
  end

  describe "format-neutral location examples" do
    it "carry xml coordinates and binary coordinates, with partial binary" do
      xml = golden_report(entry_named("xml-location.json"))
      binary = golden_report(entry_named("binary-location.json"))

      expect(xml.diagnostics.first.location.coordinates)
        .to eq("line" => 12, "column" => 4, "path" => "/root/item[2]")
      expect(binary.diagnostics.map { |d| d.location.coordinates }).to eq(
        [{ "byte_offset" => 64, "byte_length" => 4, "record_index" => 2,
           "record_type" => "HDR" }, { "byte_offset" => 128 }],
      )
    end
  end
end
