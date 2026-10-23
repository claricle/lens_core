# frozen_string_literal: true

require "json"

module LensCore
  module Renderers
    # Report -> plain text for people. No colour, no terminal control codes,
    # no wrapping: the same report always yields the same text.
    #
    #   svg-lens 0.2.4, profile example-profile
    #   INVALID: 1 error, 1 warning, 1 info
    #
    #   error  REQ-001  (unsupported_element)
    #     at line 3, column 5, /svg/foo
    #     <message>
    #     fix: <remediation>
    #     see: <label> <uri>
    #     context: {"key":"value"}
    module Human
      # How each coordinate reads, in display order.
      PLACES = {
        "xml" => [["line", "line "], ["column", "column "], ["path", ""]],
        "binary" => [
          ["byte_offset", "byte offset "],
          ["byte_length", "length "],
          ["record_index", "record "],
          ["record_type", ""],
        ],
      }.freeze

      module_function

      def render(report)
        lines = header(report)
        report.diagnostics.each { |d| lines.push("", *entry(d)) }
        "#{lines.join("\n")}\n"
      end

      def header(report)
        ["#{report.producer.name} #{report.producer.version}, " \
         "profile #{report.profile.id}",
         *("Checked at #{report.to_h['timestamp']}" if report.timestamp),
         verdict(report)]
      end

      def verdict(report)
        counts = report.summary.map do |key, count|
          noun = key.delete_suffix("s")
          "#{count} #{noun}#{'s' unless count == 1}"
        end
        "#{report.valid ? 'VALID' : 'INVALID'}: #{counts.join(', ')}"
      end

      def entry(diagnostic)
        [headline(diagnostic),
         *("  at #{place(diagnostic.location)}" if diagnostic.location),
         *diagnostic.message.each_line(chomp: true).map { |l| "  #{l}" },
         *("  fix: #{diagnostic.remediation}" if diagnostic.remediation),
         *diagnostic.citations.map { |c| citation_line(c) },
         *context_line(diagnostic.context)]
      end

      def citation_line(citation)
        "  see: #{[citation.label, citation.uri].compact.join(' ')}"
      end

      def headline(diagnostic)
        "#{diagnostic.severity}  #{diagnostic.requirement_id}  " \
          "(#{diagnostic.kind})"
      end

      def context_line(context)
        context.empty? ? [] : ["  context: #{::JSON.generate(context)}"]
      end

      def place(location)
        parts = PLACES.fetch(location.type).filter_map do |key, prefix|
          value = location.coordinates[key]
          "#{prefix}#{value}" unless value.nil?
        end
        parts.empty? ? "(#{location.type}, no coordinates)" : parts.join(", ")
      end
    end
  end
end
