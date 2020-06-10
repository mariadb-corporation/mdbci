# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MDBE CI repository
module MdbeCiParser
  extend RepositoryParserCore

  def self.parse(config, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth_mdbe_ci_repo = mdbe_ci_config['mdbe_ci_repo']
    auth_es_repo = mdbe_ci_config['es_repo']
    releases = []
    releases.concat(
      parse_mdbe_ci_rpm_repository(config['repo']['mdbe_ci_repo'], auth_mdbe_ci_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_deb_repository(config['repo']['mdbe_ci_repo'], auth_mdbe_ci_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_es_repo_rpm_repository(config['repo']['es_repo'], auth_es_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_es_repo_deb_repository(config['repo']['es_repo'], auth_es_repo, log, logger)
    )
    releases
  end

  def self.parse_mdbe_ci_rpm_repository(config, auth, log, logger)
    parse_repository(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci',
      %w[MariaDB-client MariaDB-server],
      ->(url) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      append_url(%w[yum]),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_mdbe_ci_deb_repository(config, auth, log, logger)
    parse_repository(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci',
      %w[mariadb-client mariadb-server],
      ->(url) { generate_mdbe_ci_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ }, log, logger,
      save_as_field(:version),
      append_url(%w[apt], nil, true),
      append_url(%w[dists]),
      extract_deb_platforms,
      lambda do |release, _|
        repo_path = add_auth_to_url(release[:repo_url], auth)
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release
      end
    )
  end

  def self.generate_mdbe_ci_deb_full_url(incorrect_url)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')
    mariadb_version = '10.2'
    mariadb_version = '10.3' if url.include?('10.3')
    mariadb_version = '10.4' if url.include?('10.4')
    mariadb_version = '10.5' if url.include?('10.5')
    "#{url}/pool/main/m/mariadb-#{mariadb_version}/"
  end

  def self.parse_mdbe_ci_es_repo_rpm_repository(config, auth, log, logger)
    parse_repository_recursive(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci',
      %w[MariaDB-client MariaDB-server], ->(url) { url },
      ->(package, _) { /#{package}/ }, log, logger,
      { lambda: append_to_field(:version),
        complete_condition: dirs?(%w[apt yum bintar sourcetar]) },
      { lambda: append_url(%w[yum]) },
      { lambda: split_rpm_platforms },
      { lambda: extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}) },
      { lambda: lambda do |release, _|
        release[:version] = release[:version].join('/')
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end }
    )
  end

  def self.parse_mdbe_ci_es_repo_deb_repository(config, auth, log, logger)
    parse_repository_recursive(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci',
      %w[mariadb-client mariadb-server], ->(url) { generate_mdbe_ci_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ }, log, logger,
      { lambda: append_to_field(:version),
        complete_condition: dirs?(%w[apt yum bintar sourcetar]) },
      { lambda: append_url(%w[apt], nil, true) },
      { lambda: append_url(%w[dists]) }, { lambda: extract_deb_platforms },
      { lambda: lambda do |release, _|
        repo_path = add_auth_to_url(release[:repo_url], auth)
        release[:version] = release[:version].join('/')
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release
      end }
    )
  end
end
