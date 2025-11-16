module GraphQLite
  # Introspection adds schema introspection capabilities
  module Introspection
    class << self
      def add_introspection_types(schema)
        # Add __DirectiveLocation enum first
        directive_location_enum = schema.enum('__DirectiveLocation', values: {
          'QUERY' => { value: 'QUERY' },
          'MUTATION' => { value: 'MUTATION' },
          'SUBSCRIPTION' => { value: 'SUBSCRIPTION' },
          'FIELD' => { value: 'FIELD' },
          'FRAGMENT_DEFINITION' => { value: 'FRAGMENT_DEFINITION' },
          'FRAGMENT_SPREAD' => { value: 'FRAGMENT_SPREAD' },
          'INLINE_FRAGMENT' => { value: 'INLINE_FRAGMENT' },
          'SCHEMA' => { value: 'SCHEMA' },
          'SCALAR' => { value: 'SCALAR' },
          'OBJECT' => { value: 'OBJECT' },
          'FIELD_DEFINITION' => { value: 'FIELD_DEFINITION' },
          'ARGUMENT_DEFINITION' => { value: 'ARGUMENT_DEFINITION' },
          'INTERFACE' => { value: 'INTERFACE' },
          'UNION' => { value: 'UNION' },
          'ENUM' => { value: 'ENUM' },
          'ENUM_VALUE' => { value: 'ENUM_VALUE' },
          'INPUT_OBJECT' => { value: 'INPUT_OBJECT' },
          'INPUT_FIELD_DEFINITION' => { value: 'INPUT_FIELD_DEFINITION' }
        })

        # Add __TypeKind enum
        type_kind_enum = schema.enum('__TypeKind', values: {
          'SCALAR' => { value: 'SCALAR' },
          'OBJECT' => { value: 'OBJECT' },
          'INTERFACE' => { value: 'INTERFACE' },
          'UNION' => { value: 'UNION' },
          'ENUM' => { value: 'ENUM' },
          'INPUT_OBJECT' => { value: 'INPUT_OBJECT' },
          'LIST' => { value: 'LIST' },
          'NON_NULL' => { value: 'NON_NULL' }
        })

        # Add __InputValue type (needed by __Field and __Directive)
        input_value_type = schema.object('__InputValue', description: 'An input value (argument or input field)') do
          field :name, 'String', null: false do
            resolve { |value| value.name }
          end

          field :description, 'String' do
            resolve { |value| value.description }
          end

          field :type, '__Type', null: false do
            resolve { |value| value.type }
          end

          field :defaultValue, 'String' do
            resolve { |value| value.default_value&.to_s }
          end
        end

        # Add __EnumValue type
        enum_value_type = schema.object('__EnumValue', description: 'An enum value') do
          field :name, 'String', null: false do
            resolve { |value| value.value.to_s }
          end

          field :description, 'String' do
            resolve { |value| value.description }
          end

          field :isDeprecated, 'Boolean', null: false do
            resolve { |value| !value.deprecation_reason.nil? }
          end

          field :deprecationReason, 'String' do
            resolve { |value| value.deprecation_reason }
          end
        end

        # Add __Field type
        field_type = schema.object('__Field', description: 'A field in an object type') do
          field :name, 'String', null: false do
            resolve { |field| field.name }
          end

          field :description, 'String' do
            resolve { |field| field.description }
          end

          field :args, ['__InputValue'], null: false do
            resolve { |field| field.arguments.values }
          end

          field :type, '__Type', null: false do
            resolve { |field| field.type }
          end

          field :isDeprecated, 'Boolean', null: false do
            resolve { |field| field.deprecated? }
          end

          field :deprecationReason, 'String' do
            resolve { |field| field.deprecation_reason }
          end
        end

        # Add __Directive type (before __Schema since __Schema references it)
        directive_type = schema.object('__Directive', description: 'A directive') do
          field :name, 'String', null: false do
            resolve { |directive| directive.name }
          end

          field :description, 'String' do
            resolve { |directive| directive.description }
          end

          field :locations, ['__DirectiveLocation'], null: false do
            resolve { |directive| directive.locations }
          end

          field :args, ['__InputValue'], null: false do
            resolve { |directive| directive.arguments.values }
          end
        end

        # Add __Schema type
        schema_type = schema.object('__Schema', description: 'A GraphQL schema') do
          field :types, [schema.object('__Type')] do
            resolve { |args, ctx| schema.types.values }
          end

          field :queryType, '__Type' do
            resolve { schema.query_type }
          end

          field :mutationType, '__Type' do
            resolve { schema.mutation_type }
          end

          field :subscriptionType, '__Type' do
            resolve { schema.subscription_type }
          end

          field :directives, ['__Directive'] do
            resolve { schema.directives.values }
          end
        end

        # Add __Type type
        type_type = schema.object('__Type', description: 'A type in the GraphQL schema') do
          field :kind, '__TypeKind', null: false do
            resolve { |type| type.kind }
          end

          field :name, 'String' do
            resolve { |type| type.respond_to?(:name) ? type.name : nil }
          end

          field :description, 'String' do
            resolve { |type| type.respond_to?(:description) ? type.description : nil }
          end

          field :fields, ['__Field'] do
            argument :includeDeprecated, 'Boolean'
            resolve do |type, args|
              next nil unless type.respond_to?(:fields)
              fields = type.fields.values
              fields = fields.reject(&:deprecated?) unless args[:includeDeprecated]
              fields
            end
          end

          field :interfaces, ['__Type'] do
            resolve do |type|
              type.respond_to?(:interfaces) ? type.interfaces : nil
            end
          end

          field :possibleTypes, ['__Type'] do
            resolve do |type|
              type.respond_to?(:types) ? type.types : nil
            end
          end

          field :enumValues, ['__EnumValue'] do
            argument :includeDeprecated, 'Boolean'
            resolve do |type, args|
              next nil unless type.is_a?(Types::EnumType)
              values = type.values.values
              values = values.reject { |v| v.deprecation_reason } unless args[:includeDeprecated]
              values
            end
          end

          field :inputFields, ['__InputValue'] do
            resolve do |type|
              type.is_a?(Types::InputObjectType) ? type.fields.values : nil
            end
          end

          field :ofType, '__Type' do
            resolve do |type|
              type.respond_to?(:of_type) ? type.of_type : nil
            end
          end
        end

        # Add introspection fields to query type
        if schema.query_type
          schema.query_type.field('__schema', schema_type, description: 'Access the schema introspection system') do
            resolve { schema }
          end

          schema.query_type.field('__type', type_type, description: 'Query a type by name') do |field|
            field.argument('name', Types::STRING.!)
            field.resolve do |_, args|
              schema.get_type(args[:name] || args['name'])
            end
          end
        end
      end
    end
  end
end
