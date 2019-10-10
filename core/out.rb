# frozen_string_literal: true

# Class provides means to produce output to the application
class Out
  # @param silent [Boolean] whether the output should be suppressed or not
  def initialize(silent = false)
    @silent = silent
    @stream = $stdout
    @stream.sync = true
  end

  def out(string)
    return if string.nil?

    @stream.puts(string)
  end

  def debug(string)
    print_line('DEBUG', string)
  end

  def info(string)
    print_line('INFO', string)
  end

  def warning(string)
    print_line('WARNING', string)
  end

  def error(string)
    print_line('ERROR', string)
  end

  def prompt(string)
    return if @silent

    @stream.print("PROMPT: #{string} ")
    gets.strip
  end

  private

  def print_line(level, string)
    return if @silent || string.nil?

    timestamp = Time.now.strftime('%Y-%m-%dT%H:%M:%S')
    print_raw_line("#{timestamp} #{level}: #{string}")
  end

  protected

  def print_raw_line(string)
    @stream.puts(string)
  end
end
