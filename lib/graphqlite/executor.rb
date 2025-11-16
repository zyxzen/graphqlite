module GraphQLite
  # Executor executes GraphQL operations against a schema
  class Executor
    attr_reader :schema

    def initialize(schema)
      @schema = schema
    end

    def execute(document, variables: {}, operation_name: nil, context: {})
      # Find the operation to execute
      operation = find_operation(document, operation_name)
      raise ExecutionError, "No operation found" unless operation

      # Get the root type based on operation type
      root_type = case operation.operation_type
      when 'query'
        @schema.query_type
      when 'mutation'
        @schema.mutation_type
      when 'subscription'
        @schema.subscription_type
      end

      raise ExecutionError, "Schema does not support #{operation.operation_type}" unless root_type

      # Coerce variable values
      variable_values = coerce_variable_values(operation.variable_definitions, variables)

      # Execute the operation
      data = execute_selection_set(
        operation.selection_set,
        root_type,
        nil, # root value
        variable_values,
        context
      )

      { 'data' => data }
    rescue ExecutionError => e
      { 'data' => nil, 'errors' => [{ 'message' => e.message }] }
    end

    private

    def find_operation(document, operation_name)
      operations = document.definitions.select { |d| d.is_a?(Parser::OperationDefinition) }

      if operation_name
        operations.find { |op| op.name == operation_name }
      elsif operations.length == 1
        operations.first
      else
        raise ExecutionError, "Must provide operation name if query contains multiple operations"
      end
    end

    def coerce_variable_values(variable_definitions, variables)
      return {} if variable_definitions.empty?

      variable_values = {}

      variable_definitions.each do |var_def|
        var_name = var_def.variable.name
        var_type = resolve_type_ref(var_def.type)
        default_value = var_def.default_value

        if variables.key?(var_name) || variables.key?(var_name.to_sym)
          value = variables[var_name] || variables[var_name.to_sym]
          variable_values[var_name] = coerce_input_value(value, var_type)
        elsif default_value
          variable_values[var_name] = coerce_literal_value(default_value, var_type)
        elsif var_type.is_a?(Types::NonNullType)
          raise ExecutionError, "Variable $#{var_name} is required but not provided"
        end
      end

      variable_values
    end

    def execute_selection_set(selection_set, object_type, object_value, variable_values, context)
      return nil unless selection_set

      # Collect fields
      fields = collect_fields(selection_set, object_type, variable_values)

      # Execute fields
      result = {}

      fields.each do |response_key, field_list|
        field_value = execute_field(object_type, object_value, field_list, variable_values, context)
        result[response_key] = field_value unless field_value == :skip
      end

      result
    end

    def collect_fields(selection_set, object_type, variable_values, visited_fragments = {})
      fields = Hash.new { |h, k| h[k] = [] }

      selection_set.selections.each do |selection|
        # Skip if directives say so
        next if skip_selection?(selection, variable_values)

        case selection
        when Parser::Field
          response_key = selection.alias || selection.name
          fields[response_key] << selection
        when Parser::FragmentSpread
          fragment_name = selection.name
          next if visited_fragments[fragment_name]
          visited_fragments[fragment_name] = true

          # Note: Fragment definitions would need to be passed through context
          # For now, we'll skip fragment spreads in this minimal implementation
        when Parser::InlineFragment
          # Check if type condition matches
          if !selection.type_condition || type_applies?(selection.type_condition, object_type)
            fragment_fields = collect_fields(selection.selection_set, object_type, variable_values, visited_fragments)
            fragment_fields.each do |key, field_list|
              fields[key].concat(field_list)
            end
          end
        end
      end

      fields
    end

    def skip_selection?(selection, variable_values)
      return false unless selection.respond_to?(:directives)

      selection.directives.each do |directive|
        case directive.name
        when 'skip'
          if_arg = directive.arguments.find { |arg| arg.name == 'if' }
          return true if if_arg && evaluate_argument(if_arg, variable_values)
        when 'include'
          if_arg = directive.arguments.find { |arg| arg.name == 'if' }
          return true if if_arg && !evaluate_argument(if_arg, variable_values)
        end
      end

      false
    end

    def type_applies?(type_condition, object_type)
      # For now, simple name matching
      # TODO: Handle interfaces and unions properly
      type_condition.name == object_type.name
    end

    def execute_field(object_type, object_value, field_list, variable_values, context)
      field_ast = field_list.first
      field_name = field_ast.name

      # Handle introspection fields
      case field_name
      when '__typename'
        return object_type.name
      when '__schema'
        return @schema if object_type == @schema.query_type
      when '__type'
        type_name_arg = field_ast.arguments.find { |arg| arg.name == 'name' }
        type_name = evaluate_argument(type_name_arg, variable_values) if type_name_arg
        return @schema.get_type(type_name) if object_type == @schema.query_type
      end

      # Get field definition
      field_def = object_type.fields[field_name]
      return nil unless field_def

      # Coerce arguments
      args = coerce_arguments(field_ast.arguments, field_def, variable_values)

      # Resolve field value
      resolved_value = resolve_field_value(field_def, object_value, args, context)

      # Complete value
      complete_value(field_def.type, resolved_value, field_ast.selection_set, variable_values, context)
    end

    def coerce_arguments(argument_asts, field_def, variable_values)
      return {} if argument_asts.empty?

      args = {}

      argument_asts.each do |arg_ast|
        arg_def = field_def.arguments[arg_ast.name]
        next unless arg_def

        value = evaluate_argument(arg_ast, variable_values)
        args[arg_ast.name] = value
        args[arg_ast.name.to_sym] = value # Allow both string and symbol access
      end

      args
    end

    def evaluate_argument(argument, variable_values)
      evaluate_value(argument.value, variable_values)
    end

    def evaluate_value(value, variable_values)
      case value
      when Parser::Variable
        variable_values[value.name]
      when Parser::IntValue
        value.value
      when Parser::FloatValue
        value.value
      when Parser::StringValue
        value.value
      when Parser::BooleanValue
        value.value
      when Parser::NullValue
        nil
      when Parser::EnumValue
        value.value
      when Parser::ListValue
        value.values.map { |v| evaluate_value(v, variable_values) }
      when Parser::ObjectValue
        obj = {}
        value.fields.each do |field|
          obj[field.name] = evaluate_value(field.value, variable_values)
          obj[field.name.to_sym] = obj[field.name]
        end
        obj
      else
        value
      end
    end

    def resolve_field_value(field_def, object_value, args, context)
      if field_def.resolve
        # Custom resolver
        if field_def.resolve.arity == 0
          field_def.resolve.call
        elsif field_def.resolve.arity == 1
          field_def.resolve.call(args)
        else
          field_def.resolve.call(object_value, args, context)
        end
      elsif object_value.is_a?(Hash)
        # Hash object
        object_value[field_def.name] || object_value[field_def.name.to_sym]
      elsif object_value.respond_to?(field_def.name)
        # Method call
        object_value.public_send(field_def.name)
      else
        nil
      end
    end

    def complete_value(field_type, result, selection_set, variable_values, context)
      # Resolve lazy type references
      field_type = field_type.resolve if field_type.is_a?(Schema::TypeReference)

      # Handle non-null types
      if field_type.is_a?(Types::NonNullType)
        completed = complete_value(field_type.of_type, result, selection_set, variable_values, context)
        raise ExecutionError, "Cannot return null for non-null field" if completed.nil?
        return completed
      end

      # Handle null values
      return nil if result.nil?

      # Handle list types
      if field_type.is_a?(Types::ListType)
        raise ExecutionError, "Expected list but got #{result.class}" unless result.is_a?(Array)
        return result.map { |item| complete_value(field_type.of_type, item, selection_set, variable_values, context) }
      end

      # Handle scalar types
      if field_type.is_a?(Types::ScalarType)
        return field_type.serialize.call(result)
      end

      # Handle enum types
      if field_type.is_a?(Types::EnumType)
        return result.to_s
      end

      # Handle object types
      if field_type.is_a?(Types::ObjectType)
        return execute_selection_set(selection_set, field_type, result, variable_values, context)
      end

      # Handle interface and union types
      if field_type.is_a?(Types::InterfaceType) || field_type.is_a?(Types::UnionType)
        runtime_type = resolve_runtime_type(field_type, result)
        return execute_selection_set(selection_set, runtime_type, result, variable_values, context)
      end

      result
    end

    def resolve_runtime_type(abstract_type, object_value)
      if abstract_type.resolve_type
        type_name = abstract_type.resolve_type.call(object_value)
        @schema.get_type(type_name)
      else
        # Try to infer from object class name
        class_name = object_value.class.name.split('::').last
        @schema.get_type(class_name)
      end
    end

    def resolve_type_ref(type_ref)
      case type_ref
      when Parser::NamedType
        @schema.get_type(type_ref.name)
      when Parser::ListType
        Types::ListType.new(resolve_type_ref(type_ref.type))
      when Parser::NonNullType
        Types::NonNullType.new(resolve_type_ref(type_ref.type))
      when Schema::TypeReference
        type_ref.resolve
      else
        type_ref
      end
    end

    def coerce_input_value(value, type)
      if type.is_a?(Types::NonNullType)
        raise ExecutionError, "Expected non-null value" if value.nil?
        return coerce_input_value(value, type.of_type)
      end

      return nil if value.nil?

      if type.is_a?(Types::ListType)
        return [coerce_input_value(value, type.of_type)] unless value.is_a?(Array)
        return value.map { |v| coerce_input_value(v, type.of_type) }
      end

      if type.is_a?(Types::ScalarType)
        return type.parse_value.call(value)
      end

      if type.is_a?(Types::EnumType)
        return value.to_s
      end

      if type.is_a?(Types::InputObjectType)
        return {} unless value.is_a?(Hash)
        result = {}
        type.fields.each do |field_name, field_def|
          field_value = value[field_name] || value[field_name.to_sym]
          result[field_name] = coerce_input_value(field_value, field_def.type)
        end
        return result
      end

      value
    end

    def coerce_literal_value(value, type)
      # Similar to coerce_input_value but for AST values
      if type.is_a?(Types::NonNullType)
        raise ExecutionError, "Expected non-null value" if value.is_a?(Parser::NullValue)
        return coerce_literal_value(value, type.of_type)
      end

      return nil if value.is_a?(Parser::NullValue)

      if type.is_a?(Types::ListType)
        return [coerce_literal_value(value, type.of_type)] unless value.is_a?(Parser::ListValue)
        return value.values.map { |v| coerce_literal_value(v, type.of_type) }
      end

      if type.is_a?(Types::ScalarType)
        return type.parse_literal.call(value)
      end

      evaluate_value(value, {})
    end
  end
end
