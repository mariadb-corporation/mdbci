# frozen_string_literal: true

require_relative 'parse_helper'

# This module handles the Maxscale repository
module MaxscaleParser
  def self.parse(config, log, logger)
    releases = []
    releases.concat(parse_maxscale_rpm_repository(config['repo']['rpm'], log, logger))
    releases.concat(parse_maxscale_deb_repository(config['repo']['deb'], log, logger))
    releases
  end

  def self.parse_maxscale_rpm_repository(config, log, logger)
    ParseHelper.parse_repository(
      config['path'], nil, config['key'], 'maxscale',
      %w[maxscale],
      ->(url) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      ParseHelper.save_as_field(:version),
      ParseHelper.split_rpm_platforms,
      ParseHelper.extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      ParseHelper.append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def self.parse_maxscale_deb_repository(config, log, logger)
    ParseHelper.parse_repository(
      config['path'], nil, config['key'], 'maxscale',
      %w[maxscale],
      ->(url) { "#{url}main/binary-amd64/" },
      ->(package, _) { /#{package}/ },
      log, logger,
      ParseHelper.save_as_field(:version),
      ParseHelper.append_url(%w[debian ubuntu], :platform, true),
      ParseHelper.append_url(%w[dists]),
      ParseHelper.save_as_field(:platform_version),
      lambda do |release, _|
        release[:repo] = "#{release[:repo_url]} #{release[:platform_version]} main"
        release
      end
    )
  end
end
