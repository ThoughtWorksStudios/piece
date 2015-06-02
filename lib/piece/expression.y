class Piece::ExpressionParser
  options no_result_var

  prechigh
  left     OP
  preclow

  token ID OP

  rule
  target
     : exp { val[0] }

  exp
     : exp OP exp { Exp.new(val[1], val[0], val[2]) }
     | ID         { Id.new(val[0]) }
     ;

---- header ----
  require 'strscan'
---- inner ----
  class Exp < Struct.new(:op, :left, :right)
  end

  class Id < Struct.new(:val)
  end

  def parse(str)
    @tokens = []
    str = "" if str.nil?
    scanner = StringScanner.new(str + ' ')

    until scanner.eos?
      case
      when scanner.scan(/\s+/)
      # ignore space
      when m = scanner.scan(/[+-]/i)
        @tokens.push [:OP, m]
      when m = scanner.scan(/(\w+)\b/i)
        @tokens.push [:ID, m]
      when m = scanner.scan(/\*/i)
        @tokens.push [:ID, m]
      else
        raise "unexpected characters #{scanner.peek(5)}"
      end
    end
    @tokens.push [false, false]
    do_parse
  end

  def next_token
    @tokens.shift
  end
