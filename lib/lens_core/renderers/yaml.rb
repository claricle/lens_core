# frozen_string_literal: true

require "yaml"

module LensCore
  module Renderers
    # Report -> YAML with the same content and key order as the JSON form.
    module Yaml
      module_function

      def render(report)
        ::YAML.dump(report.to_h, line_width: -1)
      end
    end
  end
end
