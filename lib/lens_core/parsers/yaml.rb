# frozen_string_literal: true

require "yaml"

module LensCore
  module Parsers
    # YAML text -> Report. Only plain data is loaded: no object tags, symbols
    # or aliases. A Time is permitted solely so an unquoted RFC 3339
    # `timestamp` works; anywhere else it fails as "must be a string".
    # The document is first read as a Psych AST, so explicit tags other than
    # the core scalar and collection ones are refused before any object is
    # built, and the unquoted `timestamp` is checked in its written form.
    module Yaml
      CORE_TAG =
        /\A(?:!!|tag:yaml\.org,2002:)(?:str|int|float|bool|null|map|seq)\z/
      DATE_LIKE = /\A\d{4}-\d/

      module_function

      # @param input [String] a YAML document
      # @return [LensCore::Report]
      # @raise [LensCore::Error] see lib/lens_core/errors.rb
      def parse(input)
        Report.from_h(decode(Text.decode(input)))
      end

      def decode(text)
        preflight(::YAML.parse(text))
        ::YAML.safe_load(text, permitted_classes: [Time],
                               permitted_symbols: [], aliases: false)
      rescue ::Psych::DisallowedClass, ::Psych::BadAlias => e
        raise UnsafeYamlError, "unsafe YAML: #{e.message}"
      rescue ::Psych::SyntaxError => e
        raise ParseError, "malformed YAML: #{e.message}"
      end

      def preflight(document)
        return unless document

        document.root.each do |node|
          tag = node.tag
          next if tag.nil? || CORE_TAG.match?(tag)

          raise UnsafeYamlError, "unsafe YAML: tag #{tag} is not allowed"
        end
        check_timestamp(document.root)
      end

      # Psych turns an unquoted date-shaped scalar into a Time and forgets how
      # it was written, so the written form is validated here.
      def check_timestamp(root)
        return unless root.is_a?(::Psych::Nodes::Mapping)

        root.children.each_slice(2) do |key, value|
          next unless key.respond_to?(:value) && key.value == "timestamp"
          next unless written_date?(value)

          Validation.timestamp(value.value, "timestamp")
        end
      end

      def written_date?(node)
        node.is_a?(::Psych::Nodes::Scalar) && node.plain &&
          DATE_LIKE.match?(node.value)
      end
    end
  end
end
