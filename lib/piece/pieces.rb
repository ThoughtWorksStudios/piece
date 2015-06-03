require 'piece/expression.tab'

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

    def apply(group, keys)
      case group
      when ExpressionParser::Exp
        case group.op
        when '+'
          apply(group.left, keys) || apply(group.right, keys)
        when '-'
          apply(group.left, keys) && apply(group.right, keys).nil?
        else
          raise "Unknown operator: #{group.op}"
        end
      when ExpressionParser::Id
        if @data.has_key?(group.val)
          get(@data[group.val], keys)
        else
          get(group, keys)
        end
      else
        raise "Unknown type: #{group.inspect}"
      end
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
      when ExpressionParser::Id
        match?(data.val, keys.first) ? '*' : nil
      when String
        apply(ExpressionParser.new.parse(data), keys)
      else
        raise "Unknown type: #{group.inspect}"
      end
    end

    def match?(a, b)
      a == b || a.nil? || a == '*' || b == '*'
    end
  end
end
