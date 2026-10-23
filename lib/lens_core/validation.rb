# frozen_string_literal: true

require "time"

module LensCore
  # Shared checks and canonicalization used by every value object, so a
  # report built in Ruby and a report parsed from text obey the same rules.
  # `name` is a member name or a path (Array) to one; errors carry it.
  module Validation
    ABSOLUTE_URI = /\A[A-Za-z][A-Za-z0-9+.-]*:\S+\z/
    TIMESTAMP = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?
                 (Z|[+-]\d{2}:\d{2})\z/x
    TEXT_ENCODINGS = [Encoding::UTF_8, Encoding::US_ASCII].freeze

    module_function

    def fail_at(detail, name)
      raise SchemaError.new(detail, Array(name))
    end

    def required(value, name)
      fail_at("is required", name) if value.nil?
      value
    end

    def object(value, name = nil)
      return value if required(value, name).is_a?(Hash)

      fail_at("must be an object", name)
    end

    def array(value, name)
      return value if required(value, name).is_a?(Array)

      fail_at("must be an array", name)
    end

    def string(value, name, allow_empty: false)
      required(value, name)
      fail_at("must be a string", name) unless value.is_a?(String)

      text(value, name)
      fail_at("must not be empty", name) if value.empty? && !allow_empty

      value.frozen? ? value : value.dup.freeze
    end

    # An optional string member: nil stays nil.
    def optional_string(value, name)
      value.nil? ? nil : string(value, name)
    end

    def integer(value, name, min:)
      required(value, name)
      fail_at("must be an integer", name) unless value.is_a?(Integer)
      fail_at("must be >= #{min}", name) if value < min

      value
    end

    def boolean(value, name)
      return value if [true, false].include?(required(value, name))

      fail_at("must be true or false", name)
    end

    def one_of(value, allowed, name)
      value = value.to_s if value.is_a?(Symbol)
      return value if allowed.include?(string(value, name))

      fail_at("must be one of #{allowed.join(', ')}", name)
    end

    def absolute_uri(value, name)
      return value if ABSOLUTE_URI.match?(string(value, name))

      fail_at("must be an absolute URI", name)
    end

    # Accepts a Time or an RFC 3339 string with an explicit offset; returns a
    # frozen UTC Time, or nil when the member is absent.
    def timestamp(value, name)
      return nil if value.nil?
      return value.dup.utc.freeze if value.is_a?(Time)

      string(value, name)
      return Time.iso8601(value).utc.freeze if TIMESTAMP.match?(value)

      fail_at("must be an RFC 3339 timestamp", name)
    rescue ArgumentError
      fail_at("must be an RFC 3339 timestamp", name)
    end

    def text(value, name)
      return if TEXT_ENCODINGS.include?(value.encoding) && value.valid_encoding?

      raise InvalidEncodingError, "#{Array(name).join('.')}: not valid UTF-8"
    end

    # Deep copy of a JSON-safe value, frozen, with object keys sorted
    # lexically (by bytes). Raises SchemaError for anything JSON cannot carry.
    def json_value(value, name)
      case value
      when nil, true, false, Integer, Float, String
        json_scalar(value, name)
      when Array then json_array(value, name)
      when Hash then json_object(value, name)
      else fail_at("must be JSON-safe (got #{value.class})", name)
      end
    end

    def json_scalar(value, name)
      if value.is_a?(Float) && !value.finite?
        fail_at("must be a finite number", name)
      end

      value.is_a?(String) ? string(value, name, allow_empty: true) : value
    end

    def json_array(list, name)
      list.each_with_index.map { |v, i| json_value(v, [*name, i]) }.freeze
    end

    def json_object(hash, name)
      hash.each_key do |key|
        fail_at("object keys must be strings", name) unless key.is_a?(String)

        text(key, name)
      end
      hash.sort_by { |key, _| key.b }
        .to_h { |key, v| [key.dup.freeze, json_value(v, [*name, key])] }
        .freeze
    end

    # A diagnostic's `context`: a JSON-safe object.
    def context(value)
      json_object(object(value, "context"), "context")
    end

    # Extension members: JSON-safe values under keys that are not standard.
    def extensions(hash, standard, name = [])
      json_object(object(hash, name), name).tap do |ext|
        clash = ext.keys & standard
        next if clash.empty?

        fail_at("#{clash.first} is a standard member, not an extension", name)
      end
    end
  end
end
