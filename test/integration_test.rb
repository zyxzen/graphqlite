require_relative 'test_helper'

class IntegrationTest < Minitest::Test
  def setup
    @schema = GraphQLite::Schema.new do
      # Define enum
      enum :Role, values: {
        'ADMIN' => { value: 'admin' },
        'USER' => { value: 'user' }
      }

      # Define types
      object :Post do
        field :id, :ID, null: false
        field :title, :String
        field :content, :String
      end

      object :User do
        field :id, :ID, null: false
        field :name, :String
        field :email, :String
        field :role, :Role
        field :posts, [:Post] do |f|
          f.resolve do |user|
            [
              { id: '1', title: 'First Post', content: 'Hello World' },
              { id: '2', title: 'Second Post', content: 'Goodbye World' }
            ]
          end
        end
      end

      # Define queries
      query do
        field :me, :User do
          {
            id: '1',
            name: 'John Doe',
            email: 'john@example.com',
            role: 'admin'
          }
        end

        field :user, :User do |f|
          f.argument :id, :ID
          f.resolve do |args|
            {
              id: args[:id],
              name: "User #{args[:id]}",
              email: "user#{args[:id]}@example.com",
              role: 'user'
            }
          end
        end

        field :users, [:User] do
          [
            { id: '1', name: 'Alice', email: 'alice@example.com', role: 'admin' },
            { id: '2', name: 'Bob', email: 'bob@example.com', role: 'user' }
          ]
        end
      end

      # Define mutations
      mutation do
        field :createUser, :User do |f|
          f.argument :name, :String
          f.argument :email, :String
          f.resolve do |args|
            {
              id: '999',
              name: args[:name],
              email: args[:email],
              role: 'user'
            }
          end
        end
      end
    end
  end

  def test_query_me
    result = @schema.execute('{ me { id name email role } }')

    assert result.key?('data')
    assert_equal '1', result['data']['me']['id']
    assert_equal 'John Doe', result['data']['me']['name']
    assert_equal 'john@example.com', result['data']['me']['email']
    assert_equal 'admin', result['data']['me']['role']
  end

  def test_query_with_nested_posts
    result = @schema.execute('{ me { name posts { id title } } }')

    assert result.key?('data')
    posts = result['data']['me']['posts']
    assert_equal 2, posts.length
    assert_equal 'First Post', posts[0]['title']
    assert_equal 'Second Post', posts[1]['title']
  end

  def test_query_with_argument
    result = @schema.execute('{ user(id: "42") { id name } }')

    assert_equal '42', result['data']['user']['id']
    assert_equal 'User 42', result['data']['user']['name']
  end

  def test_query_list
    result = @schema.execute('{ users { id name } }')

    users = result['data']['users']
    assert_equal 2, users.length
    assert_equal 'Alice', users[0]['name']
    assert_equal 'Bob', users[1]['name']
  end

  def test_mutation
    mutation = 'mutation { createUser(name: "Charlie", email: "charlie@example.com") { id name email } }'
    result = @schema.execute(mutation)

    assert result.key?('data')
    user = result['data']['createUser']
    assert_equal '999', user['id']
    assert_equal 'Charlie', user['name']
    assert_equal 'charlie@example.com', user['email']
  end

  def test_query_with_variables
    query = 'query GetUser($userId: ID!) { user(id: $userId) { id name } }'
    result = @schema.execute(query, variables: { 'userId' => '123' })

    assert_equal '123', result['data']['user']['id']
  end

  def test_query_with_alias
    result = @schema.execute('{ currentUser: me { id name } }')

    assert result['data'].key?('currentUser')
    assert_equal 'John Doe', result['data']['currentUser']['name']
  end

  def test_introspection_typename
    result = @schema.execute('{ me { __typename id } }')

    assert_equal 'User', result['data']['me']['__typename']
  end
end
