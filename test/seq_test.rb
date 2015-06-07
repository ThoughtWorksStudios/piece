require "test_helper"

class SeqTest < Test::Unit::TestCase
  include Piece

  def test_plus
    ab = Seq['a'] + Seq['b']
    assert_equal ['a', 'b'], ab.to_a
  end

  def test_match
    assert_equal [:match], Seq.match.to_a
    assert Seq.match.match?
    assert Seq.match(true).match?
    assert_false Seq.match(false).match?

    assert (Seq['a'] + Seq.match).match?
    assert_false (Seq.match + Seq['a']).match?
  end

  def test_mismatch
    assert_equal [:mismatch], Seq.mismatch.to_a
    assert_false Seq.match.mismatch?
    assert_false Seq.match(true).mismatch?
    assert Seq.match(false).mismatch?

    assert (Seq['a'] + Seq.mismatch).mismatch?
    assert_false (Seq.mismatch + Seq['a']).mismatch?
  end

  def test_combine_seqs
    ab = Seq['a'] + Seq['b']
    cd = Seq['c'] + Seq['d']
    abcd = Seq[ab] + Seq[cd]
    assert_equal [['a', 'b'], ['c', 'd']], abcd.to_a

    e = Seq['e'] + abcd
    assert_equal ['e', ['a', 'b'], ['c', 'd']], e.to_a

    em = e + Seq.match
    assert_equal ['e', ['a', 'b'], ['c', 'd'], :match], em.to_a
    assert em.match?
    assert_false em.mismatch?
  end
end
