# frozen_string_literal: true

# Reads every JSON report under a directory using LensCore alone and prints
# each report's profile, counts and locations.
#
#   bundle exec ruby read_reports.rb DIRECTORY

require "lens_core"

def location_line(location)
  fields = location.coordinates.map { |key, value| "#{key}=#{value}" }
  "  location #{location.type} #{fields.join(' ')}"
end

def report_lines(path, root)
  report = LensCore::Parsers::Json.parse(File.binread(path))
  summary = report.summary
  head = "#{path.delete_prefix("#{root}/")}: profile=#{report.profile.id} " \
         "valid=#{report.valid} errors=#{summary['errors']} " \
         "warnings=#{summary['warnings']} infos=#{summary['infos']}"
  locations = report.diagnostics.filter_map(&:location)
  [head, *locations.map { |l| location_line(l) }]
end

root = File.expand_path(ARGV.fetch(0) { abort "usage: read_reports.rb DIR" })
paths = Dir[File.join(root, "**", "*.json")]
abort "no reports found under #{root}" if paths.empty?

paths.each { |path| puts report_lines(path, root) }
puts "reports: #{paths.size}"
puts "gems: #{(Gem.loaded_specs.keys - ['bundler']).join(', ')}"
