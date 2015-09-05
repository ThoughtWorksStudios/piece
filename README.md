# Piece [![Build Status](https://snap-ci.com/ThoughtWorksStudios/piece/branch/master/build_image)](https://snap-ci.com/ThoughtWorksStudios/piece/branch/master)

[Built with :yellow_heart: and :coffee: in San Francisco](http://thoughtworks.com/mingle/team)

Piece is built for managing access control (e.g. user privileges, feature toggles) of an application.

## A rule engine for you

1. Define access control rules
2. Combine rules to construct new rules

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'piece'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install piece

## Usage

You can find full example with running Rails application [here](https://github.com/xli/piece-blog).

Define rules config/privileges.yml

    writer:
      posts: '*'
    admin: '*'
    author: writer + anonymous
    anonymous:
      users: [login, logout, new, create]
      posts: [index, show]

Load rules from YAML file

    rules = Piece.load(File.read(Rails.root.join('config', 'privileges.yml')))

Setup Rails controller:

    before_action :authorize
    ...

    private
    def current_action
      [current_user.try(:role) || 'anonymous', controller_name, action_name]
    end

    def authorize
      seq = Rails.configuration.privileges[current_action]
      if seq.last == :mismatch
        flash.now[:error] = "You're not authorized to do this action."
        render "layouts/401", status: :unauthorized
      end
    end

## Define rules

### Concepts

1. Wildcard char: *, matching everything.
2. All rules can be defined in a YAML file.
3. A rule is defined by multi-levels group names in YAML format.
4. Too keep example simple, we also call root group name "role name".
5. Use `+` to combine 2 roles.
6. Use `-` to exclude rules defined by another role.
7. Use Array (e.g. [login, logout, new, create]) to define multiple matchings at the lowest level.

### Example

A rule defined by multi-levels group names in YAML format:

    # Anonymous is root group, users and posts are sub-groups of anonymous.
    anonymous:
      users: [login, logout, new, create]
      posts: [index, show]

A rule can also be defined as the following format for role based access control:

    role_name:controller_name:action_names

For example, previous YAML format rules can be defined as:

    rules = Piece.rules
    rules << 'writer:posts:*'
    rules << 'admin:*'
    rules << 'author:writer + anonymous'
    rules << 'anonymous:users:[login, logout, new, create]'
    rules << 'anonymous:posts:[index, show]'

Combine multiple rules to define a new rule:

    # union 2 rules
    rules << 'author:writer + anonymous'

    # subtract rules, the following 'user' role is defined by subtracting 'admin_only' role from 'admin' role
    rules << 'user:admin - admin_only'

## Rule matching and explanation

APIs for matching and explanation:

    rules[user_access_string]        => an explanation Array with :match or :mismatch at last
    rules.match?(user_access_string) => true or false

Example:

    rules = Piece.load(<<-YAML)
      writer:
        posts: '*'
      admin: '*'
      author: writer + anonymous
      anonymous:
        users: [login, logout, new, create]
        posts: [index, show]
    YAML

We defined rule 'admin: *', hence it will match anything start with 'admin:'

    rules["admin:comments:destroy"]        => ['admin', 'comments', 'destroy', :match]
    rules.match?('admin:comments:destroy') => true
    rules["admin:anything"]                => ['admin', 'anything', :match]
    rules.match?('admin:anything')         => true

We defined rule 'writer:posts:*', hence it will match anything start with 'writer:posts:'

    rules["writer:comments:destroy"]         => ['admin', :mismatch]
    rules.match?('writer:comments:destroy')  => false
    rules["writer:posts:new"]                => ['admin', 'posts', 'new', :match]
    rules.match?('writer:posts:new')         => true

We defined rule 'author: writer + anonymous', hence it will match anything matches writer or anonymous role.

    rules["author:posts:new"]                => ['author', 'writer + anonymous', ['writer', 'posts', 'new', :match], :match]
    rules.match?('author:posts:new')         => true

We don't have role 'terminator' defined, so anything start with 'terminator:' won't match anything:

    rules["terminator:posts:new"]            => ['terminator', :mismatch]
    rules.match?('terminator:posts:new')     => false

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ThoughtWorksStudios/piece.
