require_relative 'test_helper'

class LexerTest < Minitest::Test
  def test_tokenize_simple_query
    lexer = GraphQLite::Lexer.new('{ hello }')
    tokens = lexer.tokenize

    assert_equal :lbrace, tokens[0].type
    assert_equal :name, tokens[1].type
    assert_equal 'hello', tokens[1].value
    assert_equal :rbrace, tokens[2].type
    assert_equal :eof, tokens[3].type
  end

  def test_tokenize_string
    lexer = GraphQLite::Lexer.new('"Hello World"')
    tokens = lexer.tokenize

    assert_equal :string, tokens[0].type
    assert_equal 'Hello World', tokens[0].value
  end

  def test_tokenize_numbers
    lexer = GraphQLite::Lexer.new('42 3.14 -5 2.5e10')
    tokens = lexer.tokenize

    assert_equal :int, tokens[0].type
    assert_equal '42', tokens[0].value

    assert_equal :float, tokens[1].type
    assert_equal '3.14', tokens[1].value

    assert_equal :int, tokens[2].type
    assert_equal '-5', tokens[2].value

    assert_equal :float, tokens[3].type
    assert_equal '2.5e10', tokens[3].value
  end

  def test_tokenize_keywords
    lexer = GraphQLite::Lexer.new('query mutation subscription fragment on true false null')
    tokens = lexer.tokenize

    assert_equal :name, tokens[0].type
    assert_equal 'query', tokens[0].value

    assert_equal :boolean, tokens[5].type
    assert_equal 'true', tokens[5].value

    assert_equal :boolean, tokens[6].type
    assert_equal 'false', tokens[6].value

    assert_equal :null, tokens[7].type
    assert_equal 'null', tokens[7].value
  end

  def test_skip_comments
    lexer = GraphQLite::Lexer.new("# This is a comment\n{ hello }")
    tokens = lexer.tokenize

    assert_equal :lbrace, tokens[0].type
    assert_equal :name, tokens[1].type
  end

  def test_tokenize_spread
    lexer = GraphQLite::Lexer.new('...')
    tokens = lexer.tokenize

    assert_equal :spread, tokens[0].type
    assert_equal '...', tokens[0].value
  end
end
