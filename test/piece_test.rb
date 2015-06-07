require "test_helper"

class PieceTest < Test::Unit::TestCase
  def test_load_and_match_rules
    rules = Piece.load(<<-YAML)
    admin:
      posts: [new, create, destroy]
      comments: destroy
      users: '*'
    super: '*'
    YAML
    assert_equal ['admin', 'comments', 'destroy', :match], rules["admin:comments:destroy"]
    assert_equal ['admin', 'comments', 'destroy', :mismatch], rules["admin:comments:create"]
    assert_equal ['admin', 'users', '*', :match],  rules['admin:users:new']
    assert_equal ['admin', 'comments', :match], rules['admin:comments']
    assert_equal ['admin', 'posts', :match], rules['admin:posts']
    assert_equal ['admin', 'comments', 'destroy', :mismatch], rules['admin:comments:destroy:confirm']

    assert_equal ['admin', 'comments', 'destroy', :mismatch], rules['admin:comments:new']
    assert_equal ['admin', 'comments', 'destroy', :mismatch], rules['admin:comments:new:confirm']
    assert_equal ['admin', 'products', :mismatch], rules['admin:products']
    assert_equal ['admin', 'products', :mismatch], rules['admin:products:new']
    assert_equal ['user', :mismatch], rules['user']

    assert_equal ['admin', 'users', :match], rules['admin:users']
    assert_equal ['admin', 'users', '*', :match], rules['admin:users:new']

    assert_equal ['super', :match], rules['super']

    assert_equal ['super', '*', :match], rules['super:users']
    assert_equal ['super', :match], rules['super']
  end

  def test_match?
    rules = Piece.load(<<-YAML)
    admin:
      posts: [new, create, destroy]
      comments: destroy
      users: '*'
    super: '*'
    YAML
    assert rules.match?("admin:comments:destroy")
    assert_false rules.match?("admin:comments:new")
  end

  def test_does_not_support_wildcard_char_while_matching_action
    rules = Piece.load(<<-YAML)
    admin:
      posts: [new, create, destroy]
      comments: destroy
      users: '*'
    super: '*'
    YAML
    assert_raise(Piece::InvalidAction) { rules['super:*'] }
    assert_raise(Piece::InvalidAction) { rules['admin:*:destroy'] }
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
    assert_equal ['admin', 'comments', 'destroy', :match], rules['admin:comments:destroy']
    assert_equal ['admin', 'users', '*', :match], rules['admin:users:new']
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
    assert_equal ['admin', "role1 + role2", ["role2", 'comments', 'destroy', :match], :match], rules['admin:comments:destroy']
    assert_equal ['admin', "role1 + role2", ["role2", 'users', '*', :match], :match], rules['admin:users:new']
  end

  def test_union_group_that_does_not_exist
    rules = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
    admin1: role1 + role2
    admin2: role1 - role2
    YAML

    assert_raise Piece::UnknownRuleGroupName do
      rules['admin1:posts:destroy']
    end
    assert_raise Piece::UnknownRuleGroupName do
      rules['admin1:users:new']
    end
    assert_raise Piece::UnknownRuleGroupName do
      rules['admin2:posts:destroy']
    end
    assert_raise Piece::UnknownRuleGroupName do
      rules['admin2:users:new']
    end
  end

  def test_group_subtraction
    rules = Piece.load(<<-YAML)
    super: '*'
    role1:
      posts: [new, create, destroy]
      comments: destroy
    role2:
      posts: [new, destroy]
      users: '*'
    admin: role1 - role2
    admin2: super - role1
    YAML

    assert_equal ['admin', 'role1 - role2', ['role1', 'posts', 'create', :match], ["role2", "posts", ["new", "destroy"], :mismatch], :match], rules['admin:posts:create']
    assert_equal ['admin', 'role1 - role2', ['role1', 'comments', 'destroy', :match], ["role2", "comments", :mismatch], :match], rules['admin:comments:destroy']
    assert_equal ['admin', 'role1 - role2', ['role2', 'posts', 'destroy', :match], :mismatch], rules['admin:posts:destroy']
    assert_equal ['admin', 'role1 - role2', ['role1', 'users', :mismatch], :mismatch], rules['admin:users:new']

    assert_equal ["admin2", "super - role1", ["super", "*", :match], ["role1", "posts", ["new", "create", "destroy"], :mismatch], :match], rules['admin2:posts:index']
    assert_equal ["admin2", "super - role1", ["role1", "posts", "create", :match], :mismatch], rules['admin2:posts:create']
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

    assert_equal ["admin", "role1 - role2", ["role2", "posts", "new", :match], :mismatch], rules['admin:posts:new']
    assert_equal ["super", "role1 - role2 + role3", ["role3", "posts", "new", :match], :match], rules['super:posts:new']
    assert_equal ["admin", "role1 - role2", ["role1", "users", :mismatch], :mismatch], rules['admin:users:new']
    assert_equal ["super", "role1 - role2 + role3", ["role3", "users", "new", :match], :match], rules['super:users:new']
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

    assert_equal ["admin", "role1 + role4", ["role1", "posts", "destroy", :match], :match], rules['admin:posts:destroy']
    assert_equal ["admin", "role1 + role4", ["role4", "role2 - role3", ["role2", "users", "*", :match], ["role3", "users", ["new"], :mismatch], :match], :match], rules['admin:users:destroy']
    assert_equal ["admin", "role1 + role4", ["role1", "comments", "destroy", :match], :match], rules['admin:comments:destroy']

    # notice: admin = role1 + role4 = role1 + (role2 - role3)
    #         admin != role1 + role2 - role3
    # For rule2 in role1 and role3, because (role2 - role3) happens
    #        first,
    # role1 is plusing the result of (role2 - role3), hence role1 will
    # keep rules defined in role3
    assert_equal ["admin", "role1 + role4", ["role1", "posts", "new", :match], :match], rules['admin:posts:new']
    # 'admin:users:new' is removed as role2 - role3 and role1 does not
    #         have this rule defined
    assert_equal ["admin", "role1 + role4", ["role1", "users", :mismatch], ["role4", "role2 - role3", ["role3", "users", "new", :match], :mismatch], :mismatch], rules['admin:users:new']
  end

  def test_alias_root_group_name
    rules = Piece.load(<<-YAML)
    role1:
      posts: [new, create, destroy]
      comments: destroy
    role2: role1
    YAML

    assert_equal ["role1", "posts", "new", :match], rules['role1:posts:new']
    assert_equal ["role2", "role1", "role1", "posts", "new", :match], rules['role2:posts:new']
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

    assert_equal ["role1", "posts", "new", :match], rules['role1:posts:new']
    assert_equal ["posts", "role1", "role1", "posts", "new", :match], rules['posts:posts:new']
    assert_equal ["comments", "posts", "new", :match], rules['comments:posts:new']
    assert_equal ["comments", "posts", ["new"], :mismatch], rules['comments:posts:create']
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

    assert_equal ["admin", "* - role1", ["role1", "posts", "new", :match], :mismatch], rules['admin:posts:new']
    assert_equal ["admin", "* - role1", [:match], ["role1", "users", :mismatch], :match], rules['admin:users:new']

    assert_equal ["super", "* - role2 + role3", ["role3", "posts", "new", :match], :match], rules['super:posts:new']
    assert_equal ["super", "* - role2 + role3", ["role3", "users", "new", :match], :match], rules['super:users:new']
    assert_equal ["super", "* - role2 + role3", [["role2", "posts", "destroy", :match], :mismatch], ["role3", "posts", ["new"], :mismatch], :mismatch], rules['super:posts:destroy']
    assert_equal ["super", "* - role2 + role3", [["role2", "users", "*", :match], :mismatch], ["role3", "users", ["new"], :mismatch], :mismatch], rules['super:users:create']
  end

  def test_append_rules
    rules = Piece.rules
    rules << 'admin:posts:new,create,destroy'
    rules << 'admin: comments: [new,destroy]'
    rules << 'admin:users:*'
    rules << 'super:users:*'
    rules << 'hero: admin - super'
    rules.add 'hello:*'
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
    assert rules.match?(:admin, :posts, :new)
    assert rules.match?('admin', 'posts:new')
    assert_equal :match, rules['admin', 'posts:new'].last
    assert_equal :match, rules[['admin', 'posts:new']].last
  end

  def test_append_rule_that_is_array_format
    rules = Piece.rules
    rules << ['admin', 'posts', "*"]
    rules << [:admin, :users, :'*']
    rules << ["admin:comments:[*]"]
    rules << ['admin', 'blog', ['new', 'create']]
    assert rules.match?('admin:posts:new')
    assert rules.match?('admin:users:new')
    assert rules.match?('admin:comments:new')
    assert rules.match?('admin:blog:new')
  end

  def test_delete_rule
    rules = Piece.rules
    rules << ['admin', 'posts', "*"]
    rules << ['admin', 'comments', ['new', 'create']]
    rules.delete('admin', 'posts', '*')
    rules.delete('admin', 'comments', "new")
    assert !rules.match?('admin:posts:new')
    assert !rules.match?('admin:posts:create')

    assert !rules.match?('admin:comments:new')
    assert rules.match?('admin:comments:create')
    rules.delete('admin', 'comments', "create")

    assert !rules.match?('admin:comments:create')
    assert !rules.match?('admin:comments')
  end

  def test_example1
    rules = Piece.load(<<-YAML)
all: '*'
admin_only:
  admins: all
  organizations: [new, create, destroy]
  users: [new, edit, create, update, destroy]
json: all
html:
  admin: all
  readonly: all - admin_only
YAML
    assert_equal ["html", "readonly", "all - admin_only", ["all", "*", :match], ["admin_only", "organizations", ["new", "create", "destroy"], :mismatch], :match], rules['html:readonly:organizations:index']
  end

end
