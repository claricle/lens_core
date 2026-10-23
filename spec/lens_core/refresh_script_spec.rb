# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

RSpec.describe "script/refresh_svg_goldens" do # rubocop:disable RSpec/DescribeClass
  let(:repo) { File.expand_path("../..", __dir__) }
  let(:svg_paths) do
    %w[svg_conform/svg-1.1-invalid-grammar.json
       svg_conform/svg-2-external-reference.json
       svg_conform/svg-four-channel-library.json]
  end

  # A copy of the script in a scratch tree, so ROOT (and every write) lands
  # in the scratch tree, plus a manifest whose SVG paths are replaced.
  def build_tree(dir, paths, outside)
    tree = File.join(dir, "tree")
    golden = File.join(tree, "spec/fixtures/v1/golden")
    FileUtils.mkdir_p([File.join(golden, "svg_conform"),
                       File.join(tree, "script")])
    FileUtils.cp(File.join(repo, "script/refresh_svg_goldens"),
                 File.join(tree, "script"))
    File.write(File.join(golden, "manifest.yml"), manifest_with(paths))
    link_out(golden, outside) if outside
    File.join(tree, "script/refresh_svg_goldens")
  end

  def link_out(golden, outside)
    FileUtils.rm_r(File.join(golden, "svg_conform"))
    File.symlink(outside, File.join(golden, "svg_conform"))
  end

  def run_script(paths, outside: nil)
    Dir.mktmpdir do |dir|
      script = build_tree(dir, paths, outside)
      _, err, status = Open3.capture3(
        RbConfig.ruby, "-I", File.join(repo, "lib"), script,
        File.join(dir, "none")
      )
      yield err, status, dir
    end
  end

  def manifest_with(paths)
    manifest = YAML.safe_load_file(
      File.join(repo, "spec/fixtures/v1/golden/manifest.yml"),
    )
    svg = manifest["goldens"].select { |g| g.key?("svg_conform_commit") }
    svg.zip(paths) { |entry, path| entry["path"] = path }
    YAML.dump(manifest)
  end

  [["a traversing path", "../../../../../outside.json"],
   ["an absolute path", "/tmp/outside.json"],
   ["a path outside the three goldens",
    "svg_conform/extra.json"]].each do |name, path|
    it "refuses #{name} before any checkout or write" do
      paths = [path, *svg_paths.drop(1)]

      run_script(paths) do |err, status, _dir|
        expect(status.exitstatus).to eq(1)
        expect(err).to include("manifest path")
      end
    end
  end

  it "refuses a golden directory that is a symlink out of the tree" do
    Dir.mktmpdir do |outside|
      run_script(svg_paths, outside: outside) do |err, status, _dir|
        expect(status.exitstatus).to eq(1)
        expect(err).to include("manifest path")
        expect(Dir.children(outside)).to be_empty
      end
    end
  end

  it "accepts the three expected paths up to the checkout check" do
    run_script(svg_paths) do |err, status, _dir|
      expect(status.exitstatus).to eq(1)
      expect(err).to include("not a directory")
    end
  end
end
