# frozen_string_literal: true

require "yaml"

module LensCore
  module Parsers
    # YAML text -> Report. Only plain data is loaded: no object tags, symbols
    # or aliases. A Time is permitted solely so an unquoted RFC 3339
    # `timestamp` works; anywhere else it fails as "must be a string".
    module Yaml
      module_function

      # @param input [String] a YAML document
      # @return [LensCore::Report]
      # @raise [LensCore::Error] see lib/lens_core/errors.rb
      def parse(input)
        Report.from_h(decode(Text.decode(input)))
      end

      def decode(text)
        ::YAML.safe_load(text, permitted_classes: [Time],
                               permitted_symbols: [], aliases: false)
      rescue ::Psych::DisallowedClass, ::Psych::BadAlias => e
        raise UnsafeYamlError, "unsafe YAML: #{e.message}"
      rescue ::Psych::SyntaxError => e
        raise ParseError, "malformed YAML: #{e.message}"
      end
    end
  end
end
