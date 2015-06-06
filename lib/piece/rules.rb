require 'piece/expression.tab'

module Piece
  class RulesError < StandardError
  end

  class InvalidAction < RulesError
  end

  class UnknownRuleGroupName < RulesError
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

    def delete(*rule)
      return if rule.empty?
      parts = rule_parts(rule)

      group = parts[0..-2].inject(@data) do |data, part|
        data[part].tap do |ret|
          return if ret.nil?
        end
      end

      if group
        group.delete_if {|rule| rule == parts[-1]}
        if group.empty?
          self.delete(*(parts[0..-2]))
        end
      end
    end

    def match?(*action)
      self[*action][:match]
    end

    def [](*action)
      ret = []
      m = eval(@data, action_parts(action), ret)
      {:match => m == :match, :reason => ret}
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
      Array(rule).map do |part|
        case part
        when Array
          part.join(',')
        when Symbol
          part.to_s
        else
          part.to_s
        end.split(':')
      end.flatten.map(&:strip)
    end

    def dequote(str)
      str =~ /^[\['"](.*)[\]'"]$/ ? $1 : str
    end

    def apply(group, actions, backtrace)
      case group
      when ExpressionParser::Exp
        validate_rule_names(group)
        case group.op
        when '+'
          sub = []
          if r = apply(group.left, actions, sub)
            backtrace.concat(sub)
            r
          else
            apply(group.right, actions, backtrace)
          end
        when '-'
          sub1, sub2 = [], []
          if r = apply(group.left, actions, sub1)
            if apply(group.right, actions, sub2).nil?
              backtrace.concat(sub1)
              r
            else
              backtrace.concat(sub2)
              nil
            end
          else
            backtrace.concat(sub1)
            nil
          end
        else
          raise "Unknown operator: #{group.op}"
        end
      when ExpressionParser::Id
        if @data.has_key?(group.val)
          backtrace << group.val
          eval(@data[group.val], actions, backtrace)
        else
          eval(group, actions, backtrace)
        end
      else
        raise "Unknown type: #{group.inspect}"
      end
    end

    def eval(data, actions, backtrace=[])
      return data.nil? ? nil : :match if actions.empty?
      case data
      when Hash
        backtrace << actions.first
        eval(data[actions.first], actions[1..-1], backtrace)
      when Array
        backtrace << data
        eval(data.first, actions) || eval(data[1..-1], actions)
      when NilClass
        nil
      when ExpressionParser::Id
        _match_?(data.val, actions.first) ? :match : nil
      when String
        backtrace << data
        apply(ExpressionParser.new.parse(data), actions, backtrace)
      else
        raise "Unknown type: #{group.inspect}"
      end
    end

    def _match_?(a, b)
      a == b || a.nil? || a == '*' || b == '*'
    end

    def validate_rule_names(exp)
      case exp
      when ExpressionParser::Exp
        validate_rule_names(exp.left)
        validate_rule_names(exp.right)
      when ExpressionParser::Id
        if exp.val != '*' && !@data.has_key?(exp.val)
          raise UnknownRuleGroupName,
                "Expecting '#{exp.val}' in expression to be a root rule group name(root group names: #{@data.keys.inspect}) you defined. "
        end
      end
    end
  end
end
