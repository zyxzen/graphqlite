require_relative "graphqlite/version"
require_relative "graphqlite/lexer"
require_relative "graphqlite/parser"
require_relative "graphqlite/types"
require_relative "graphqlite/schema"
require_relative "graphqlite/executor"
require_relative "graphqlite/validator"
require_relative "graphqlite/introspection"
require_relative "graphqlite/errors"

module GraphQLite
  class << self
    # Create a new schema
    def schema(&block)
      Schema.new(&block)
    end
  end
end
