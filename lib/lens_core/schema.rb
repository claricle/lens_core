# frozen_string_literal: true

require "json"

module LensCore
  # The normative JSON Schema shipped with the gem.
  module Schema
    PATH = File.expand_path("../../schemas/lens-diagnostics-v1.json", __dir__)

    module_function

    # Schema version, as written in a report's `schema_version` member.
    def version
      SCHEMA_VERSION
    end

    # The schema as a Hash, freshly parsed on every call.
    def document
      ::JSON.parse(File.read(PATH, encoding: Encoding::UTF_8))
    end
  end
end
