# frozen_string_literal: true

require_relative "lens_core/version"
require_relative "lens_core/errors"
require_relative "lens_core/schema"
require_relative "lens_core/validation"
require_relative "lens_core/node"
require_relative "lens_core/citation"
require_relative "lens_core/location"
require_relative "lens_core/producer"
require_relative "lens_core/profile"
require_relative "lens_core/diagnostic"
require_relative "lens_core/report"
require_relative "lens_core/parsers/text"
require_relative "lens_core/parsers/json"
require_relative "lens_core/parsers/yaml"
require_relative "lens_core/renderers/json"
require_relative "lens_core/renderers/yaml"
require_relative "lens_core/renderers/human"

# Format-neutral conformance diagnostics: a report model (schema version
# LensCore::SCHEMA_VERSION), JSON and YAML parsers, and JSON, YAML and
# human-readable renderers. It has no runtime dependencies.
module LensCore
end
