# frozen_string_literal: true

module LensCore
  # Where a diagnostic applies. `type` says which coordinates are meaningful;
  # a coordinate that is not known is nil and is omitted from output, never
  # replaced by a placeholder.
  #
  #   xml     line, column (1-based), path
  #   binary  byte_offset, byte_length, record_index (0-based), record_type
  class Location < Node
    TYPES = %w[xml binary].freeze
    FIELDS = {
      "xml" => %w[line column path],
      "binary" => %w[byte_offset byte_length record_index record_type],
    }.freeze
    MEMBERS = (["type"] + FIELDS.values.flatten).freeze
    MINIMUMS = {
      "line" => 1, "column" => 1,
      "byte_offset" => 0, "byte_length" => 0, "record_index" => 0
    }.freeze

    attr_reader :type, :coordinates

    def self.from_h(hash)
      known, extra = split(hash)
      type = Validation.one_of(known["type"], TYPES, "type")
      new(type: type, **known.except("type").transform_keys(&:to_sym),
          extensions: extra)
    end

    def self.xml(line: nil, column: nil, path: nil, extensions: {})
      new(type: "xml", line: line, column: column, path: path,
          extensions: extensions)
    end

    def self.binary(byte_offset: nil, byte_length: nil, record_index: nil,
                    record_type: nil, extensions: {})
      new(type: "binary", byte_offset: byte_offset, byte_length: byte_length,
          record_index: record_index, record_type: record_type,
          extensions: extensions)
    end

    def initialize(type:, extensions: {}, **fields)
      @type = Validation.one_of(type, TYPES, "type")
      @coordinates = coordinates_from(fields)
      super(extensions: extensions)
      freeze
    end

    FIELDS.values.flatten.each do |name|
      define_method(name) { coordinates[name] }
    end

    private

    def coordinates_from(fields)
      applicable = FIELDS.fetch(type)
      reject_stray(fields, applicable)
      applicable.to_h { |name| [name, check(name, fields[name.to_sym])] }
        .compact.freeze
    end

    def reject_stray(fields, applicable)
      stray = fields.keys.map(&:to_s) - applicable
      return if stray.empty?

      Validation.fail_at("is not a #{type} coordinate", stray.first)
    end

    def check(name, value)
      return nil if value.nil?
      return Validation.string(value, name) unless MINIMUMS.key?(name)

      Validation.integer(value, name, min: MINIMUMS.fetch(name))
    end

    def standard_members
      { "type" => type }.merge(coordinates)
    end
  end
end
