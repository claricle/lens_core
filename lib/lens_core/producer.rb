# frozen_string_literal: true

module LensCore
  # The tool that produced a report.
  class Producer < Node
    MEMBERS = %w[name version].freeze

    attr_reader :name, :version

    def self.from_h(hash)
      known, extra = split(hash)
      new(name: known["name"], version: known["version"], extensions: extra)
    end

    def initialize(name:, version:, extensions: {})
      @name = Validation.string(name, "name")
      @version = Validation.string(version, "version")
      super(extensions: extensions)
      freeze
    end

    private

    def standard_members
      { "name" => name, "version" => version }
    end
  end
end
