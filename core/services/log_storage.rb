# frozen_string_literal: true

require_relative '../out'

# Class provides storage of logs
class LogStorage < Out
  def initialize
    super
    @logs = []
  end

  def out(string)
    return if string.nil?

    @logs.push(string)
  end

  def print_to_stdout
    @logs.each { |log_line| @stream.puts(log_line) }
  end

  def print_raw_line(string)
    @logs.push(string)
  end
end
