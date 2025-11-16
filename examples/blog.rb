#!/usr/bin/env ruby

require_relative '../lib/graphqlite'

# Mock database
class DB
  @posts = [
    { id: '1', title: 'First Post', content: 'Hello World', author_id: '1', status: 'published' },
    { id: '2', title: 'Second Post', content: 'GraphQL is awesome', author_id: '1', status: 'published' },
    { id: '3', title: 'Draft Post', content: 'Work in progress', author_id: '2', status: 'draft' }
  ]

  @authors = [
    { id: '1', name: 'Alice', email: 'alice@example.com' },
    { id: '2', name: 'Bob', email: 'bob@example.com' }
  ]

  class << self
    attr_reader :posts, :authors

    def find_post(id)
      @posts.find { |p| p[:id] == id }
    end

    def find_author(id)
      @authors.find { |a| a[:id] == id }
    end

    def posts_by_author(author_id)
      @posts.select { |p| p[:author_id] == author_id }
    end

    def posts_by_status(status)
      @posts.select { |p| p[:status] == status }
    end

    def create_post(title:, content:, author_id:)
      post = {
        id: (@posts.length + 1).to_s,
        title: title,
        content: content,
        author_id: author_id,
        status: 'draft'
      }
      @posts << post
      post
    end
  end
end

# Define schema
schema = GraphQLite::Schema.new do
  # Enum for post status
  enum :PostStatus, values: {
    'DRAFT' => { value: 'draft', description: 'Draft post' },
    'PUBLISHED' => { value: 'published', description: 'Published post' },
    'ARCHIVED' => { value: 'archived', description: 'Archived post' }
  }

  # Author type
  object :Author do
    field :id, :ID, null: false
    field :name, :String
    field :email, :String

    field :posts, [:Post] do |author|
      DB.posts_by_author(author[:id])
    end
  end

  # Post type
  object :Post do
    field :id, :ID, null: false
    field :title, :String
    field :content, :String
    field :status, :PostStatus

    field :author, :Author do |post|
      DB.find_author(post[:author_id])
    end
  end

  # Queries
  query do
    field :post, :Post do |f|
      f.argument :id, :ID
      f.resolve do |args|
        DB.find_post(args[:id])
      end
    end

    field :posts, [:Post] do |f|
      f.argument :status, :PostStatus
      f.resolve do |args|
        if args[:status]
          DB.posts_by_status(args[:status])
        else
          DB.posts
        end
      end
    end

    field :author, :Author do |f|
      f.argument :id, :ID
      f.resolve do |args|
        DB.find_author(args[:id])
      end
    end
  end

  # Mutations
  mutation do
    field :createPost, :Post do |f|
      f.argument :title, :String
      f.argument :content, :String
      f.argument :authorId, :ID
      f.resolve do |args|
        DB.create_post(
          title: args[:title],
          content: args[:content],
          author_id: args[:authorId]
        )
      end
    end
  end
end

# Example queries
puts "=== All Posts ==="
result = schema.execute('{ posts { id title author { name } } }')
puts JSON.pretty_generate(result)

puts "\n=== Published Posts ==="
result = schema.execute('{ posts(status: PUBLISHED) { title status } }')
puts JSON.pretty_generate(result)

puts "\n=== Single Post with Author ==="
result = schema.execute('{ post(id: "1") { title content author { name email } } }')
puts JSON.pretty_generate(result)

puts "\n=== Author with Posts ==="
result = schema.execute('{ author(id: "1") { name posts { title status } } }')
puts JSON.pretty_generate(result)

puts "\n=== Create New Post ==="
mutation = 'mutation { createPost(title: "New Post", content: "Amazing content", authorId: "1") { id title status } }'
result = schema.execute(mutation)
puts JSON.pretty_generate(result)

puts "\n=== Introspection ==="
result = schema.execute('{ __type(name: "Post") { name fields { name type { name kind } } } }')
puts JSON.pretty_generate(result)
