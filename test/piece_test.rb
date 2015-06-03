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

  def test_combination_by_yaml_anchors
    pieces = Piece.load(<<-YAML)
    role1: &role1
      posts: [new, create, destroy]
    role2: &role2
      comments: destroy
      users: '*'
    admin:
      <<: *role1
      <<: *role2
    YAML
    assert pieces.has?('admin:comments:destroy')
    assert pieces.has?('admin:users:new')
  end

  def test_union_abstraction_by_root_group_name
    pieces = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
    role2:
      comments: destroy
      users: '*'
    admin: role1 + role2
    YAML
    assert pieces.has?('admin:comments:destroy')
    assert pieces.has?('admin:users:new')
  end

  def test_subtraction_abstraction_by_root_group_name
    pieces = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
      comments: destroy
    role2:
      posts: [new, destroy]
      users: '*'
    admin: role1 - role2
    YAML

    assert pieces.has?('admin:posts:create')
    assert pieces.has?('admin:comments:destroy')
    assert !pieces.has?('admin:posts:destroy')
    assert !pieces.has?('admin:users:new')
  end

  def test_combination_of_abstractions
    pieces = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
      comments: destroy
    role2:
      posts: [new, destroy]
      users: '*'
    role3:
      posts: [new]
      users: [new]
    admin: role1 - role2
    super: role1 - role2 + role3
    YAML

    assert !pieces.has?('admin:posts:new')
    assert pieces.has?('super:posts:new')
    assert !pieces.has?('admin:users:new')
    assert pieces.has?('super:users:new')
  end

  def test_alias
    pieces = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
      comments: destroy
    role2: role1
    YAML

    assert pieces.has?('role1:posts:new')
    assert pieces.has?('role2:posts:new')
  end

  def test_confusing_duplicated_group_names
    pieces = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
      comments: destroy
    posts: role1
    comments:
      posts: [new]
    YAML

    assert pieces.has?('role1:posts:new')
    assert pieces.has?('posts:posts:new')
    assert pieces.has?('comments:posts:new')
    assert !pieces.has?('comments:posts:create')
  end

  def test_combination_of_abstraction_and_wildcard_char
    pieces = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
      comments: destroy
    role2:
      posts: [new, destroy]
      users: '*'
    role3:
      posts: [new]
      users: [new]
    admin: '* - role1'
    super: '* - role2 + role3'
    YAML

    assert !pieces.has?('admin:posts:new')
    assert pieces.has?('admin:users:new')

    assert pieces.has?('super:posts:new')
    assert pieces.has?('super:users:new')
    assert !pieces.has?('super:posts:destroy')
    assert !pieces.has?('super:users:create')
  end
end
