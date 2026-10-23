# frozen_string_literal: true

require "json"

module LensCore
  module Parsers
    # JSON text -> Report.
    module Json
      module_function

      # @param input [String] a JSON document
      # @return [LensCore::Report]
      # @raise [LensCore::Error] see lib/lens_core/errors.rb
      def parse(input)
        Report.from_h(decode(Text.decode(input)))
      end

      def decode(text)
        ::JSON.parse(text, allow_nan: false)
      rescue ::JSON::ParserError => e
        raise ParseError, "malformed JSON: #{e.message.lines.first.to_s.strip}"
      end
    end
  end
end
