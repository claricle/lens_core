# frozen_string_literal: true

require "open3"
require "tmpdir"
require "bundler"

RSpec.describe "host application using LensCore alone" do # rubocop:disable RSpec/DescribeClass
  let(:app) { File.join(GoldenHelpers::REPO_ROOT, "spec/fixtures/host_app") }
  let(:output) do
    out, err, status = run_in_host("exec", "ruby", "read_reports.rb",
                                   GoldenHelpers::GOLDEN_ROOT)
    raise "host app failed: #{err}" unless status.success?

    out
  end

  def run_in_host(*command)
    Bundler.with_unbundled_env do
      Open3.capture3({ "BUNDLE_GEMFILE" => File.join(app, "Gemfile") },
                     "bundle", *command, chdir: app)
    end
  end

  it "has a bundle holding only LensCore" do
    out, err, status = run_in_host("list", "--name-only")

    expect(status).to be_success, err
    names = out.lines.map(&:strip).grep(/\A[\w-]+\z/)
    expect(names).to eq(["lens_core"])
    gems = File.readlines(File.join(app, "Gemfile")).grep(/^\s*gem /)
    expect(gems.size).to eq(1)
    expect(gems.first).to start_with('gem "lens_core"')
    expect(File.read(File.join(app, "read_reports.rb")))
      .not_to match(/require "(svg|png|emf|postscript)/)
  end

  it "reads the xml and binary location examples" do
    expect(output).to include(
      "examples/xml-location.json: profile=example-xml-profile valid=false " \
      "errors=1 warnings=0 infos=0",
      "  location xml line=12 column=4 path=/root/item[2]",
      "  location binary byte_offset=64 byte_length=4 record_index=2 " \
      "record_type=HDR",
      "  location binary byte_offset=128\n",
    )
  end

  it "reads the whole golden directory with counts and no SVG dependency" do
    expect(output).to include(
      "reports: #{golden_entries.size}",
      "svg_conform/svg-four-channel-library.json: " \
      "profile=svg_1_1_full_static valid=false errors=2 warnings=1 infos=1",
    )
    gems = output[/^gems: (.*)$/, 1].split(", ")
    expect(gems).to include("lens_core")
    expect(gems.grep(/svg|png|emf|postscript/)).to be_empty
  end

  it "exits non-zero for a directory without reports" do
    Dir.mktmpdir do |dir|
      _out, err, status = run_in_host("exec", "ruby", "read_reports.rb", dir)

      expect(status).not_to be_success
      expect(err).to include("no reports found")
    end
  end
end
