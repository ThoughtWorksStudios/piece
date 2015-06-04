require 'piece/expression.tab'

module Piece
  class InvalidAction < StandardError
  end

  class Rules
    def initialize(data={})
      @data = data
    end

    def <<(rule)
      parts = rule_parts(rule)
      group = parts[0..-3].inject(@data) do |data, part|
        data[part] ||= {}
      end
      last = parts.last
      group[parts[-2]] = dequote(last).split(',').map(&:strip)
    end
    alias :add :<<

    def match?(*action)
      !!self[*action]
    end

    def [](*action)
      get(@data, action_parts(action))
    end

    private
    def action_parts(action)
      action.map{|part| part.to_s.split(':')}.flatten.map(&:strip).tap do |ret|
        if ret.any?{|part| part.include?('*')}
          raise InvalidAction, "Should not include '*' in an action"
        end
      end
    end

    def rule_parts(rule)
      Array(rule).map{|part| part.to_s.split(':')}.flatten.map(&:strip)
    end

    def dequote(str)
      str =~ /^[\['"](.*)[\]'"]$/ ? $1 : str
    end

    def apply(group, actions)
      case group
      when ExpressionParser::Exp
        case group.op
        when '+'
          apply(group.left, actions) || apply(group.right, actions)
        when '-'
          apply(group.left, actions) && apply(group.right, actions).nil?
        else
          raise "Unknown operator: #{group.op}"
        end
      when ExpressionParser::Id
        if @data.has_key?(group.val)
          get(@data[group.val], actions)
        else
          get(group, actions)
        end
      else
        raise "Unknown type: #{group.inspect}"
      end
    end

    def get(data, actions)
      return data.nil? ? nil : Array(data) if actions.empty?
      case data
      when Hash
        get(data[actions.first], actions[1..-1])
      when Array
        get(data.first, actions) || get(data[1..-1], actions)
      when NilClass
        nil
      when ExpressionParser::Id
        _match_?(data.val, actions.first) ? '*' : nil
      when String
        apply(ExpressionParser.new.parse(data), actions)
      else
        raise "Unknown type: #{group.inspect}"
      end
    end

    def _match_?(a, b)
      a == b || a.nil? || a == '*' || b == '*'
    end
  end
end
