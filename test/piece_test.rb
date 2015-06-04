require "test_helper"

class PieceTest < Test::Unit::TestCase
  def test_load_and_use_rules
    rules = Piece.load(<<-YAML)
    admin:
      posts: [new, create, destroy]
      comments: destroy
      users: '*'
    super: '*'
    YAML
    assert rules.match?("admin:comments:destroy")
    assert !rules.match?("admin:comments:create")
    assert rules.match?('admin:users:new')

    assert_equal ['destroy'], rules['admin:comments']
    assert_equal ['new', 'create', 'destroy'], rules['admin:posts']

    assert_equal '*', rules['admin:comments:destroy']
    assert_equal '*', rules['admin:comments:destroy:confirm']
    assert_nil rules['admin:comments:new']
    assert_nil rules['admin:comments:new:confirm']
    assert_nil rules['admin:products']
    assert_nil rules['admin:products:new']
    assert_nil rules['user']

    assert_equal ['*'], rules['admin:users']
    assert_equal '*', rules['admin:users:new']

    assert_equal ['*'], rules['super']
    assert rules.match?('super:users')
    assert rules.match?('super')
  end

  def test_does_not_support_wildcard_char_while_matching_action
    rules = Piece.load(<<-YAML)
    admin:
      posts: [new, create, destroy]
      comments: destroy
      users: '*'
    super: '*'
    YAML
    assert_raise(Piece::InvalidAction) { rules.match?('super:*') }
    assert_raise(Piece::InvalidAction) { rules.match?('admin:*:destroy') }
  end

  def test_load_rules_from_yaml_using_anchors
    rules = Piece.load(<<-YAML)
    role1: &role1
      posts: [new, create, destroy]
    role2: &role2
      comments: destroy
      users: '*'
    admin:
      <<: *role1
      <<: *role2
    YAML
    assert rules.match?('admin:comments:destroy')
    assert rules.match?('admin:users:new')
  end

  def test_union_groups_by_root_group_name
    rules = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
    role2:
      comments: destroy
      users: '*'
    admin: role1 + role2
    YAML
    assert rules.match?('admin:comments:destroy')
    assert rules.match?('admin:users:new')
  end

  def test_union_group_that_does_not_exist
    rules = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
    admin1: role1 + role2
    admin2: role1 - role2
    YAML
    assert rules.match?('admin1:posts:destroy')
    assert !rules.match?('admin1:users:new')

    assert rules.match?('admin1:role2')
    assert !rules.match?('admin1:role1')

    assert rules.match?('admin2:posts:destroy')
    assert !rules.match?('admin2:users:new')

    assert !rules.match?('admin2:role2')
    assert !rules.match?('admin2:role1')
  end

  def test_group_subtraction
    rules = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
      comments: destroy
    role2:
      posts: [new, destroy]
      users: '*'
    admin: role1 - role2
    YAML

    assert rules.match?('admin:posts:create')
    assert rules.match?('admin:comments:destroy')
    assert !rules.match?('admin:posts:destroy')
    assert !rules.match?('admin:users:new')
  end

  def test_combination_of_group_union_and_subtraction
    rules = Piece.load(<<-YAML)
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

    assert !rules.match?('admin:posts:new')
    assert rules.match?('super:posts:new')
    assert !rules.match?('admin:users:new')
    assert rules.match?('super:users:new')
  end

  def test_multiple_levels_reference
    rules = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
      comments: destroy
    role2:
      posts: [new, destroy]
      users: '*'
      comments: new
    role3:
      posts: [new]
      users: [new]
      comments: new
    role4: role2 - role3
    admin: role1 + role4
    YAML

    assert rules.match?('admin:posts:destroy')
    assert rules.match?('admin:users:destroy')
    assert rules.match?('admin:comments:destroy')

    # notice: admin = role1 + role4 = role1 + (role2 - role3)
    #         admin != role1 + role2 - role3
    # For rule2 in role1 and role3, because (role2 - role3) happens
    #        first,
    # role1 is plusing the result of (role2 - role3), hence role1 will
    # keep rules defined in role3
    assert rules.match?('admin:posts:new')
    # 'admin:users:new' is removed as role2 - role3 and role1 does not
    #         have this rule defined
    assert !rules.match?('admin:users:new')
  end

  def test_alias_root_group_name
    rules = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
      comments: destroy
    role2: role1
    YAML

    assert rules.match?('role1:posts:new')
    assert rules.match?('role2:posts:new')
  end

  def test_duplicated_group_names_behaviors
    rules = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
      comments: destroy
    posts: role1
    comments:
      posts: [new]
    YAML

    assert rules.match?('role1:posts:new')
    assert rules.match?('posts:posts:new')
    assert rules.match?('comments:posts:new')
    assert !rules.match?('comments:posts:create')
  end

  def test_combination_of_abstraction_and_wildcard_char
    rules = Piece.load(<<-YAML)
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

    assert !rules.match?('admin:posts:new')
    assert rules.match?('admin:users:new')

    assert rules.match?('super:posts:new')
    assert rules.match?('super:users:new')
    assert !rules.match?('super:posts:destroy')
    assert !rules.match?('super:users:create')
  end

  def test_append_rules
    rules = Piece.rules
    rules << 'admin:posts:new,create,destroy'
    rules << 'admin: comments: [new,destroy]'
    rules << 'admin:users:*'
    rules << 'super:users:*'
    rules << 'hero: admin - super'
    rules << 'hello:*'
    assert rules.match?('admin:users:new')
    assert rules.match?('admin:posts:new')
    assert rules.match?('admin:comments:new')
    assert !rules.match?('admin:posts:update')
    assert rules.match?('super:users:new')

    assert rules.match?('hero:posts:new')
    assert !rules.match?('hero:users:new')

    assert rules.match?('hello:world')
  end

  def test_dequote_action_format_rules
    rules = Piece.rules
    rules << 'admin:posts:"*"'
    rules << "admin:users:'*'"
    rules << "admin:comments:[*]"
    assert rules.match?('admin:posts:new')
    assert rules.match?('admin:users:new')
    assert rules.match?('admin:comments:new')
  end

  def test_match_with_an_array_of_action_parts
    rules = Piece.rules
    rules << 'admin:posts:*'
    assert rules.match?('admin', 'posts', 'new')
    assert rules.match?('admin', 'posts:new')
    assert_equal '*', rules['admin', 'posts:new']
  end
end
