require_relative 'test_helper'

class ExecutorTest < Minitest::Test
  def test_execute_simple_query
    schema = GraphQLite::Schema.new do
      query do
        field :hello, :String do
          "World"
        end
      end
    end

    result = schema.execute('{ hello }')

    assert result.key?('data')
    assert_equal 'World', result['data']['hello']
  end

  def test_execute_query_with_nested_fields
    schema = GraphQLite::Schema.new do
      object :User do
        field :id, :ID, null: false
        field :name, :String
      end

      query do
        field :user, :User do
          { id: '123', name: 'John Doe' }
        end
      end
    end

    result = schema.execute('{ user { id name } }')

    assert result.key?('data')
    assert_equal '123', result['data']['user']['id']
    assert_equal 'John Doe', result['data']['user']['name']
  end

  def test_execute_query_with_arguments
    schema = GraphQLite::Schema.new do
      query do
        field :greet, String do |f|
          f.argument :name, String
          f.resolve { |args| "Hello, #{args[:name]}!" }
        end
      end
    end

    result = schema.execute('{ greet(name: "Alice") }')

    assert_equal 'Hello, Alice!', result['data']['greet']
  end

  def test_execute_query_with_variables
    schema = GraphQLite::Schema.new do
      query do
        field :greet, String do |f|
          f.argument :name, String
          f.resolve { |args| "Hello, #{args[:name]}!" }
        end
      end
    end

    query = 'query Greet($name: String) { greet(name: $name) }'
    result = schema.execute(query, variables: { 'name' => 'Bob' })

    assert_equal 'Hello, Bob!', result['data']['greet']
  end

  def test_execute_query_with_list
    schema = GraphQLite::Schema.new do
      query do
        field :numbers, [:Int] do
          [1, 2, 3, 4, 5]
        end
      end
    end

    result = schema.execute('{ numbers }')

    assert_equal [1, 2, 3, 4, 5], result['data']['numbers']
  end

  def test_typename_introspection
    schema = GraphQLite::Schema.new do
      object :User do
        field :id, :ID, null: false
        field :name, :String
      end

      query do
        field :user, :User do
          { id: '1', name: 'Test' }
        end
      end
    end

    result = schema.execute('{ user { __typename id } }')

    assert_equal 'User', result['data']['user']['__typename']
  end

  def test_null_handling
    schema = GraphQLite::Schema.new do
      query do
        field :nullable, :String do
          nil
        end
      end
    end

    result = schema.execute('{ nullable }')

    assert_nil result['data']['nullable']
  end

  def test_error_on_missing_field
    schema = GraphQLite::Schema.new do
      query do
        field :hello, :String do
          "World"
        end
      end
    end

    result = schema.execute('{ goodbye }')

    assert result.key?('errors')
    assert result['errors'].length > 0
  end
end
