module GraphQLite
  module Types
    # Base class for all types
    class BaseType
      attr_reader :name, :description

      def initialize(name, description: nil)
        @name = name
        @description = description
      end

      def to_s
        name
      end

      def non_null?
        false
      end

      def list?
        false
      end
    end

    # Scalar types
    class ScalarType < BaseType
      attr_reader :serialize, :parse_value, :parse_literal

      def initialize(name, description: nil, serialize: nil, parse_value: nil, parse_literal: nil)
        super(name, description: description)
        @serialize = serialize || ->(value) { value }
        @parse_value = parse_value || ->(value) { value }
        @parse_literal = parse_literal || ->(value) { value }
      end

      def kind
        'SCALAR'
      end
    end

    # Object types
    class ObjectType < BaseType
      attr_reader :fields, :interfaces

      def initialize(name, description: nil, interfaces: [])
        super(name, description: description)
        @fields = {}
        @interfaces = interfaces
      end

      def field(name, type = nil, description: nil, deprecation_reason: nil, &block)
        @fields[name.to_s] = Field.new(
          name: name.to_s,
          type: type,
          description: description,
          deprecation_reason: deprecation_reason,
          resolve: block
        )
      end

      def kind
        'OBJECT'
      end
    end

    # Interface types
    class InterfaceType < BaseType
      attr_reader :fields, :resolve_type

      def initialize(name, description: nil, resolve_type: nil)
        super(name, description: description)
        @fields = {}
        @resolve_type = resolve_type
      end

      def field(name, type, description: nil, deprecation_reason: nil)
        @fields[name.to_s] = Field.new(
          name: name.to_s,
          type: type,
          description: description,
          deprecation_reason: deprecation_reason
        )
      end

      def kind
        'INTERFACE'
      end
    end

    # Union types
    class UnionType < BaseType
      attr_reader :types, :resolve_type

      def initialize(name, types: [], description: nil, resolve_type: nil)
        super(name, description: description)
        @types = types
        @resolve_type = resolve_type
      end

      def kind
        'UNION'
      end
    end

    # Enum types
    class EnumType < BaseType
      attr_reader :values

      def initialize(name, values: {}, description: nil)
        super(name, description: description)
        @values = values.transform_values do |value|
          value.is_a?(Hash) ? EnumValue.new(**value) : EnumValue.new(value: value)
        end
      end

      def kind
        'ENUM'
      end
    end

    EnumValue = Struct.new(:value, :description, :deprecation_reason, keyword_init: true)

    # Input object types
    class InputObjectType < BaseType
      attr_reader :fields

      def initialize(name, description: nil)
        super(name, description: description)
        @fields = {}
      end

      def field(name, type, description: nil, default_value: nil)
        @fields[name.to_s] = InputField.new(
          name: name.to_s,
          type: type,
          description: description,
          default_value: default_value
        )
      end

      def kind
        'INPUT_OBJECT'
      end
    end

    # List type wrapper
    class ListType
      attr_reader :of_type

      def initialize(of_type)
        @of_type = of_type
      end

      def to_s
        "[#{@of_type}]"
      end

      def list?
        true
      end

      def non_null?
        false
      end

      def kind
        'LIST'
      end

      # Resolve lazy type references
      def resolve_types
        @of_type = @of_type.resolve if @of_type.respond_to?(:resolve)
        self
      end
    end

    # Non-null type wrapper
    class NonNullType
      attr_reader :of_type

      def initialize(of_type)
        # Allow TypeReference as of_type, will be resolved later
        raise TypeError, "Cannot wrap NonNullType in NonNullType" if of_type.is_a?(NonNullType)
        @of_type = of_type
      end

      def to_s
        "#{@of_type}!"
      end

      def non_null?
        true
      end

      def list?
        false
      end

      def kind
        'NON_NULL'
      end

      # Resolve lazy type references
      def resolve_types
        @of_type = @of_type.resolve if @of_type.respond_to?(:resolve)
        self
      end
    end

    # Field definition
    class Field
      attr_reader :name, :type, :description, :deprecation_reason, :arguments, :resolve

      def initialize(name:, type:, description: nil, deprecation_reason: nil, resolve: nil)
        @name = name
        @type = type
        @description = description
        @deprecation_reason = deprecation_reason
        @arguments = {}
        @resolve = resolve
      end

      def argument(name, type, description: nil, default_value: nil)
        @arguments[name.to_s] = Argument.new(
          name: name.to_s,
          type: type,
          description: description,
          default_value: default_value
        )
      end

      def deprecated?
        !@deprecation_reason.nil?
      end
    end

    # Argument definition
    class Argument
      attr_reader :name, :type, :description, :default_value

      def initialize(name:, type:, description: nil, default_value: nil)
        @name = name
        @type = type
        @description = description
        @default_value = default_value
      end
    end

    # Input field definition
    class InputField
      attr_reader :name, :type, :description, :default_value

      def initialize(name:, type:, description: nil, default_value: nil)
        @name = name
        @type = type
        @description = description
        @default_value = default_value
      end
    end

    # Built-in scalar types
    INT = ScalarType.new(
      'Int',
      description: 'The `Int` scalar type represents non-fractional signed whole numeric values.',
      serialize: ->(value) { value.to_i },
      parse_value: ->(value) { value.to_i },
      parse_literal: ->(value) { value.is_a?(Parser::IntValue) ? value.value.to_i : nil }
    )

    FLOAT = ScalarType.new(
      'Float',
      description: 'The `Float` scalar type represents signed double-precision fractional values.',
      serialize: ->(value) { value.to_f },
      parse_value: ->(value) { value.to_f },
      parse_literal: ->(value) {
        case value
        when Parser::FloatValue
          value.value.to_f
        when Parser::IntValue
          value.value.to_f
        end
      }
    )

    STRING = ScalarType.new(
      'String',
      description: 'The `String` scalar type represents textual data.',
      serialize: ->(value) { value.to_s },
      parse_value: ->(value) { value.to_s },
      parse_literal: ->(value) { value.is_a?(Parser::StringValue) ? value.value : nil }
    )

    BOOLEAN = ScalarType.new(
      'Boolean',
      description: 'The `Boolean` scalar type represents `true` or `false`.',
      serialize: ->(value) { !!value },
      parse_value: ->(value) { !!value },
      parse_literal: ->(value) { value.is_a?(Parser::BooleanValue) ? value.value : nil }
    )

    ID = ScalarType.new(
      'ID',
      description: 'The `ID` scalar type represents a unique identifier.',
      serialize: ->(value) { value.to_s },
      parse_value: ->(value) { value.to_s },
      parse_literal: ->(value) {
        case value
        when Parser::StringValue, Parser::IntValue
          value.value.to_s
        end
      }
    )

    # Helper methods to create type wrappers
    def self.list(type)
      ListType.new(type)
    end

    def self.non_null(type)
      NonNullType.new(type)
    end

    # Convenience method for non-null types
    class BaseType
      def !
        NonNullType.new(self)
      end
    end

    class ListType
      def !
        NonNullType.new(self)
      end
    end
  end
end
