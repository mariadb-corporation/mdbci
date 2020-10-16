# frozen_string_literal: true

require_relative 'repository_parser_core'
require_relative '../../services/sem_version_parser'

# This module handles the Maxscale repository
module MaxscaleParser
  extend RepositoryParserCore

  def self.parse(config, product_version, log, logger)
    releases = []
    releases.concat(parse_maxscale_rpm_repository(config['repo']['rpm'], product_version, log, logger))
    releases.concat(parse_maxscale_deb_repository(config['repo']['deb'], product_version, log, logger))
    releases
  end

  def self.setup_new_key(new_key, new_key_sem_versions)
    lambda do |release, _|
      version = SemVersionParser.new_sem_version(release[:version])
      release[:repo_key] = new_key if new_key_sem_versions.any? do |new_key_version|
        !version.nil? && !new_key_version.nil? &&
          version.satisfies?("~> #{new_key_version.to_s}") && version.minor == new_key_version.minor
      end
      release
    end
  end

  def self.parse_maxscale_rpm_repository(config, product_version, log, logger)
    new_key_sem_versions = config['new_key_versions'].map { |version| SemVersionParser.new_sem_version(version) }
    parse_repository(
      config['path'], nil, config['key'], 'maxscale', product_version,
      %w[maxscale],
      ->(url) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end,
      setup_new_key(config['new_key'], new_key_sem_versions)
    )
  end

  def self.parse_maxscale_deb_repository(config, product_version, log, logger)
    new_key_sem_versions = config['new_key_versions'].map { |version| SemVersionParser.new_sem_version(version) }
    parse_repository(
      config['path'], nil, config['key'], 'maxscale', product_version,
      %w[maxscale],
      ->(url) { "#{url}main/binary-amd64/" },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      append_url(%w[debian ubuntu], :platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        release[:repo] = "#{release[:repo_url]} #{release[:platform_version]} main"
        release
      end,
      setup_new_key(config['new_key'], new_key_sem_versions)
    )
  end
end
