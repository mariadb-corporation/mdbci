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
      ->(url) { "#{url}rpms/" }, ->(package, _) { /#{package}/ }, log, logger,
      save_as_field(:version),
      append_url(%w[yum]),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      append_url(%w[x86_64]),
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
      %w[mariadb-client mariadb-server], ->(url) { generate_mariadb_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ }, log, logger,
      save_as_field(:version),
      append_url(%w[repo]),
      append_url(%w[debian ubuntu], :platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        release[:version] = release[:version].delete('mariadb-')
        release[:repo] = "#{release[:repo_url]} #{release[:platform_version]} main"
        release
      end
    )
  end

  def self.generate_mariadb_deb_full_url(incorrect_url)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')
    "#{url}/pool/main/m/mariadb-10.5/"
  end
end
