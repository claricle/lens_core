# frozen_string_literal: true

module LensCore
  # Base of the immutable value objects. A node has standard members (named by
  # MEMBERS, in schema order) plus extensions: additional JSON-safe members a
  # compatible v1 producer may add. Extensions are kept and re-emitted after
  # the standard members, sorted lexically.
  class Node
    attr_reader :extensions

    def self.members
      self::MEMBERS
    end

    # Splits a wire object into [standard members, extensions]. A standard
    # member is never null: absent optional members are omitted.
    def self.split(hash, name = nil)
      Validation.object(hash, name)
      known, extra = hash.partition { |key, _| members.include?(key) }
        .map(&:to_h)
      reject_nulls(known)
      [known, extra]
    end

    def self.reject_nulls(known)
      known.each do |key, value|
        next unless value.nil?

        Validation.fail_at("must not be null (omit the member instead)", key)
      end
    end
    private_class_method :reject_nulls

    def initialize(extensions: {})
      @extensions = Validation.extensions(extensions, self.class.members)
    end

    # Canonical wire form: standard members in schema order (absent optional
    # members omitted), then extensions.
    def to_h
      standard_members.compact.merge(extensions)
    end

    def ==(other)
      other.instance_of?(self.class) && other.to_h == to_h
    end
    alias eql? ==

    def hash
      [self.class, to_h].hash
    end

    private

    def standard_members
      raise NotImplementedError
    end
  end
end
