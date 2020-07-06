# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the Maxscale CI repository
module MaxscaleCiParser
  extend RepositoryParserCore

  def self.parse(config, product_version, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth = mdbe_ci_config['mdbe_ci_repo']
    releases = []
    releases.concat(parse_maxscale_ci_rpm_repository(config['repo'], product_version, auth, log, logger))
    releases.concat(parse_maxscale_ci_deb_repository(config['repo'], product_version, auth, log, logger))
    releases
  end

  def self.parse_maxscale_ci_rpm_repository(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'maxscale_ci', product_version,
      %w[maxscale],
      ->(url) { url },
      ->(package, _) { /#{package}/ }, log, logger,
      save_as_field(:version),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_maxscale_ci_deb_repository(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'maxscale_ci', product_version,
      %w[maxscale], ->(url) { "#{url}main/binary-amd64/" },
      ->(package, _) { /#{package}/ }, log, logger,
      save_as_field(:version),
      append_url(%w[debian ubuntu], :platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        url = add_auth_to_url(release[:repo_url], auth)
        release[:repo] = "#{url} #{release[:platform_version]} main"
        release
      end
    )
  end
end
