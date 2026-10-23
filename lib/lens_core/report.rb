# frozen_string_literal: true

module LensCore
  # A complete diagnostics report (schema version 1).
  #
  # `valid` is stated by the producer, not derived: whether warnings fail a
  # document is the producer's policy. It cannot be true while the report
  # holds an error. `summary` is always derived from the diagnostics.
  class Report < Node
    MEMBERS = %w[schema_version producer profile timestamp valid summary
                 diagnostics].freeze
    SUMMARY_KEYS = {
      "errors" => "error", "warnings" => "warning", "infos" => "info"
    }.freeze

    attr_reader :producer, :profile, :valid, :diagnostics, :timestamp

    # Builds a Report from a decoded JSON/YAML object. Raises
    # UnsupportedVersionError, SchemaError or InvalidEncodingError.
    def self.from_h(hash)
      unless hash.is_a?(Hash)
        raise SchemaError, "the document must be an object"
      end

      check_version(hash["schema_version"])
      known, extra = split(hash)
      build(known, extra).tap { |r| r.check_summary(known["summary"]) }
    end

    def self.check_version(version)
      Validation.integer(version, "schema_version", min: 0)
      return if version == SCHEMA_VERSION

      raise UnsupportedVersionError,
            "schema_version #{version} is not supported " \
            "(this is LensCore #{VERSION}, schema version #{SCHEMA_VERSION})"
    end

    def self.build(known, extra)
      new(
        producer: within("producer") { Producer.from_h(known["producer"]) },
        profile: within("profile") { Profile.from_h(known["profile"]) },
        diagnostics: diagnostics_from(known["diagnostics"]),
        valid: known["valid"], timestamp: known["timestamp"], extensions: extra
      )
    end

    def self.within(name)
      yield
    rescue SchemaError => e
      raise e.within(name)
    end

    def self.diagnostics_from(list)
      Validation.array(list, "diagnostics").each_with_index.map do |item, i|
        within("diagnostics") { within(i) { Diagnostic.from_h(item) } }
      end
    end
    private_class_method :check_version, :build, :within, :diagnostics_from

    # @param timestamp [Time, String, nil] supplied by the caller; never
    #   defaulted to the current time.
    def initialize(producer:, profile:, valid:, diagnostics: [],
                   timestamp: nil, extensions: {})
      @producer = check_type(producer, Producer, "producer")
      @profile = check_type(profile, Profile, "profile")
      @diagnostics = check_diagnostics(diagnostics)
      @valid = check_valid(valid)
      @timestamp = Validation.timestamp(timestamp, "timestamp")
      super(extensions: extensions)
      freeze
    end

    def schema_version
      SCHEMA_VERSION
    end

    # Counts derived from the diagnostics.
    def summary
      SUMMARY_KEYS.transform_values { |severity| count(severity) }
    end

    # The wire summary is redundant; reject one that disagrees.
    # @api private
    def check_summary(wire)
      Validation.object(wire, "summary")
      summary.each do |key, expected|
        actual = Validation.integer(wire[key], ["summary", key], min: 0)
        next if actual == expected

        Validation.fail_at(
          "is #{actual} but the diagnostics contain #{expected}",
          ["summary", key],
        )
      end
    end

    private

    def count(severity)
      diagnostics.count { |d| d.severity == severity }
    end

    def check_type(value, type, name)
      return value if value.is_a?(type)

      Validation.fail_at("must be a #{type}", name)
    end

    def check_diagnostics(list)
      Validation.array(list, "diagnostics").each_with_index.map do |item, i|
        check_type(item, Diagnostic, ["diagnostics", i])
      end.freeze
    end

    def check_valid(value)
      Validation.boolean(value, "valid")
      return value unless value && diagnostics.any?(&:error?)

      Validation.fail_at("cannot be true when the report has errors", "valid")
    end

    def standard_members
      {
        "schema_version" => schema_version, "producer" => producer.to_h,
        "profile" => profile.to_h, "timestamp" => format_timestamp,
        "valid" => valid, "summary" => summary,
        "diagnostics" => diagnostics.map(&:to_h)
      }
    end

    # UTC, with sub-second digits only when there are some.
    def format_timestamp
      return nil unless timestamp

      digits = format("%09d", timestamp.nsec).sub(/0+\z/, "")
      fraction = digits.empty? ? "" : ".#{digits}"
      "#{timestamp.strftime('%Y-%m-%dT%H:%M:%S')}#{fraction}Z"
    end
  end
end
