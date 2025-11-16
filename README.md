# GraphQLite

## Description

A lightweight, production-ready GraphQL implementation for Ruby with zero dependencies. GraphQLite is designed to be simple, minimal, and clean while maintaining full GraphQL spec compliance. It's easier to use and more straightforward than existing solutions.

## Features

- Zero runtime dependencies - pure Ruby implementation
- Simple, intuitive DSL for schema definition
- Full GraphQL spec compliance (October 2021)
- Production-ready with comprehensive error handling
- Complete introspection support
- Fast execution with efficient parser
- Clean, maintainable codebase

## Installation

Add to your Gemfile:

```ruby
gem 'graphqlite'
```

Or install directly:

```bash
gem install graphqlite
```

## Basic Usage

```ruby
require 'graphqlite'

schema = GraphQLite::Schema.new do
  query do
    field :hello, :String do
      "World"
    end
  end
end

result = schema.execute('{ hello }')
# => { "data" => { "hello" => "World" } }
```

## Available Usages

### Define Object Types

```ruby
object :User do
  field :id, :ID, null: false
  field :name, :String
  field :email, :String
end
```

### Query with Arguments

```ruby
query do
  field :user, :User do |f|
    f.argument :id, :ID
    f.resolve do |args|
      User.find(args[:id])
    end
  end
end
```

### Lists and Non-Null Types

```ruby
query do
  field :users, [:User] do    # List of users
    User.all
  end

  field :count, :Int, null: false do  # Required field
    User.count
  end
end
```

### Mutations

```ruby
mutation do
  field :createUser, :User do |f|
    f.argument :name, :String
    f.argument :email, :String
    f.resolve do |args|
      User.create(name: args[:name], email: args[:email])
    end
  end
end
```

### Execute with Variables

```ruby
query = 'query GetUser($id: ID!) { user(id: $id) { name } }'
result = schema.execute(query, variables: { 'id' => '123' })
```

### Execute with Context

```ruby
result = schema.execute(
  '{ me { name } }',
  context: { current_user: current_user }
)

# Access in resolvers
field :me, :User do |_, args, context|
  context[:current_user]
end
```

## Advanced Usage

### Custom Resolvers

```ruby
object :User do
  field :fullName, :String do |user|
    "#{user[:first_name]} #{user[:last_name]}"
  end

  field :posts, [:Post] do |user|
    Post.where(user_id: user[:id])
  end
end
```

### Enum Types

```ruby
enum :Role, values: {
  'ADMIN' => { value: 'admin', description: 'Administrator' },
  'USER' => { value: 'user', description: 'Regular user' },
  'GUEST' => { value: 'guest', description: 'Guest user' }
}

object :User do
  field :role, :Role
end
```

### Custom Scalars

```ruby
scalar :DateTime,
  description: 'ISO 8601 datetime',
  serialize: ->(value) { value.iso8601 },
  parse_value: ->(value) { Time.parse(value) },
  parse_literal: ->(value) {
    value.is_a?(Parser::StringValue) ? Time.parse(value.value) : nil
  }
```

### Introspection

```ruby
# Schema introspection
schema.execute('{ __schema { types { name } } }')

# Type introspection
schema.execute('{ __type(name: "User") { name fields { name } } }')

# Typename in queries
schema.execute('{ user { __typename id } }')
```

## Detailed Documentation

### Built-in Scalar Types

- `Int` - 32-bit signed integer
- `Float` - Double-precision floating-point
- `String` - UTF-8 character sequence
- `Boolean` - true or false
- `ID` - Unique identifier (serialized as string)

### Schema Definition API

**Object Types**
```ruby
object :TypeName do
  field :fieldName, :FieldType
  field :requiredField, :Type, null: false
  field :listField, [:Type]
  field :computedField, :Type do |object, args, context|
    # resolver logic
  end
end
```

**Fields with Arguments**
```ruby
field :search, [:User] do |f|
  f.argument :query, :String
  f.argument :limit, :Int
  f.resolve do |args, context|
    User.search(args[:query]).limit(args[:limit] || 10)
  end
end
```

**Query Root**
```ruby
query do
  field :fieldName, :Type do |f|
    f.argument :arg, :ArgType
    f.resolve { |args| ... }
  end
end
```

**Mutation Root**
```ruby
mutation do
  field :actionName, :ReturnType do |f|
    f.argument :input, :InputType
    f.resolve { |args| ... }
  end
end
```

### Query Execution API

```ruby
# Basic execution
schema.execute(query_string)

# With variables
schema.execute(query_string, variables: { 'key' => 'value' })

# With context
schema.execute(query_string, context: { user: current_user })

# Combined
schema.execute(
  query_string,
  variables: variables_hash,
  context: context_hash
)
```

### Error Handling

GraphQLite automatically validates and reports errors:

```ruby
result = schema.execute('{ invalidField }')
# => { "errors" => [{ "message" => "Field 'invalidField' does not exist..." }] }
```

Errors include:
- Syntax errors in queries
- Field validation errors
- Type mismatch errors
- Argument validation errors
- Runtime resolver errors

### Complete Example

```ruby
schema = GraphQLite::Schema.new do
  enum :Status, values: {
    'ACTIVE' => { value: 'active' },
    'INACTIVE' => { value: 'inactive' }
  }

  object :Post do
    field :id, :ID, null: false
    field :title, :String
    field :content, :String
    field :status, :Status
    field :author, :User do |post|
      User.find(post[:author_id])
    end
  end

  object :User do
    field :id, :ID, null: false
    field :name, :String
    field :email, :String
    field :posts, [:Post] do |user|
      Post.where(author_id: user[:id])
    end
  end

  query do
    field :user, :User do |f|
      f.argument :id, :ID
      f.resolve { |args| User.find(args[:id]) }
    end

    field :posts, [:Post] do |f|
      f.argument :status, :Status
      f.resolve do |args|
        query = Post.all
        query = query.where(status: args[:status]) if args[:status]
        query
      end
    end
  end

  mutation do
    field :createPost, :Post do |f|
      f.argument :title, :String
      f.argument :content, :String
      f.argument :authorId, :ID
      f.resolve do |args|
        Post.create(
          title: args[:title],
          content: args[:content],
          author_id: args[:authorId]
        )
      end
    end
  end
end

# Execute queries
schema.execute('{ posts { title author { name } } }')
schema.execute('{ posts(status: ACTIVE) { title } }')

# Execute mutations
mutation = 'mutation { createPost(title: "Hello", content: "World", authorId: "1") { id } }'
schema.execute(mutation)
```

## License

MIT License
