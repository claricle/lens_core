# frozen_string_literal: true

require "json"

module LensCore
  module Renderers
    # Report -> canonical JSON: two-space indent, schema key order, one
    # trailing newline. Parsing canonical JSON and rendering it again
    # returns the same bytes.
    module Json
      module_function

      def render(report)
        "#{::JSON.pretty_generate(report.to_h)}\n"
      end
    end
  end
end
