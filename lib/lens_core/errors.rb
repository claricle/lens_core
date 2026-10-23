# frozen_string_literal: true

module LensCore
  # Base class of every error LensCore raises for bad input.
  class Error < StandardError; end

  # The text is not well-formed JSON or YAML (or is not a document at all).
  class ParseError < Error; end

  # The YAML uses a feature that is not safe to load: an object tag, a symbol,
  # or an alias.
  class UnsafeYamlError < Error; end

  # The text, or a string inside it, is not valid UTF-8.
  class InvalidEncodingError < Error; end

  # The document declares a schema version other than LensCore::SCHEMA_VERSION.
  class UnsupportedVersionError < Error; end

  # The document is well-formed but breaks the schema. `path` names the
  # offending member, e.g. "diagnostics[2].location.line".
  class SchemaError < Error
    attr_reader :detail, :path

    def initialize(detail, path = [])
      @detail = detail
      @path = path.freeze
      super(path.empty? ? detail : "#{format_path}: #{detail}")
    end

    # The same error, located one level further out.
    def within(segment)
      self.class.new(detail, [segment, *path])
    end

    private

    def format_path
      path.each_with_index.map do |seg, i|
        if seg.is_a?(Integer)
          "[#{seg}]"
        else
          (i.zero? ? seg.to_s : ".#{seg}")
        end
      end.join
    end
  end
end
