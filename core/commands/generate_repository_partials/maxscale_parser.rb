# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the Maxscale repository
module MaxscaleParser
  extend RepositoryParserCore

  def self.parse(config, log, logger)
    releases = []
    releases.concat(parse_maxscale_rpm_repository(config['repo']['rpm'], log, logger))
    releases.concat(parse_maxscale_deb_repository(config['repo']['deb'], log, logger))
    releases
  end

  def self.parse_maxscale_rpm_repository(config, log, logger)
    parse_repository(
      config['path'], nil, config['key'], 'maxscale',
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
      end
    )
  end

  def self.parse_maxscale_deb_repository(config, log, logger)
    parse_repository(
      config['path'], nil, config['key'], 'maxscale',
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
      end
    )
  end
end