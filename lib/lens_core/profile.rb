# frozen_string_literal: true

module LensCore
  # The profile (rule set) a document was checked against.
  class Profile < Node
    MEMBERS = %w[id citations].freeze

    attr_reader :id, :citations

    def self.from_h(hash)
      known, extra = split(hash)
      new(id: known["id"], citations: Citation.list_from_h(known["citations"]),
          extensions: extra)
    end

    def initialize(id:, citations: [], extensions: {})
      @id = Validation.string(id, "id")
      @citations = Citation.check_list(citations)
      super(extensions: extensions)
      freeze
    end

    private

    def standard_members
      { "id" => id, "citations" => citations.map(&:to_h) }
    end
  end
end
