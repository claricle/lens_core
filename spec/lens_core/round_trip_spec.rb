# frozen_string_literal: true

RSpec.describe "canonical round trips" do # rubocop:disable RSpec/DescribeClass
  let(:json) { LensCore::Renderers::Json }
  let(:yaml) { LensCore::Renderers::Yaml }
  let(:json_parser) { LensCore::Parsers::Json }
  let(:yaml_parser) { LensCore::Parsers::Yaml }

  def corpus
    fixture_names("valid", "json").map { |n| fixture(n) } +
      golden_entries.map { |e| golden_bytes(e) }
  end

  it "covers the valid fixtures and every golden" do
    expect(corpus.size).to eq(fixture_names("valid", "json").size +
                              golden_entries.size)
    expect(corpus.size).to be >= 8
  end

  it "renders canonical JSON byte for byte after parsing it" do
    corpus.each do |bytes|
      expect(json.render(json_parser.parse(bytes)).b).to eq(bytes)
    end
  end

  it "keeps the value through JSON and YAML in either order" do
    corpus.each do |bytes|
      report = json_parser.parse(bytes)
      via_yaml = yaml_parser.parse(yaml.render(report))

      expect(via_yaml).to eq(report)
      expect(json.render(via_yaml).b).to eq(bytes)
      expect(yaml.render(json_parser.parse(json.render(via_yaml))))
        .to eq(yaml.render(report))
    end
  end

  it "renders the same bytes however a report was built" do
    built = LensCore::Report.new(
      producer: LensCore::Producer.new(name: "p", version: "1"),
      profile: LensCore::Profile.new(id: "x"),
      valid: false,
      diagnostics: [LensCore::Diagnostic.new(
        severity: "error", kind: "k", requirement_id: "R-1", message: "m",
        location: LensCore::Location.binary(byte_offset: 3,
                                            record_type: "T")
      )],
    )
    text = json.render(built)

    expect(json_parser.parse(text)).to eq(built)
    expect(json.render(json_parser.parse(text))).to eq(text)
    expect(text).to end_with("}\n")
  end

  it "preserves extension members through the round trip" do
    bytes = fixture("valid/binary_report.json")
    report = json_parser.parse(bytes)

    expect(report.extensions).to eq("x_trace_id" => "t-1")
    expect(json.render(report).b).to eq(bytes)
  end
end
