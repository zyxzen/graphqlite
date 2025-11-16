module GraphQLite
  # Lexer tokenizes GraphQL documents according to the spec
  class Lexer
    TOKEN_TYPES = %i[
      name int float string boolean null
      lparen rparen lbracket rbracket lbrace rbrace
      colon pipe equals bang dollar at spread
      eof
    ].freeze

    Token = Struct.new(:type, :value, :line, :column)

    attr_reader :source, :pos, :line, :column

    def initialize(source)
      @source = source
      @pos = 0
      @line = 1
      @column = 1
    end

    def tokenize
      tokens = []
      loop do
        token = next_token
        tokens << token
        break if token.type == :eof
      end
      tokens
    end

    def next_token
      skip_ignored
      return Token.new(:eof, nil, @line, @column) if @pos >= @source.length

      char = current_char
      start_line = @line
      start_column = @column

      token = case char
      when '{'
        advance
        Token.new(:lbrace, '{', start_line, start_column)
      when '}'
        advance
        Token.new(:rbrace, '}', start_line, start_column)
      when '('
        advance
        Token.new(:lparen, '(', start_line, start_column)
      when ')'
        advance
        Token.new(:rparen, ')', start_line, start_column)
      when '['
        advance
        Token.new(:lbracket, '[', start_line, start_column)
      when ']'
        advance
        Token.new(:rbracket, ']', start_line, start_column)
      when ':'
        advance
        Token.new(:colon, ':', start_line, start_column)
      when '|'
        advance
        Token.new(:pipe, '|', start_line, start_column)
      when '='
        advance
        Token.new(:equals, '=', start_line, start_column)
      when '!'
        advance
        Token.new(:bang, '!', start_line, start_column)
      when '$'
        advance
        Token.new(:dollar, '$', start_line, start_column)
      when '@'
        advance
        Token.new(:at, '@', start_line, start_column)
      when '.'
        if peek(1) == '.' && peek(2) == '.'
          advance(3)
          Token.new(:spread, '...', start_line, start_column)
        else
          raise ParseError, "Unexpected character '.' at #{start_line}:#{start_column}"
        end
      when '"'
        read_string(start_line, start_column)
      when '-', '0'..'9'
        read_number(start_line, start_column)
      when 'a'..'z', 'A'..'Z', '_'
        read_name(start_line, start_column)
      else
        raise ParseError, "Unexpected character '#{char}' at #{start_line}:#{start_column}"
      end

      token
    end

    private

    def current_char
      @source[@pos]
    end

    def peek(offset = 1)
      @source[@pos + offset]
    end

    def advance(count = 1)
      count.times do
        if current_char == "\n"
          @line += 1
          @column = 1
        else
          @column += 1
        end
        @pos += 1
      end
    end

    def skip_ignored
      loop do
        break if @pos >= @source.length
        char = current_char

        case char
        when ' ', "\t", "\r", "\n", ','
          advance
        when '#'
          skip_comment
        else
          break
        end
      end
    end

    def skip_comment
      advance while @pos < @source.length && current_char != "\n"
    end

    def read_string(start_line, start_column)
      advance # skip opening quote
      value = ""

      loop do
        raise ParseError, "Unterminated string at #{start_line}:#{start_column}" if @pos >= @source.length

        char = current_char

        if char == '"'
          advance
          break
        elsif char == '\\'
          advance
          escape_char = current_char
          value += case escape_char
          when '"', '\\', '/'
            escape_char
          when 'n'
            "\n"
          when 't'
            "\t"
          when 'r'
            "\r"
          when 'b'
            "\b"
          when 'f'
            "\f"
          when 'u'
            # Unicode escape sequence \uXXXX
            advance
            hex = @source[@pos, 4]
            raise ParseError, "Invalid unicode escape at #{@line}:#{@column}" unless hex =~ /\A[0-9a-fA-F]{4}\z/
            advance(3)
            [hex.to_i(16)].pack('U')
          else
            raise ParseError, "Invalid escape sequence \\#{escape_char} at #{@line}:#{@column}"
          end
          advance
        else
          value += char
          advance
        end
      end

      Token.new(:string, value, start_line, start_column)
    end

    def read_number(start_line, start_column)
      value = ""
      is_float = false

      # Optional negative sign
      if current_char == '-'
        value += current_char
        advance
      end

      # Integer part
      if current_char == '0'
        value += current_char
        advance
      else
        while current_char =~ /[0-9]/
          value += current_char
          advance
        end
      end

      # Fractional part
      if current_char == '.'
        is_float = true
        value += current_char
        advance

        raise ParseError, "Invalid number at #{start_line}:#{start_column}" unless current_char =~ /[0-9]/

        while current_char =~ /[0-9]/
          value += current_char
          advance
        end
      end

      # Exponent part
      if current_char =~ /[eE]/
        is_float = true
        value += current_char
        advance

        if current_char =~ /[+-]/
          value += current_char
          advance
        end

        raise ParseError, "Invalid number at #{start_line}:#{start_column}" unless current_char =~ /[0-9]/

        while current_char =~ /[0-9]/
          value += current_char
          advance
        end
      end

      type = is_float ? :float : :int
      Token.new(type, value, start_line, start_column)
    end

    def read_name(start_line, start_column)
      value = ""

      while current_char =~ /[a-zA-Z0-9_]/
        value += current_char
        advance
      end

      # Check for keywords
      type = case value
      when "true", "false"
        :boolean
      when "null"
        :null
      else
        :name
      end

      Token.new(type, value, start_line, start_column)
    end
  end
end
