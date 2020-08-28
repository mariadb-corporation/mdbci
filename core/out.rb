# frozen_string_literal: true

# Class provides means to produce output to the application
class Out
  # @param silent [Boolean] whether the output should be suppressed or not
  def initialize(silent = false, force = false)
    @silent = silent
    @force = force
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
    STDIN.gets.strip
  rescue Interrupt => _e
    'n'
  end

  def confirmation(info_string, confirm_string)
    return true if @force

    info(info_string)
    result = prompt(confirm_string)[0].casecmp('y').zero?
    info('Aborted!') unless result
    result
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
