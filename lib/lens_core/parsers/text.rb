# frozen_string_literal: true

module LensCore
  module Parsers
    # Input decoding shared by the JSON and YAML parsers.
    module Text
      BOM = "﻿"
      READABLE = [Encoding::UTF_8, Encoding::US_ASCII, Encoding::BINARY].freeze

      module_function

      # Returns the input as valid UTF-8 text, or raises. Strings tagged
      # UTF-8, US-ASCII or binary (the usual result of reading a file in
      # "rb" mode) are read as UTF-8; any other encoding is rejected rather
      # than transcoded, so every accepted byte stream has one meaning.
      def decode(input)
        unless input.is_a?(String)
          raise ParseError, "expected a String, got #{input.class}"
        end

        text = utf8(input)
        if text.start_with?(BOM)
          raise ParseError, "a byte order mark is not allowed"
        end

        text
      end

      def utf8(input)
        unless READABLE.include?(input.encoding)
          raise InvalidEncodingError, "input is #{input.encoding}, not UTF-8"
        end

        text = input.dup.force_encoding(Encoding::UTF_8)
        return text if text.valid_encoding?

        raise InvalidEncodingError, "input is not valid UTF-8"
      end
    end
  end
end
