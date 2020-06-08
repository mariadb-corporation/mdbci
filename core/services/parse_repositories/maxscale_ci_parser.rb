# frozen_string_literal: true

require_relative 'parse_helper'

# This module handles the Maxscale CI repository
module MaxscaleCiParser
  def self.parse(config, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth = mdbe_ci_config['mdbe_ci_repo']
    releases = []
    releases.concat(parse_maxscale_ci_rpm_repository(config['repo'], auth, log, logger))
    releases.concat(parse_maxscale_ci_deb_repository(config['repo'], auth, log, logger))
    releases
  end

  def self.parse_maxscale_ci_rpm_repository(config, auth, log, logger)
    ParseHelper.parse_repository(
      config['path'], auth, ParseHelper.add_auth_to_url(config['key'], auth), 'maxscale_ci',
      %w[maxscale],
      ->(url) { url },
      ->(package, _) { /#{package}/ }, log, logger,
      ParseHelper.save_as_field(:version),
      ParseHelper.append_url(%w[mariadb-maxscale]),
      ParseHelper.split_rpm_platforms,
      ParseHelper.extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      ParseHelper.append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = ParseHelper.add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_maxscale_ci_deb_repository(config, auth, log, logger)
    ParseHelper.parse_repository(
      config['path'], auth, ParseHelper.add_auth_to_url(config['key'], auth), 'maxscale_ci',
      %w[maxscale], ->(url) { "#{url}main/binary-amd64/" },
      ->(package, _) { /#{package}/ }, log, logger,
      ParseHelper.save_as_field(:version),
      ParseHelper.append_url(%w[mariadb-maxscale]),
      ParseHelper.append_url(%w[debian ubuntu], :platform, true),
      ParseHelper.append_url(%w[dists]),
      ParseHelper.save_as_field(:platform_version),
      lambda do |release, _|
        url = ParseHelper.add_auth_to_url(release[:url], auth)
        release[:repo] = "#{url} #{release[:platform_version]} main"
        release
      end
    )
  end
end
