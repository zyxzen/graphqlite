module GraphQLite
  # Parser builds an AST from tokens
  class Parser
    # AST Node types
    Document = Struct.new(:definitions)
    OperationDefinition = Struct.new(:operation_type, :name, :variable_definitions, :directives, :selection_set)
    FragmentDefinition = Struct.new(:name, :type_condition, :directives, :selection_set)
    VariableDefinition = Struct.new(:variable, :type, :default_value, :directives)
    SelectionSet = Struct.new(:selections)
    Field = Struct.new(:alias, :name, :arguments, :directives, :selection_set)
    FragmentSpread = Struct.new(:name, :directives)
    InlineFragment = Struct.new(:type_condition, :directives, :selection_set)
    Argument = Struct.new(:name, :value)
    Directive = Struct.new(:name, :arguments)
    Variable = Struct.new(:name)

    # Values
    IntValue = Struct.new(:value)
    FloatValue = Struct.new(:value)
    StringValue = Struct.new(:value)
    BooleanValue = Struct.new(:value)
    NullValue = Struct.new(:value)
    EnumValue = Struct.new(:value)
    ListValue = Struct.new(:values)
    ObjectValue = Struct.new(:fields)
    ObjectField = Struct.new(:name, :value)

    # Types
    NamedType = Struct.new(:name)
    ListType = Struct.new(:type)
    NonNullType = Struct.new(:type)

    attr_reader :tokens, :pos

    def initialize(source)
      @lexer = Lexer.new(source)
      @tokens = @lexer.tokenize
      @pos = 0
    end

    def parse
      definitions = []

      while current_token.type != :eof
        definitions << parse_definition
      end

      Document.new(definitions)
    end

    private

    def current_token
      @tokens[@pos]
    end

    def peek_token(offset = 1)
      @tokens[@pos + offset] || @tokens.last
    end

    def advance
      @pos += 1
    end

    def expect(type)
      token = current_token
      raise ParseError, "Expected #{type} but got #{token.type} at #{token.line}:#{token.column}" unless token.type == type
      advance
      token
    end

    def skip_token(type)
      advance if current_token.type == type
    end

    def parse_definition
      token = current_token

      case token.type
      when :name
        case token.value
        when 'query', 'mutation', 'subscription'
          parse_operation_definition
        when 'fragment'
          parse_fragment_definition
        else
          # Short-hand query (no operation keyword)
          parse_operation_definition
        end
      when :lbrace
        # Short-hand query
        parse_operation_definition
      else
        raise ParseError, "Unexpected token #{token.type} at #{token.line}:#{token.column}"
      end
    end

    def parse_operation_definition
      operation_type = 'query' # default
      name = nil
      variable_definitions = []
      directives = []

      if current_token.type == :name && %w[query mutation subscription].include?(current_token.value)
        operation_type = current_token.value
        advance

        # Operation name (optional)
        if current_token.type == :name
          name = current_token.value
          advance
        end

        # Variable definitions (optional)
        if current_token.type == :lparen
          variable_definitions = parse_variable_definitions
        end

        # Directives (optional)
        directives = parse_directives
      end

      # Selection set (required)
      selection_set = parse_selection_set

      OperationDefinition.new(operation_type, name, variable_definitions, directives, selection_set)
    end

    def parse_fragment_definition
      expect(:name) # 'fragment'
      name = expect(:name).value
      expect(:name) # 'on'
      type_condition = parse_named_type
      directives = parse_directives
      selection_set = parse_selection_set

      FragmentDefinition.new(name, type_condition, directives, selection_set)
    end

    def parse_variable_definitions
      expect(:lparen)
      definitions = []

      while current_token.type != :rparen
        definitions << parse_variable_definition
      end

      expect(:rparen)
      definitions
    end

    def parse_variable_definition
      expect(:dollar)
      variable_name = expect(:name).value
      expect(:colon)
      type = parse_type

      default_value = nil
      if current_token.type == :equals
        advance
        default_value = parse_value_literal
      end

      directives = parse_directives

      VariableDefinition.new(Variable.new(variable_name), type, default_value, directives)
    end

    def parse_type
      type = if current_token.type == :lbracket
        advance
        inner_type = parse_type
        expect(:rbracket)
        ListType.new(inner_type)
      else
        parse_named_type
      end

      if current_token.type == :bang
        advance
        type = NonNullType.new(type)
      end

      type
    end

    def parse_named_type
      name = expect(:name).value
      NamedType.new(name)
    end

    def parse_selection_set
      expect(:lbrace)
      selections = []

      while current_token.type != :rbrace
        selections << parse_selection
      end

      expect(:rbrace)
      SelectionSet.new(selections)
    end

    def parse_selection
      if current_token.type == :spread
        advance
        if current_token.type == :name && current_token.value != 'on'
          # Fragment spread
          name = expect(:name).value
          directives = parse_directives
          FragmentSpread.new(name, directives)
        else
          # Inline fragment
          type_condition = nil
          if current_token.type == :name && current_token.value == 'on'
            advance
            type_condition = parse_named_type
          end
          directives = parse_directives
          selection_set = parse_selection_set
          InlineFragment.new(type_condition, directives, selection_set)
        end
      else
        parse_field
      end
    end

    def parse_field
      # Alias or field name
      name_or_alias = expect(:name).value

      field_name = name_or_alias
      field_alias = nil

      if current_token.type == :colon
        advance
        field_alias = name_or_alias
        field_name = expect(:name).value
      end

      # Arguments
      arguments = current_token.type == :lparen ? parse_arguments : []

      # Directives
      directives = parse_directives

      # Selection set (optional)
      selection_set = current_token.type == :lbrace ? parse_selection_set : nil

      Field.new(field_alias, field_name, arguments, directives, selection_set)
    end

    def parse_arguments
      expect(:lparen)
      arguments = []

      while current_token.type != :rparen
        arguments << parse_argument
      end

      expect(:rparen)
      arguments
    end

    def parse_argument
      name = expect(:name).value
      expect(:colon)
      value = parse_value
      Argument.new(name, value)
    end

    def parse_directives
      directives = []

      while current_token.type == :at
        advance
        name = expect(:name).value
        arguments = current_token.type == :lparen ? parse_arguments : []
        directives << Directive.new(name, arguments)
      end

      directives
    end

    def parse_value
      case current_token.type
      when :dollar
        advance
        name = expect(:name).value
        Variable.new(name)
      else
        parse_value_literal
      end
    end

    def parse_value_literal
      token = current_token

      case token.type
      when :int
        advance
        IntValue.new(token.value.to_i)
      when :float
        advance
        FloatValue.new(token.value.to_f)
      when :string
        advance
        StringValue.new(token.value)
      when :boolean
        advance
        BooleanValue.new(token.value == 'true')
      when :null
        advance
        NullValue.new(nil)
      when :name
        advance
        EnumValue.new(token.value)
      when :lbracket
        parse_list_value
      when :lbrace
        parse_object_value
      else
        raise ParseError, "Unexpected token #{token.type} at #{token.line}:#{token.column}"
      end
    end

    def parse_list_value
      expect(:lbracket)
      values = []

      while current_token.type != :rbracket
        values << parse_value_literal
      end

      expect(:rbracket)
      ListValue.new(values)
    end

    def parse_object_value
      expect(:lbrace)
      fields = []

      while current_token.type != :rbrace
        name = expect(:name).value
        expect(:colon)
        value = parse_value_literal
        fields << ObjectField.new(name, value)
      end

      expect(:rbrace)
      ObjectValue.new(fields)
    end
  end
end
