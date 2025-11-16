module GraphQLite
  class Error < StandardError; end
  class ParseError < Error; end
  class ValidationError < Error; end
  class ExecutionError < Error; end
  class TypeError < Error; end
end
