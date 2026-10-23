# frozen_string_literal: true

require "open3"
require "rubygems/package"
require "tmpdir"

RSpec.describe "gem packaging" do # rubocop:disable RSpec/DescribeClass
  let(:root) { File.expand_path("../..", __dir__) }
  let(:spec_file) { File.join(root, "lens_core.gemspec") }

  it "ships a BSD 2-Clause license text in the gem files" do
    gemspec = Gem::Specification.load(spec_file)

    expect(gemspec.licenses).to eq(["BSD-2-Clause"])
    expect(gemspec.files).to include("LICENSE")
    text = File.read(File.join(root, "LICENSE"))
    expect(text).to start_with("BSD 2-Clause License")
    expect(text).to match(/^Copyright \(c\) \d{4}, Ribose$/)
    expect(text).to include("Redistributions of source code must retain")
  end

  it "builds an artifact that contains the license" do
    Dir.mktmpdir do |dir|
      out = File.join(dir, "lens_core.gem")
      _, err, status = Open3.capture3("gem", "build", spec_file,
                                      "--output", out, chdir: root)

      expect(status).to be_success, err
      package = Gem::Package.new(out)
      expect(package.spec.files).to include("LICENSE")
      expect(package.contents).to include("LICENSE")
    end
  end
end
