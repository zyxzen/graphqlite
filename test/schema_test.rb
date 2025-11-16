require_relative 'test_helper'

class SchemaTest < Minitest::Test
  def test_simple_schema
    schema = GraphQLite::Schema.new do
      query do
        field :hello, String do
          resolve { "World" }
        end
      end
    end

    refute_nil schema.query_type
    assert_equal 'Query', schema.query_type.name
    assert schema.query_type.fields.key?('hello')
  end

  def test_schema_with_types
    schema = GraphQLite::Schema.new do
      object :User do
        field :id, :ID, null: false
        field :name, :String
        field :email, :String
      end

      query do
        field :user, :User do
          resolve { { id: '1', name: 'John', email: 'john@example.com' } }
        end
      end
    end

    user_type = schema.get_type('User')
    refute_nil user_type
    assert_equal 3, user_type.fields.length
  end

  def test_schema_with_arguments
    schema = GraphQLite::Schema.new do
      query do
        field :greet, String do |f|
          f.argument :name, String
          f.resolve { |args| "Hello, #{args[:name]}!" }
        end
      end
    end

    greet_field = schema.query_type.fields['greet']
    assert greet_field.arguments.key?('name')
  end

  def test_built_in_scalars
    schema = GraphQLite::Schema.new do
      query do
        field :test, String
      end
    end

    refute_nil schema.get_type('Int')
    refute_nil schema.get_type('Float')
    refute_nil schema.get_type('String')
    refute_nil schema.get_type('Boolean')
    refute_nil schema.get_type('ID')
  end

  def test_enum_type
    schema = GraphQLite::Schema.new do
      enum :Status, values: {
        'ACTIVE' => { value: 'active' },
        'INACTIVE' => { value: 'inactive' }
      }

      query do
        field :status, :Status do
          resolve { 'active' }
        end
      end
    end

    status_type = schema.get_type('Status')
    assert_instance_of GraphQLite::Types::EnumType, status_type
    assert_equal 2, status_type.values.length
  end
end
