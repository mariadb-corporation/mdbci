require 'sem_version'

module SemVersionParser
  def self.parse_sem_version(version)
    if SemVersion.valid?(version)
      SemVersion.new(version).to_a
    else
      version_match = version.match(/^(\d+)(\.(\d+)(\.(\d+)([_-](\d+)?))?)?.*/)
      return nil if version_match.nil?

      version_match.captures.values_at(*(0..7).step(2)).compact.map(&:to_i)
    end
  end

  def self.new_sem_version(version)
    SemVersion.new(parse_sem_version(version))
  rescue ArgumentError
    nil
  end
end
