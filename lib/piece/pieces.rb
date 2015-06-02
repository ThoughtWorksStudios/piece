
module Piece
  class InvalidKey < StandardError
  end

  class Pieces
    def initialize(data)
      @data = data
    end

    def has?(key)
      !!get(@data, parts(key))
    end

    def [](key)
      get(@data, parts(key))
    end

    private
    def parts(key)
      raise InvalidKey, "Should not include '*' in a key" if key.include?('*')
      key.split(':')
    end

    def get(data, keys)
      return data.nil? ? nil : Array(data) if keys.empty?

      case data
      when Hash
        get(data[keys.first], keys[1..-1])
      when Array
        get(data.first, keys) || get(data[1..-1], keys)
      when NilClass
        nil
      else
        match?(data, keys.first) ? '*' : nil
      end
    end

    def match?(a, b)
      a == b || a.nil? || a == '*' || b == '*'
    end
  end
end
