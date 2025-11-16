module GraphQLite
  # Validator validates GraphQL documents against the schema
  class Validator
    attr_reader :schema, :errors

    def initialize(schema)
      @schema = schema
      @errors = []
    end

    def validate(document)
      @errors = []

      document.definitions.each do |definition|
        case definition
        when Parser::OperationDefinition
          validate_operation(definition)
        when Parser::FragmentDefinition
          validate_fragment(definition)
        end
      end

      @errors
    end

    private

    def validate_operation(operation)
      # Get root type
      root_type = case operation.operation_type
      when 'query'
        @schema.query_type
      when 'mutation'
        @schema.mutation_type
      when 'subscription'
        @schema.subscription_type
      end

      unless root_type
        @errors << ValidationError.new("Schema does not support #{operation.operation_type}")
        return
      end

      # Validate variable definitions
      validate_variable_definitions(operation.variable_definitions)

      # Validate selection set
      validate_selection_set(operation.selection_set, root_type)
    end

    def validate_fragment(fragment)
      # Validate type condition exists
      type = @schema.get_type(fragment.type_condition.name)
      unless type
        @errors << ValidationError.new("Unknown type: #{fragment.type_condition.name}")
        return
      end

      # Validate selection set
      validate_selection_set(fragment.selection_set, type)
    end

    def validate_variable_definitions(variable_definitions)
      return if variable_definitions.empty?

      variable_definitions.each do |var_def|
        # Validate variable type exists
        type = resolve_type_ref(var_def.type)
        unless type
          @errors << ValidationError.new("Unknown type for variable $#{var_def.variable.name}")
        end
      end
    end

    def validate_selection_set(selection_set, parent_type)
      return unless selection_set

      selection_set.selections.each do |selection|
        case selection
        when Parser::Field
          validate_field(selection, parent_type)
        when Parser::FragmentSpread
          # Fragment validation would require storing fragments
          # Skip for minimal implementation
        when Parser::InlineFragment
          if selection.type_condition
            type = @schema.get_type(selection.type_condition.name)
            unless type
              @errors << ValidationError.new("Unknown type: #{selection.type_condition.name}")
              next
            end
            validate_selection_set(selection.selection_set, type)
          else
            validate_selection_set(selection.selection_set, parent_type)
          end
        end
      end
    end

    def validate_field(field, parent_type)
      field_name = field.name

      # Introspection fields are always valid
      return if %w[__typename __schema __type].include?(field_name)

      # Check if field exists on parent type
      unless parent_type.respond_to?(:fields) && parent_type.fields[field_name]
        @errors << ValidationError.new("Field '#{field_name}' does not exist on type '#{parent_type.name}'")
        return
      end

      field_def = parent_type.fields[field_name]

      # Validate arguments
      validate_arguments(field.arguments, field_def)

      # Validate nested selection set
      if field.selection_set
        field_type = unwrap_type(field_def.type)

        unless field_type.respond_to?(:fields)
          @errors << ValidationError.new("Field '#{field_name}' is a scalar and cannot have a selection set")
          return
        end

        validate_selection_set(field.selection_set, field_type)
      elsif requires_selection_set?(field_def.type)
        @errors << ValidationError.new("Field '#{field_name}' requires a selection set")
      end
    end

    def validate_arguments(arguments, field_def)
      return if arguments.empty?

      arguments.each do |arg|
        arg_def = field_def.arguments[arg.name]
        unless arg_def
          @errors << ValidationError.new("Unknown argument '#{arg.name}' on field '#{field_def.name}'")
        end
      end

      # Check for required arguments
      field_def.arguments.each do |arg_name, arg_def|
        if arg_def.type.is_a?(Types::NonNullType)
          unless arguments.any? { |arg| arg.name == arg_name }
            @errors << ValidationError.new("Required argument '#{arg_name}' missing on field '#{field_def.name}'")
          end
        end
      end
    end

    def unwrap_type(type)
      case type
      when Types::NonNullType, Types::ListType
        unwrap_type(type.of_type)
      else
        type
      end
    end

    def requires_selection_set?(type)
      unwrapped = unwrap_type(type)
      unwrapped.is_a?(Types::ObjectType) ||
        unwrapped.is_a?(Types::InterfaceType) ||
        unwrapped.is_a?(Types::UnionType)
    end

    def resolve_type_ref(type_ref)
      case type_ref
      when Parser::NamedType
        @schema.get_type(type_ref.name)
      when Parser::ListType
        inner = resolve_type_ref(type_ref.type)
        inner ? Types::ListType.new(inner) : nil
      when Parser::NonNullType
        inner = resolve_type_ref(type_ref.type)
        inner ? Types::NonNullType.new(inner) : nil
      else
        type_ref
      end
    end
  end
end
