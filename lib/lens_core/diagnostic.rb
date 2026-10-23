# frozen_string_literal: true

module LensCore
  # One finding. `kind` is an open vocabulary: producers may introduce new
  # values, consumers must tolerate ones they do not know.
  class Diagnostic < Node
    SEVERITIES = %w[error warning info].freeze
    MEMBERS = %w[severity kind requirement_id message citations remediation
                 context location].freeze

    attr_reader(*MEMBERS.map(&:to_sym))

    def self.from_h(hash)
      known, extra = split(hash)
      new(
        severity: known["severity"], kind: known["kind"],
        requirement_id: known["requirement_id"], message: known["message"],
        remediation: known["remediation"], context: known.fetch("context", {}),
        citations: Citation.list_from_h(known.fetch("citations", [])),
        location: location_from(known["location"]), extensions: extra
      )
    end

    def self.location_from(value)
      return nil if value.nil?

      Location.from_h(value)
    rescue SchemaError => e
      raise e.within("location")
    end
    private_class_method :location_from

    def initialize(severity:, kind:, requirement_id:, message:, citations: [],
                   remediation: nil, context: {}, location: nil,
                   extensions: {})
      @severity = Validation.one_of(severity, SEVERITIES, "severity")
      @kind = Validation.string(kind, "kind")
      @requirement_id = Validation.string(requirement_id, "requirement_id")
      @message = Validation.string(message, "message")
      @citations = Citation.check_list(citations)
      @remediation = Validation.optional_string(remediation, "remediation")
      @context = Validation.context(context)
      @location = check_location(location)
      super(extensions: extensions)
      freeze
    end

    SEVERITIES.each do |name|
      define_method(:"#{name}?") { severity == name }
    end

    private

    def check_location(location)
      return location if location.nil? || location.is_a?(Location)

      Validation.fail_at("must be a LensCore::Location", "location")
    end

    def standard_members
      MEMBERS.to_h { |name| [name, public_send(name)] }.merge(
        "citations" => citations.map(&:to_h), "location" => location&.to_h,
      )
    end
  end
end
