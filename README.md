# GraphQLite

A lightweight, production-ready GraphQL implementation for Ruby with **zero dependencies**. GraphQLite is designed to be simple, minimal, clean, and easier to use than existing solutions while maintaining full GraphQL spec compliance.

## Features

- **Zero runtime dependencies** - Pure Ruby implementation
- **Simple, intuitive DSL** - Define schemas with minimal code
- **Full GraphQL spec compliance** - Implements the October 2021 GraphQL specification
- **Production ready** - Comprehensive error handling and validation
- **Fast execution** - Efficient parser and executor
- **Complete introspection** - Full support for GraphQL introspection queries
- **Clean codebase** - Easy to understand and extend

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'graphqlite'
```

Or install it yourself:

```bash
gem install graphqlite
```

## Quick Start

```ruby
require 'graphqlite'

# Define your schema
schema = GraphQLite::Schema.new do
  query do
    field :hello, :String do
      "World"
    end

    field :user, :User do |f|
      f.argument :id, :ID
      f.resolve do |args|
        { id: args[:id], name: "John Doe", email: "john@example.com" }
      end
    end
  end

  object :User do
    field :id, :ID, null: false
    field :name, :String
    field :email, :String
  end
end

# Execute queries
result = schema.execute('{ hello }')
# => { "data" => { "hello" => "World" } }

result = schema.execute('{ user(id: "123") { id name email } }')
# => { "data" => { "user" => { "id" => "123", "name" => "John Doe", "email" => "john@example.com" } } }
```

## Schema Definition

### Object Types

Define object types with fields:

```ruby
schema = GraphQLite::Schema.new do
  object :User do
    field :id, :ID, null: false
    field :name, :String
    field :email, :String
    field :age, :Int
    field :active, :Boolean
  end
end
```

### Fields with Resolvers

Fields can have custom resolvers:

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

### Fields with Arguments

Add arguments to fields:

```ruby
query do
  field :user, :User do |f|
    f.argument :id, :ID
    f.resolve do |args|
      User.find(args[:id])
    end
  end

  field :search, [:User] do |f|
    f.argument :query, :String
    f.argument :limit, :Int
    f.resolve do |args|
      User.search(args[:query]).limit(args[:limit] || 10)
    end
  end
end
```

### Enum Types

Define enums:

```ruby
enum :Role, values: {
  'ADMIN' => { value: 'admin', description: 'Administrator role' },
  'USER' => { value: 'user', description: 'Regular user role' },
  'GUEST' => { value: 'guest', description: 'Guest role' }
}

object :User do
  field :role, :Role
end
```

### List Types

Use array notation for lists:

```ruby
query do
  field :users, [:User] do
    User.all
  end

  field :numbers, [:Int] do
    [1, 2, 3, 4, 5]
  end
end
```

### Non-Null Types

Use `null: false` to make fields required:

```ruby
object :User do
  field :id, :ID, null: false  # Required field
  field :name, :String          # Optional field
end
```

### Mutations

Define mutations:

```ruby
mutation do
  field :createUser, :User do |f|
    f.argument :name, :String
    f.argument :email, :String
    f.resolve do |args|
      user = User.create(name: args[:name], email: args[:email])
      { id: user.id, name: user.name, email: user.email }
    end
  end

  field :deleteUser, :Boolean do |f|
    f.argument :id, :ID
    f.resolve do |args|
      User.find(args[:id]).destroy
      true
    end
  end
end
```

## Query Execution

### Basic Execution

```ruby
result = schema.execute('{ hello }')
# => { "data" => { "hello" => "World" } }
```

### With Variables

```ruby
query = 'query GetUser($id: ID!) { user(id: $id) { name } }'
result = schema.execute(query, variables: { 'id' => '123' })
# => { "data" => { "user" => { "name" => "John Doe" } } }
```

### With Context

Pass context to all resolvers:

```ruby
result = schema.execute(
  '{ me { name } }',
  context: { current_user: current_user }
)

# Access context in resolvers
query do
  field :me, :User do |_, args, context|
    context[:current_user]
  end
end
```

### Error Handling

GraphQLite automatically handles errors:

```ruby
result = schema.execute('{ nonexistent }')
# => { "errors" => [{ "message" => "Field 'nonexistent' does not exist on type 'Query'" }] }
```

## Built-in Scalars

GraphQLite includes all standard GraphQL scalars:

- `Int` - Signed 32-bit integer
- `Float` - Signed double-precision floating-point value
- `String` - UTF-8 character sequence
- `Boolean` - true or false
- `ID` - Unique identifier (serialized as string)

## Custom Scalars

Define custom scalar types:

```ruby
scalar :DateTime,
  description: 'ISO 8601 datetime',
  serialize: ->(value) { value.iso8601 },
  parse_value: ->(value) { Time.parse(value) },
  parse_literal: ->(value) { value.is_a?(Parser::StringValue) ? Time.parse(value.value) : nil }
```

## Introspection

GraphQLite fully supports introspection:

```ruby
# Get schema information
result = schema.execute('{ __schema { types { name } } }')

# Get type information
result = schema.execute('{ __type(name: "User") { name fields { name type { name } } } }')

# Get typename
result = schema.execute('{ user { __typename id } }')
# => { "data" => { "user" => { "__typename" => "User", "id" => "123" } } }
```

## Comparison with graphql-ruby

GraphQLite is designed to be simpler and more lightweight than the popular `graphql` gem:

| Feature | GraphQLite | graphql-ruby |
|---------|-----------|--------------|
| Runtime Dependencies | **0** | 3 |
| Schema Definition | Clean DSL | Class-based or DSL |
| Learning Curve | Low | Moderate |
| Performance | Fast | Fast |
| Spec Compliance | Full | Full |
| Introspection | Full | Full |

## Example: Blog API

```ruby
schema = GraphQLite::Schema.new do
  enum :PostStatus, values: {
    'DRAFT' => { value: 'draft' },
    'PUBLISHED' => { value: 'published' },
    'ARCHIVED' => { value: 'archived' }
  }

  object :Author do
    field :id, :ID, null: false
    field :name, :String
    field :email, :String
    field :posts, [:Post] do |author|
      Post.where(author_id: author[:id])
    end
  end

  object :Post do
    field :id, :ID, null: false
    field :title, :String
    field :content, :String
    field :status, :PostStatus
    field :author, :Author do |post|
      Author.find(post[:author_id])
    end
  end

  query do
    field :post, :Post do |f|
      f.argument :id, :ID
      f.resolve { |args| Post.find(args[:id]) }
    end

    field :posts, [:Post] do |f|
      f.argument :status, :PostStatus
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
          author_id: args[:authorId],
          status: 'draft'
        )
      end
    end

    field :publishPost, :Post do |f|
      f.argument :id, :ID
      f.resolve do |args|
        post = Post.find(args[:id])
        post.update(status: 'published')
        post
      end
    end
  end
end

# Query examples
result = schema.execute('{ posts { id title author { name } } }')
result = schema.execute('{ posts(status: PUBLISHED) { title } }')

# Mutation example
mutation = 'mutation { createPost(title: "Hello", content: "World", authorId: "1") { id } }'
result = schema.execute(mutation)
```

## Testing

Run the test suite:

```bash
rake test
```

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the MIT License.

## Credits

Created with ❤️ to provide a lightweight, production-ready GraphQL solution for Ruby.
