# Flippant

Fast feature toggling for ruby applications, backed by Redis.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'flippant'
```

## Usage

Flippant composes three constructs to determine whether a feature is enabled:

* Actors - An actor can be any value, but typically it is a `User` or
  some other object representing a user.
* Groups - Groups are used to identify and qualify actors. For example,
  "everybody", "nobody", "admins", "staff", "testers" could all be groups names.
* Rules - Rules represent individual features which are evaluated against actors
  and groups. For example, "search", "analytics", "super-secret-feature" could
  all be rule names.

Group names may be either strings or symbols.

Let's walk through setting up a few example groups and rules. You'll want to
establish groups at startup, as they aren't likely to change (and defining
functions from a web interface isn't wise).

### Groups

First, a group that nobody can belong to. This is useful for disabling a feature
without deleting it:

```ruby
Flippant.register("nobody", ->(actor, _) { false })
```

Now the opposite, a group that everybody can belong to:

```ruby
Flippant.register("everybody", ->(actor, _) { true })
```

To be more exclusive and define staff-only features we need a "staff" group:

```ruby
Flippant.register("staff", ->(actor, _) { actor.staff? })
```

Lastly, we'll roll out a feature out to a percentage of the actors:

```ruby
Flippant.register("adopters", ->(actor, buckets) { buckets.include?(actor.id % 10) })
```

To tidy up a bit, we can define the registered group detection functions in a separate module.

```ruby
module FeatureGroups
  def self.premium_subscriber?(actor, _)
    actor.premium_subscriber?
  end

  def self.allowed_user?(actor, allowed_ids)
    allowed_ids.include?(actor.id)
  end
end

Flippant.register("premium_subscriber", &FeatureGroups.method(:premium_subscriber?))
Flippant.register("allowed_user", &FeatureGroups.method(:allowed_user?))
```


With some core groups defined we now can set up some rules.

### Rules

Rules are comprised of a name, a group, and an optional set of values. Starting
with a simple example that builds on the groups we have already created, we'll
enable the "search" feature:

```ruby
# Any staff can use the "search" feature
Flippant.enable("search", "staff")

# 30% of "adopters" can use the "search" feature as well
Flippant.enable("search", "adopters", [0, 1, 2])
```

Because rules are only built of binaries and simple data they can be defined or
refined at runtime. In fact, this is a crucial part of feature toggling. With a
web interface rules can be added, removed, or modified.

```ruby
# Turn search off for adopters
Flippant.disable("search", "adopters")

# On second thought, enable it again for 10%
Flippant.enable("search", "adopters", [3])
```

With a set of groups and rules defined we can check whether a feature is
enabled for a particular actor:

```ruby
class User
  attr_accessor :id, :is_staff

  def initialize(id, is_staff)
    @id = id
    @is_staff = is_staff
  end

  def staff?
    @is_staff
  end
end

staff_user = User.new(1, true)
early_user = User.new(2, false)
later_user = User.new(3, false)

Flippant.enabled?("search", staff_user) #=> true, staff
Flippant.enabled?("search", early_user) #=> false, not an adopter
Flippant.enabled?("search", later_user) #=> true, is an adopter
```

If an actor qualifies for multiple groups and *any* of the rules evaluate to
true that feature will be enabled for them. Think of the "nobody" and
"everybody" groups that were defined earlier:

```ruby
Flippant.enable("search", "everybody")
Flippant.enable("search", "nobody")

Flippant.enabled?("search", User.new) #=> true
```

## Breakdown

Evaluating rules requires a round trip to the database. Clearly, with a lot of
rules it is inefficient to evaluate each one individually. There is a function
to help with this exact scenario:

```ruby
Flippant.enable("search", "staff")
Flippant.enable("delete", "everybody")
Flippant.enable("invite", "nobody")

user = User.new(1, true)
Flippant.breakdown(user) #=> {
  "search" => true,
  "delete" => true,
  "invite" => false
}
```

The breakdown is a simple hash of string keys to boolean values. This is
extremely handy for single page applications where you can serialize the
breakdown on boot or send it back from an endpoint as JSON.

## Configuration

Both Redis and Memory adapters are available for Flippant's registry storage. Memory
is the default.

The Memory adapter behaves identically to the Redis adapter, but will clear out
its registry whenever the application is reloaded, so it may be especially useful
in testing.

You may want to change this to Redis in production by overriding the `adapter` setting.

```ruby
# In Rails, for instance, add this to `config/initializers/flippant.rb`:
Flippant.adapter = if Rails.env.test?
                     Flippant::Adapter::Memory.new
                   else
                     Flippant::Adapter::Redis.new
                   end
```

## License

MIT License, see [LICENSE.txt](LICENSE.txt) for details.
