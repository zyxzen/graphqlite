module GraphQLite
  # Schema is the main entry point for defining GraphQL schemas
  class Schema
    attr_reader :query_type, :mutation_type, :subscription_type, :types, :directives

    def initialize(&block)
      @types = {}
      @directives = {}
      @query_type = nil
      @mutation_type = nil
      @subscription_type = nil
      @type_resolver = TypeResolver.new(self)

      # Register built-in scalars
      register_type(Types::INT)
      register_type(Types::FLOAT)
      register_type(Types::STRING)
      register_type(Types::BOOLEAN)
      register_type(Types::ID)

      # Build schema using DSL
      instance_eval(&block) if block_given?

      # Add introspection types
      Introspection.add_introspection_types(self)
    end

    def query(&block)
      @query_type = define_root_type('Query', &block)
    end

    def mutation(&block)
      @mutation_type = define_root_type('Mutation', &block)
    end

    def subscription(&block)
      @subscription_type = define_root_type('Subscription', &block)
    end

    def object(name, description: nil, interfaces: [], &block)
      type = Types::ObjectType.new(name.to_s, description: description, interfaces: interfaces)
      register_type(type)

      builder = TypeBuilder.new(type, self)
      builder.instance_eval(&block) if block_given?

      type
    end

    def interface(name, description: nil, resolve_type: nil, &block)
      type = Types::InterfaceType.new(name.to_s, description: description, resolve_type: resolve_type)
      register_type(type)

      builder = TypeBuilder.new(type, self)
      builder.instance_eval(&block) if block_given?

      type
    end

    def union(name, types: [], description: nil, resolve_type: nil)
      type = Types::UnionType.new(name.to_s, types: types, description: description, resolve_type: resolve_type)
      register_type(type)
      type
    end

    def enum(name, values: {}, description: nil)
      type = Types::EnumType.new(name.to_s, values: values, description: description)
      register_type(type)
      type
    end

    def input_object(name, description: nil, &block)
      type = Types::InputObjectType.new(name.to_s, description: description)
      register_type(type)

      builder = TypeBuilder.new(type, self)
      builder.instance_eval(&block) if block_given?

      type
    end

    def scalar(name, description: nil, serialize: nil, parse_value: nil, parse_literal: nil)
      type = Types::ScalarType.new(
        name.to_s,
        description: description,
        serialize: serialize,
        parse_value: parse_value,
        parse_literal: parse_literal
      )
      register_type(type)
      type
    end

    def execute(query_string, variables: {}, operation_name: nil, context: {})
      # Parse the query
      document = Parser.new(query_string).parse

      # Validate the query
      validator = Validator.new(self)
      errors = validator.validate(document)
      return { 'errors' => errors.map { |e| { 'message' => e.message } } } unless errors.empty?

      # Execute the query
      executor = Executor.new(self)
      executor.execute(document, variables: variables, operation_name: operation_name, context: context)
    rescue ParseError, ValidationError, ExecutionError => e
      { 'errors' => [{ 'message' => e.message }] }
    end

    def get_type(name)
      return nil if name.nil?
      @types[name.to_s]
    end

    def register_type(type)
      @types[type.name] = type
    end

    private

    def define_root_type(name, &block)
      type = Types::ObjectType.new(name)
      register_type(type)

      builder = TypeBuilder.new(type, self)
      builder.instance_eval(&block) if block_given?

      type
    end

    # Helper class for building types using DSL
    class TypeBuilder
      def initialize(type, schema)
        @type = type
        @schema = schema
        @resolver = TypeResolver.new(schema)
      end

      def field(name, type = nil, description: nil, null: true, deprecation_reason: nil, &block)
        # Resolve type reference
        resolved_type = @resolver.resolve(type)
        resolved_type = Types::NonNullType.new(resolved_type) unless null

        if @type.is_a?(Types::ObjectType)
          # Check if block expects a parameter (builder pattern) or not (resolver pattern)
          if block && block.arity > 0
            # Builder pattern: pass FieldBuilder to block
            field_def = @type.field(name, resolved_type, description: description, deprecation_reason: deprecation_reason)
            field_builder = FieldBuilder.new(field_def, @schema)
            block.call(field_builder)
            field_builder
          else
            # Resolver pattern: block is the resolver
            field_def = @type.field(name, resolved_type, description: description, deprecation_reason: deprecation_reason, &block)
            FieldBuilder.new(field_def, @schema)
          end
        elsif @type.is_a?(Types::InterfaceType)
          @type.field(name, resolved_type, description: description, deprecation_reason: deprecation_reason)
        elsif @type.is_a?(Types::InputObjectType)
          default_value = null ? nil : block&.call
          @type.field(name, resolved_type, description: description, default_value: default_value)
        end
      end
    end

    # Helper class for building fields with arguments
    class FieldBuilder
      attr_reader :field

      def initialize(field, schema)
        @field = field
        @schema = schema
        @resolver = TypeResolver.new(schema)
      end

      def argument(name, type, description: nil, default_value: nil)
        resolved_type = @resolver.resolve(type)
        @field.argument(name, resolved_type, description: description, default_value: default_value)
        self
      end

      alias arg argument

      def resolve(&block)
        @field.instance_variable_set(:@resolve, block)
        self
      end
    end

    # Lazy type reference for forward references
    class TypeReference
      attr_reader :name, :schema

      def initialize(name, schema)
        @name = name
        @schema = schema
      end

      def resolve
        type = @schema.get_type(@name.to_s)
        raise TypeError, "Unknown type: #{@name}" unless type
        type
      end
    end

    # Type resolver handles type references (symbols, strings, types)
    class TypeResolver
      def initialize(schema)
        @schema = schema
      end

      def resolve(type_ref)
        case type_ref
        when Types::BaseType, Types::ListType, Types::NonNullType
          type_ref
        when String, Symbol
          # Look up type by name - if it doesn't exist yet, return a lazy reference
          type = @schema.get_type(type_ref.to_s)
          return type if type
          # Return lazy reference for forward references (mainly for introspection)
          TypeReference.new(type_ref, @schema)
        when Array
          # Array notation for lists: [String] -> ListType
          raise TypeError, "Array type must have exactly one element" unless type_ref.length == 1
          Types::ListType.new(resolve(type_ref[0]))
        when Class
          # Ruby class reference - auto-convert to type name
          type_name = type_ref.name.split('::').last
          type = @schema.get_type(type_name)
          return type if type
          TypeReference.new(type_name, @schema)
        else
          raise TypeError, "Invalid type reference: #{type_ref.inspect}"
        end
      end
    end
  end
end
