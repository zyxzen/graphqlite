require_relative 'test_helper'

class ParserTest < Minitest::Test
  def test_parse_simple_query
    parser = GraphQLite::Parser.new('{ hello }')
    document = parser.parse

    assert_equal 1, document.definitions.length
    operation = document.definitions[0]
    assert_instance_of GraphQLite::Parser::OperationDefinition, operation
    assert_equal 'query', operation.operation_type
  end

  def test_parse_query_with_fields
    parser = GraphQLite::Parser.new('{ user { id name email } }')
    document = parser.parse

    operation = document.definitions[0]
    selections = operation.selection_set.selections

    assert_equal 1, selections.length
    user_field = selections[0]
    assert_equal 'user', user_field.name

    user_selections = user_field.selection_set.selections
    assert_equal 3, user_selections.length
    assert_equal 'id', user_selections[0].name
    assert_equal 'name', user_selections[1].name
    assert_equal 'email', user_selections[2].name
  end

  def test_parse_query_with_arguments
    parser = GraphQLite::Parser.new('{ user(id: 123) { name } }')
    document = parser.parse

    operation = document.definitions[0]
    user_field = operation.selection_set.selections[0]

    assert_equal 1, user_field.arguments.length
    arg = user_field.arguments[0]
    assert_equal 'id', arg.name
    assert_instance_of GraphQLite::Parser::IntValue, arg.value
    assert_equal 123, arg.value.value
  end

  def test_parse_query_with_variables
    parser = GraphQLite::Parser.new('query GetUser($id: ID!) { user(id: $id) { name } }')
    document = parser.parse

    operation = document.definitions[0]
    assert_equal 'GetUser', operation.name
    assert_equal 1, operation.variable_definitions.length

    var_def = operation.variable_definitions[0]
    assert_equal 'id', var_def.variable.name
    assert_instance_of GraphQLite::Parser::NonNullType, var_def.type
    assert_equal 'ID', var_def.type.type.name
  end

  def test_parse_mutation
    parser = GraphQLite::Parser.new('mutation CreateUser($name: String!) { createUser(name: $name) { id } }')
    document = parser.parse

    operation = document.definitions[0]
    assert_equal 'mutation', operation.operation_type
  end

  def test_parse_field_alias
    parser = GraphQLite::Parser.new('{ username: name }')
    document = parser.parse

    field = document.definitions[0].selection_set.selections[0]
    assert_equal 'username', field.alias
    assert_equal 'name', field.name
  end
end
