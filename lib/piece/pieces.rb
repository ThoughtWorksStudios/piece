
module Piece
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
      key.split(':')
    end

    def get(data, keys)
      return data.nil? ? nil : Array(data) if keys.empty?

      case data
      when Hash
        get(data[keys.shift], keys)
      when Array
        '*' if data.include?('*') || data.include?(keys.shift)
      when NilClass
        nil
      else
        get([data], keys)
      end
    end
  end
end
