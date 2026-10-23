# frozen_string_literal: true

module LensCore
  # A pointer to the text a requirement comes from.
  class Citation < Node
    MEMBERS = %w[uri label].freeze

    attr_reader :uri, :label

    def self.from_h(hash)
      known, extra = split(hash)
      new(uri: known["uri"], label: known["label"], extensions: extra)
    end

    # Wire array -> frozen array of Citation; errors carry the array index.
    def self.list_from_h(list, name = "citations")
      Validation.array(list, name).each_with_index.map do |item, i|
        from_h(item)
      rescue SchemaError => e
        raise e.within(i).within(name)
      end.freeze
    end

    # Ruby array -> frozen array, every item a Citation.
    def self.check_list(list, name = "citations")
      Validation.array(list, name).each_with_index.map do |item, i|
        unless item.is_a?(self)
          Validation.fail_at("must be a LensCore::Citation",
                             [name, i])
        end
        item
      end.freeze
    end

    # @param uri [String] absolute URI (required)
    # @param label [String, nil] human-readable name
    def initialize(uri:, label: nil, extensions: {})
      @uri = Validation.absolute_uri(uri, "uri")
      @label = label.nil? ? nil : Validation.string(label, "label")
      super(extensions: extensions)
      freeze
    end

    private

    def standard_members
      { "uri" => uri, "label" => label }
    end
  end
end
