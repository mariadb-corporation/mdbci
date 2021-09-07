# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MariaDB Staging repository
module MariadbStagingParser
  extend RepositoryParserCore

  def self.parse(config, product_version, log, logger)
    releases = []
    releases.concat(
      parse_mariadb_staging_rpm_repository(config['repo']['rpm'], product_version, log, logger)
    )
    releases.concat(
      parse_mariadb_staging_deb_repository(config['repo']['deb'], product_version, log, logger)
    )
    releases
  end

  def self.parse_mariadb_staging_rpm_repository(config, product_version, log, logger)
    parse_repository(
      config['path'], nil, config['key'], 'mariadb_staging', product_version,
      %w[MariaDB-client MariaDB-server],
      ->(url, _) { "#{url}rpms/" }, ->(package, _) { /#{package}/ }, log, logger,
      save_as_field(:version),
      append_url(%w[yum]),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      append_url(%w[x86_64 aarch64], :architecture),
      lambda do |release, _|
        release[:version] = release[:version].delete('mariadb-')
        release[:repo] = release[:url]
        release
      end
    )
  end

  def self.parse_mariadb_staging_deb_repository(config, product_version, log, logger)
    parse_repository(
      config['path'], nil, config['key'], 'mariadb_staging', product_version,
      %w[mariadb-client mariadb-server], ->(url, _) { generate_mariadb_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ }, log, logger,
      save_as_field(:version),
      append_url(%w[repo]),
      append_url(%w[debian ubuntu], :platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      set_deb_architecture(nil),
      lambda do |release, _|
        release[:version] = release[:version].delete('mariadb-')
        release[:repo] = "#{release[:repo_url]} #{release[:platform_version]} main"
        release
      end
    )
  end
end
