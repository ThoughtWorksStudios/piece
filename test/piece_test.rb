require "test_helper"

class PieceTest < Test::Unit::TestCase
  def test_load_pieces
    pieces = Piece.load(<<-YAML)
    admin:
      posts: [new, create, destroy]
      comments: destroy
      users: '*'
    super: '*'
    YAML
    assert pieces.has?("admin:comments:destroy")
    assert !pieces.has?("admin:comments:create")
    assert pieces.has?('admin:users:new')

    assert_equal ['destroy'], pieces['admin:comments']
    assert_equal ['new', 'create', 'destroy'], pieces['admin:posts']

    assert_equal '*', pieces['admin:comments:destroy']
    assert_equal '*', pieces['admin:comments:destroy:confirm']
    assert_nil pieces['admin:comments:new']
    assert_nil pieces['admin:comments:new:confirm']
    assert_nil pieces['admin:products']
    assert_nil pieces['admin:products:new']
    assert_nil pieces['user']

    assert_equal ['*'], pieces['admin:users']
    assert_equal '*', pieces['admin:users:new']

    assert_equal ['*'], pieces['super']
    assert pieces.has?('super:users')
    assert pieces.has?('super')
  end

  def test_does_not_support_wildcard_char_in_key
    pieces = Piece.load(<<-YAML)
    admin:
      posts: [new, create, destroy]
      comments: destroy
      users: '*'
    super: '*'
    YAML
    assert_raise(Piece::InvalidKey) { pieces.has?('super:*') }
    assert_raise(Piece::InvalidKey) { pieces.has?('admin:*:destroy') }
  end
end
