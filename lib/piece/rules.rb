require 'piece/expression.tab'
require 'piece/seq'

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
      matching_seq(*action).match?
    end

    def [](*action)
      matching_seq(*action).to_a
    end

    private
    def matching_seq(*action)
      eval(@data, action_parts(action))
    end

    def action_parts(action)
      action.flatten.map{|part| part.to_s.split(':')}.flatten.map(&:strip).tap do |ret|
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

    def apply(group, actions)
      case group
      when ExpressionParser::Exp
        validate_rule_names(group)
        case group.op
        when '+'
          left = apply(group.left, actions)
          if left.match?
            Seq[left] + Seq.match
          else
            right = apply(group.right, actions)
            if right.match?
              Seq[right] + Seq.match
            else
              Seq[left] + Seq[right] + Seq.mismatch
            end
          end
        when '-'
          left = apply(group.left, actions)
          if left.match?
            right = apply(group.right, actions)
            if right.match?
              Seq[right] + Seq.mismatch
            else
              Seq[left] + Seq[right] + Seq.match
            end
          else
            Seq[left] + Seq.mismatch
          end
        else
          raise "Unknown operator: #{group.op}"
        end
      when ExpressionParser::Id
        if @data.has_key?(group.val)
          Seq[group.val] + eval(@data[group.val], actions)
        else
          eval(group, actions)
        end
      else
        raise "Unknown type: #{group.inspect}"
      end
    end

    def eval(data, actions)
      if actions.empty?
        Seq.match(!data.nil?)
      else
        case data
        when Hash
          Seq[actions.first] + eval(data[actions.first], actions[1..-1])
        when Array
          data.each do |ac|
            ret = eval(ac, actions)
            if ret.match?
              return ret
            end
          end
          Seq[data] + Seq.mismatch
        when NilClass
          Seq.mismatch
        when ExpressionParser::Id
          if data.val == '*'
            Seq.match
          elsif actions.size == 1
            Seq.match(data.val == actions[0])
          else
            Seq.mismatch
          end
        when String
          Seq[data] + apply(ExpressionParser.new.parse(data), actions)
        else
          raise "Unknown type: #{group.inspect}"
        end
      end
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
