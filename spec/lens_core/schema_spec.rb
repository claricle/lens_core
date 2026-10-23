# frozen_string_literal: true

require "json_schemer"

RSpec.describe LensCore::Schema do
  describe "schemas/lens-diagnostics-v1.json" do
    let(:schema_hash) { described_class.document }
    let(:schemer) { JSONSchemer.schema(schema_hash) }

    def ruby_accepts?(document)
      LensCore::Parsers::Json.parse(JSON.generate(document))
      true
    rescue LensCore::Error
      false
    end

    def base
      fixture_hash("valid/xml_report.json")
    end

    def with(&block)
      base.tap(&block)
    end

    describe "versions" do
      it "declares the same schema version as the Ruby model" do
        expect(schema_hash.dig("properties", "schema_version", "const"))
          .to eq(LensCore::SCHEMA_VERSION)
        expect(described_class.version).to eq(LensCore::SCHEMA_VERSION)
      end

      it "is a valid JSON Schema" do
        expect(JSONSchemer.valid_schema?(schema_hash)).to be(true)
      end
    end

    describe "required members" do
      it "match the Ruby model" do
        defs = schema_hash["$defs"]

        expect(schema_hash["required"])
          .to match_array(LensCore::Report::MEMBERS - ["timestamp"])
        expect(defs.dig("diagnostic",
                        "required")).to match_array(%w[severity kind
                                                       requirement_id message])
        expect(defs.dig("diagnostic", "properties").keys).to eq(LensCore::Diagnostic::MEMBERS)
        expect(defs.dig("citation", "required")).to eq(["uri"])
        expect(defs.dig("producer", "required")).to match_array(LensCore::Producer::MEMBERS)
        expect(defs.dig("profile", "required")).to match_array(LensCore::Profile::MEMBERS)
        expect(defs.dig("diagnostic", "properties", "severity", "enum")).to eq(LensCore::Diagnostic::SEVERITIES)
        expect(defs.dig("location", "properties", "type", "enum")).to eq(LensCore::Location::TYPES)
      end

      it "list the same coordinates per location type as the Ruby model" do
        branches = schema_hash.dig("$defs", "location", "allOf").map do |b|
          b["then"]["properties"]
        end

        LensCore::Location::FIELDS.each_value.zip(branches) do |fields, props|
          expect(props.select { |_, v| v.is_a?(Hash) }.keys).to eq(fields)
        end
      end
    end

    describe "fixtures" do
      it "accepts every valid fixture, which Ruby also parses" do
        names = fixture_names("valid", "json")

        expect(names.size).to be >= 3
        names.each do |name|
          expect(schemer.validate(fixture_hash(name)).to_a).to be_empty
          expect(ruby_accepts?(fixture_hash(name))).to be(true)
        end
      end

      it "rejects the unsupported-version fixture, which Ruby also rejects" do
        document = fixture_hash("invalid/unsupported_version.json")

        expect(schemer.valid?(document)).to be(false)
        expect(ruby_accepts?(document)).to be(false)
      end
    end

    describe "agreement between schema and Ruby" do
      rejected = {
        "missing schema_version" => ->(d) { d.delete("schema_version") },
        "missing producer" => ->(d) { d.delete("producer") },
        "missing profile" => ->(d) { d.delete("profile") },
        "missing valid" => ->(d) { d.delete("valid") },
        "missing summary" => ->(d) { d.delete("summary") },
        "missing diagnostics" => ->(d) { d.delete("diagnostics") },
        "unsupported schema_version" => ->(d) { d["schema_version"] = 2 },
        "string schema_version" => ->(d) { d["schema_version"] = "1" },
        "non-boolean valid" => ->(d) { d["valid"] = "no" },
        "valid with errors" => ->(d) { d["valid"] = true },
        "negative summary count" => ->(d) { d["summary"]["warnings"] = -1 },
        "producer without version" => ->(d) { d["producer"].delete("version") },
        "empty producer name" => ->(d) { d["producer"]["name"] = "" },
        "profile without citations" => ->(d) {
          d["profile"].delete("citations")
        },
        "relative citation uri" => ->(d) {
          d["profile"]["citations"][0]["uri"] = "spec/1.0"
        },
        "citation without uri" => ->(d) {
          d["profile"]["citations"][0].delete("uri")
        },
        "empty citation label" => ->(d) {
          d["profile"]["citations"][0]["label"] = ""
        },
        "bad timestamp" => ->(d) { d["timestamp"] = "yesterday" },
        "timestamp without offset" => ->(d) {
          d["timestamp"] = "2026-10-23T09:30:00"
        },
        "impossible calendar date" => ->(d) {
          d["timestamp"] = "2026-02-29T10:00:00Z"
        },
        "hour 24" => ->(d) { d["timestamp"] = "2026-10-23T24:00:00Z" },
        "diagnostics not an array" => ->(d) { d["diagnostics"] = {} },
        "unknown severity" => ->(d) {
          d["diagnostics"][0]["severity"] = "fatal"
        },
        "missing kind" => ->(d) { d["diagnostics"][0].delete("kind") },
        "missing requirement_id" => ->(d) {
          d["diagnostics"][0].delete("requirement_id")
        },
        "empty message" => ->(d) { d["diagnostics"][0]["message"] = "" },
        "null remediation" => ->(d) {
          d["diagnostics"][0]["remediation"] = nil
        },
        "array context" => ->(d) { d["diagnostics"][0]["context"] = [] },
        "null location" => ->(d) { d["diagnostics"][0]["location"] = nil },
        "location without type" => ->(d) {
          d["diagnostics"][0]["location"].delete("type")
        },
        "unknown location type" => ->(d) {
          d["diagnostics"][0]["location"]["type"] = "json"
        },
        "zero line" => ->(d) { d["diagnostics"][0]["location"]["line"] = 0 },
        "string column" => ->(d) {
          d["diagnostics"][0]["location"]["column"] = "5"
        },
        "binary field on xml location" => ->(d) {
          d["diagnostics"][0]["location"]["byte_offset"] = 1
        },
        "xml field on binary location" => lambda { |d|
          d["diagnostics"][0]["location"] = { "type" => "binary", "line" => 1 }
        },
        "negative byte_offset" => lambda { |d|
          d["diagnostics"][0]["location"] =
            { "type" => "binary", "byte_offset" => -1 }
        },
      }

      accepted = {
        "unchanged" => ->(_d) {},
        "unknown top-level member" => ->(d) {
          d["x_note"] = { "any" => [1, nil] }
        },
        "unknown producer member" => ->(d) { d["producer"]["build"] = "abc" },
        "unknown profile member" => ->(d) { d["profile"]["owner"] = "me" },
        "unknown citation member" => ->(d) {
          d["profile"]["citations"][0]["page"] = 4
        },
        "unknown diagnostic member" => ->(d) {
          d["diagnostics"][0]["confidence"] = 0.5
        },
        "unknown location member" => ->(d) {
          d["diagnostics"][0]["location"]["offset_hint"] = 3
        },
        "unknown diagnostic kind" => ->(d) {
          d["diagnostics"][0]["kind"] = "never_seen_before"
        },
        "unknown summary member" => ->(d) { d["summary"]["total"] = 3 },
        "no timestamp" => ->(d) { d.delete("timestamp") },
        "offset timestamp" => ->(d) {
          d["timestamp"] = "2026-10-23T11:30:00.5+02:00"
        },
        "no diagnostics" => lambda { |d|
          d["diagnostics"] = []
          d["summary"] = { "errors" => 0, "warnings" => 0, "infos" => 0 }
          d["valid"] = true
        },
        "invalid without errors" => lambda { |d|
          d["diagnostics"].shift
          d["summary"]["errors"] = 0
        },
        "bare xml location" => ->(d) {
          d["diagnostics"][0]["location"] = { "type" => "xml" }
        },
        "bare binary location" => ->(d) {
          d["diagnostics"][0]["location"] = { "type" => "binary" }
        },
        "zero byte_offset" => lambda { |d|
          d["diagnostics"][0]["location"] =
            { "type" => "binary", "byte_offset" => 0, "record_index" => 0 }
        },
        "nested context" => ->(d) {
          d["diagnostics"][0]["context"] =
            { "a" => { "b" => [1, "two", nil, true, 1.5] } }
        },
        "non-ASCII text" => ->(d) { d["diagnostics"][0]["message"] = "café ☃" },
      }

      rejected.each do |name, change|
        it "both reject: #{name}" do
          document = with(&change)

          expect(schemer.valid?(document)).to be(false)
          expect(ruby_accepts?(document)).to be(false)
        end
      end

      accepted.each do |name, change|
        it "both accept: #{name}" do
          document = with(&change)

          expect(schemer.valid?(document)).to be(true)
          expect(ruby_accepts?(document)).to be(true)
        end
      end

      it "leaves summary arithmetic to Ruby (JSON Schema cannot count)" do
        document = with { |d| d["summary"]["errors"] = 5 }

        expect(schemer.valid?(document)).to be(true)
        expect(ruby_accepts?(document)).to be(false)
      end

      it "refuses 3.0 where schema validators read an integer" do
        document = with { |d| d["diagnostics"][0]["location"]["line"] = 3.0 }

        expect(schemer.valid?(document)).to be(true)
        expect(ruby_accepts?(document)).to be(false)
      end
    end
  end
end
