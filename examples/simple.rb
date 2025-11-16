#!/usr/bin/env ruby

require_relative '../lib/graphqlite'

# Simple GraphQL schema example
schema = GraphQLite::Schema.new do
  query do
    # Simple field
    field :hello, :String do
      "World"
    end

    # Field with argument
    field :greet, :String do |f|
      f.argument :name, :String
      f.resolve do |args|
        "Hello, #{args[:name] || 'stranger'}!"
      end
    end

    # Field returning a list
    field :numbers, [:Int] do
      [1, 2, 3, 4, 5]
    end
  end
end

# Execute queries
puts "Simple query:"
result = schema.execute('{ hello }')
puts result.inspect
# => {"data"=>{"hello"=>"World"}}

puts "\nQuery with argument:"
result = schema.execute('{ greet(name: "Alice") }')
puts result.inspect
# => {"data"=>{"greet"=>"Hello, Alice!"}}

puts "\nQuery with list:"
result = schema.execute('{ numbers }')
puts result.inspect
# => {"data"=>{"numbers"=>[1, 2, 3, 4, 5]}}

puts "\nQuery with variables:"
query = 'query Greet($name: String) { greet(name: $name) }'
result = schema.execute(query, variables: { 'name' => 'Bob' })
puts result.inspect
# => {"data"=>{"greet"=>"Hello, Bob!"}}
