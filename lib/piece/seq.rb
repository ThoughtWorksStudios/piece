module Piece
  class Seq
    def self.[](*data)
      new(*data)
    end

    def self.match(m=true)
      m ? new(:match) : mismatch
    end

    def self.mismatch
      new(:mismatch)
    end

    def initialize(*data)
      @data = data
    end

    def match?
      @data.last == :match
    end

    def mismatch?
      @data.last == :mismatch
    end

    def +(seq)
      Seq.new(*(to_a.concat(seq.to_a)))
    end

    def to_a
      @data.map do |d|
        case d
        when Seq
          d.to_a
        else
          d
        end
      end
    end
  end
end
