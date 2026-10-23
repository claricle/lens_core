# frozen_string_literal: true

RSpec.describe LensCore::Renderers do
  let(:json) { LensCore::Renderers::Json }
  let(:yaml) { LensCore::Renderers::Yaml }
  let(:human) { LensCore::Renderers::Human }

  %w[xml_report binary_report minimal_report].each do |name|
    describe "fixture #{name}" do
      let(:report) { load_report(name) }

      it "round-trips canonical JSON byte for byte" do
        expect(json.render(report).b).to eq(fixture("valid/#{name}.json"))
      end

      it "renders YAML that parses back to the same report, byte-stably" do
        text = yaml.render(report)

        expect(text.b).to eq(fixture("valid/#{name}.yaml"))
        expect(LensCore::Parsers::Yaml.parse(text)).to eq(report)
      end

      it "renders the human form shown in the fixture" do
        expect(human.render(report).b).to eq(fixture("valid/#{name}.txt"))
      end
    end
  end

  describe "all severities" do
    let(:report) { load_report("xml_report") }

    it "appear in every renderer, in input order" do
      {
        "json" => json.render(report).scan(/"severity": "(\w+)"/),
        "yaml" => yaml.render(report).scan(/severity: (\w+)/),
        "human" => human.render(report).scan(/^(error|warning|info)  /),
      }.each_value do |order|
        expect(order.flatten).to eq(%w[error warning info])
      end
    end

    it "gives the human summary line the derived counts" do
      expect(human.render(report))
        .to include("INVALID: 1 error, 1 warning, 1 info")
    end
  end

  describe "determinism" do
    it "renders the same bytes for equal reports built in different ways" do
      from_json = load_report("binary_report")
      from_yaml = load_report("binary_report", "yaml")

      expect([json, yaml, human].map { |r| r.render(from_json) })
        .to eq([json, yaml, human].map { |r| r.render(from_yaml) })
    end

    it "emits extension keys lexically regardless of input order" do
      doc = fixture_hash("valid/minimal_report.json")
        .merge("zz" => 1, "aa" => { "y" => 1, "b" => 2 })
      rendered = json.render(LensCore::Parsers::Json.parse(JSON.generate(doc)))

      expect(JSON.parse(rendered).keys.last(2)).to eq(%w[aa zz])
      expect(rendered).to include(%("aa": {\n    "b": 2,\n    "y": 1\n  }))
    end

    it "shows a timestamp only when the report carries one" do
      stamped = [json, yaml, human].map do |r|
        r.render(load_report("xml_report")).include?("2026-10-23T09:30:00Z")
      end
      bare = [json, yaml, human].map do |r|
        r.render(load_report("binary_report"))
      end

      expect(stamped).to all(be(true))
      expect(bare.join).not_to match(/timestamp|Checked at/)
    end
  end

  describe "locations" do
    it "survives parse and render with present coordinates only" do
      %w[xml_report binary_report].each do |name|
        original = fixture_hash("valid/#{name}.json")
        rendered = JSON.parse(json.render(load_report(name, "yaml")))

        expect(rendered["diagnostics"].filter_map { |d| d["location"] })
          .to eq(original["diagnostics"].filter_map { |d| d["location"] })
      end
    end

    it "does not write a coordinate into a location that lacked it" do
      text = human.render(load_report("binary_report"))

      expect(text).to include("at byte offset 128, record 3\n")
      expect(text).not_to include("length 0")
    end

    it "renders a coordinate-free location honestly" do
      diagnostic = LensCore::Diagnostic.new(
        severity: "info", kind: "k", requirement_id: "R", message: "m",
        location: LensCore::Location.binary
      )

      expect(human.render(build_report([diagnostic])))
        .to include("at (binary, no coordinates)")
    end
  end

  describe "text" do
    let(:message) { "café — \"quoted\" # not a comment: yes\nsecond line" }
    let(:report) do
      build_report([LensCore::Diagnostic.new(
        severity: "warning", kind: "k", requirement_id: "R", message: message,
      )])
    end

    it "keeps non-ASCII text and special characters through JSON and YAML" do
      from_json = LensCore::Parsers::Json.parse(json.render(report))
      from_yaml = LensCore::Parsers::Yaml.parse(yaml.render(report))

      expect([from_json, from_yaml].map { |r| r.diagnostics.first.message })
        .to eq([message, message])
    end

    it "indents every line of a multi-line message in the human form" do
      expect(human.render(report))
        .to include("  café — \"quoted\" # not a comment: yes\n  second line\n")
    end
  end
end
