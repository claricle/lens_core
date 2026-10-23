# frozen_string_literal: true

RSpec.describe LensCore::Parsers do
  let(:json) { LensCore::Parsers::Json }
  let(:yaml) { LensCore::Parsers::Yaml }

  %w[xml_report binary_report minimal_report].each do |name|
    describe "fixture #{name}" do
      it "parses from JSON and YAML to the same model" do
        from_json = json.parse(fixture("valid/#{name}.json"))
        from_yaml = yaml.parse(fixture("valid/#{name}.yaml"))

        expect(from_json).to be_a(LensCore::Report)
        expect(from_yaml).to eq(from_json)
      end
    end
  end

  describe "parsed content" do
    subject(:report) { json.parse(fixture("valid/xml_report.json")) }

    it "carries every field of the document" do
      expect(report.producer.name).to eq("example-xml-lens")
      expect(report.profile.citations.map(&:label))
        .to eq(["Example XML Profile 1.0"])
      expect(report.timestamp).to eq(Time.utc(2026, 10, 23, 9, 30))
      expect(report.diagnostics.map(&:severity)).to eq(%w[error warning info])
      expect(report.diagnostics.first.location.to_h)
        .to eq("type" => "xml", "line" => 12, "column" => 5,
               "path" => "/svg/script")
      expect(report.diagnostics.first.remediation)
        .to eq("Remove the <script> element.")
    end

    it "keeps unknown members and kinds" do
      binary = json.parse(fixture("valid/binary_report.json"))

      expect(binary.extensions).to eq("x_trace_id" => "t-1")
      expect(binary.producer.extensions).to eq("build" => "abc123")
      expect(binary.diagnostics.last.extensions).to eq("confidence" => 0.5)
    end
  end

  describe "location coordinates" do
    it "keeps present coordinates and invents none" do
      binary = json.parse(fixture("valid/binary_report.json"))
        .diagnostics.map { |d| d.location.to_h }

      expect(binary).to eq(
        [{ "type" => "binary", "byte_offset" => 0, "byte_length" => 4,
           "record_index" => 0, "record_type" => "HDR" },
         { "type" => "binary", "byte_offset" => 128, "record_index" => 3 }],
      )
      xml = json.parse(fixture("valid/xml_report.json"))
      expect(xml.diagnostics[1].location.to_h)
        .to eq("type" => "xml", "line" => 20, "path" => "/svg/use[1]")
    end
  end

  describe "documented failures" do
    it "raises ParseError for malformed JSON and YAML" do
      expect do
        json.parse(fixture("invalid/malformed.json"))
      end.to raise_error(
        LensCore::ParseError, /malformed JSON/
      )
      expect do
        yaml.parse(fixture("invalid/malformed.yaml"))
      end.to raise_error(
        LensCore::ParseError, /malformed YAML/
      )
    end

    it "raises UnsupportedVersionError for another schema version" do
      expect { json.parse(fixture("invalid/unsupported_version.json")) }
        .to raise_error(LensCore::UnsupportedVersionError, /schema_version 2/)
    end

    it "raises UnsafeYamlError for object tags, symbols and anchors" do
      expect { yaml.parse(fixture("invalid/unsafe_tag.yaml")) }.to raise_error(LensCore::UnsafeYamlError)
      expect do
        yaml.parse(fixture("invalid/unsafe_anchor.yaml"))
      end.to raise_error(LensCore::UnsafeYamlError)
      expect { yaml.parse("schema_version: :one\n") }.to raise_error(LensCore::UnsafeYamlError)
    end

    it "raises InvalidEncodingError for bytes that are not UTF-8" do
      expect do
        json.parse(fixture("invalid/invalid_utf8.json"))
      end.to raise_error(LensCore::InvalidEncodingError)
      expect { yaml.parse("a: \xFF".b) }.to raise_error(LensCore::InvalidEncodingError)
    end

    it "raises InvalidEncodingError for text tagged with another encoding" do
      utf16 = fixture("valid/minimal_report.json").dup
        .force_encoding("UTF-8").encode("UTF-16LE")

      expect do
        json.parse(utf16)
      end.to raise_error(LensCore::InvalidEncodingError, /UTF-16LE/)
    end

    it "raises ParseError for a byte order mark and for non-String input" do
      with_bom = "﻿#{fixture('valid/minimal_report.json')}"

      expect do
        json.parse(with_bom)
      end.to raise_error(LensCore::ParseError, /byte order mark/)
      expect do
        yaml.parse("﻿a: 1")
      end.to raise_error(LensCore::ParseError, /byte order mark/)
      expect { json.parse(nil) }.to raise_error(LensCore::ParseError, /String/)
    end

    it "raises SchemaError for a document that is not an object" do
      ["[]", "null", "3", '"x"'].each do |text|
        expect do
          json.parse(text)
        end.to raise_error(LensCore::SchemaError, /must be an object/)
      end
      expect { yaml.parse("") }.to raise_error(LensCore::SchemaError)
    end

    it "raises SchemaError when the summary disagrees with the diagnostics" do
      expect { json.parse(fixture("invalid/summary_mismatch.json")) }
        .to raise_error(LensCore::SchemaError,
                        /summary\.errors: is 0 but the diagnostics contain 1/)
    end

    it "locates a schema violation by path" do
      doc = fixture_hash("valid/xml_report.json")
      doc["diagnostics"][1]["location"]["line"] = 0

      expect do
        json.parse(JSON.generate(doc))
      end.to raise_error(LensCore::SchemaError) { |e|
               expect(e.path).to eq(["diagnostics", 1,
                                     "location", "line"])
               expect(e.message)
                 .to eq("diagnostics[1].location.line: must be >= 1")
             }
    end

    it "rejects null for an optional member" do
      doc = fixture_hash("valid/xml_report.json")
      doc["diagnostics"][0]["remediation"] = nil

      expect { json.parse(JSON.generate(doc)) }
        .to raise_error(LensCore::SchemaError,
                        /diagnostics\[0\]\.remediation: must not be null/)
    end

    it "keeps every failure under LensCore::Error" do
      [LensCore::ParseError, LensCore::UnsafeYamlError, LensCore::InvalidEncodingError,
       LensCore::UnsupportedVersionError, LensCore::SchemaError].each do |klass|
        expect(klass.ancestors).to include(LensCore::Error)
      end
    end
  end

  describe "YAML timestamps" do
    it "accepts an unquoted RFC 3339 timestamp" do
      text = fixture("valid/xml_report.yaml")
        .sub("'2026-10-23T09:30:00Z'", "2026-10-23T09:30:00Z")

      expect(yaml.parse(text).timestamp).to eq(Time.utc(2026, 10, 23, 9, 30))
    end

    it "does not accept a timestamp-shaped scalar as a string elsewhere" do
      text = fixture("valid/minimal_report.yaml")
        .sub("name: min", "name: 2026-10-23T09:30:00Z")

      expect do
        yaml.parse(text)
      end.to raise_error(LensCore::SchemaError,
                         /producer\.name: must be a string/)
    end
  end

  describe "input flexibility" do
    it "reads binary-tagged strings as UTF-8" do
      text = fixture("valid/xml_report.json")

      expect(text.encoding).to eq(Encoding::BINARY)
      expect(json.parse(text).diagnostics.size).to eq(3)
    end
  end
end
