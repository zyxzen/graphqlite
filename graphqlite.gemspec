Gem::Specification.new do |spec|
  spec.name          = "graphqlite"
  spec.version       = "1.0.0"
  spec.authors       = ["GraphQLite Contributors"]
  spec.email         = ["graphqlite@example.com"]

  spec.summary       = "A lightweight, production-ready GraphQL implementation for Ruby"
  spec.description   = "GraphQLite is a simple, minimal, and clean GraphQL implementation with zero dependencies. It's designed to be easier to use and faster than existing solutions while maintaining full GraphQL spec compliance."
  spec.homepage      = "https://github.com/yourusername/graphqlite"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/yourusername/graphqlite"
  spec.metadata["changelog_uri"] = "https://github.com/yourusername/graphqlite/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "README.md", "LICENSE", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  # Zero runtime dependencies - pure Ruby only!

  # Development dependencies
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
