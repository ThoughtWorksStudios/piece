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
        apply(group.val, keys)
      else
        if @data.has_key?(group)
          get(@data[group], keys)
        else
          raise "Unknown group: #{group}"
        end
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
      when ExpressionParser::Exp
        apply(data, keys)
      when ExpressionParser::Id
        match?(data.val, keys.first) ? '*' : nil
      else
        get(ExpressionParser.new.parse(data), keys)
      end
    end

    def match?(a, b)
      a == b || a.nil? || a == '*' || b == '*'
    end
  end
end
