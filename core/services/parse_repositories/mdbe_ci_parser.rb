# frozen_string_literal: true

require_relative 'parse_helper'

# This module handles the MDBE CI repository
module MdbeCiParser
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
    ParseHelper.parse_repository(
      config['path'], auth, ParseHelper.add_auth_to_url(config['key'], auth), 'mdbe_ci',
      %w[MariaDB-client MariaDB-server],
      ->(url) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      ParseHelper.save_as_field(:version),
      ParseHelper.append_url(%w[yum]),
      ParseHelper.split_rpm_platforms,
      ParseHelper.extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      lambda do |release, _|
        release[:repo] = ParseHelper.add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_mdbe_ci_deb_repository(config, auth, log, logger)
    ParseHelper.parse_repository(
      config['path'], auth, ParseHelper.add_auth_to_url(config['key'], auth), 'mdbe_ci',
      %w[mariadb-client mariadb-server],
      ->(url) { generate_mdbe_ci_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ }, log, logger,
      ParseHelper.save_as_field(:version),
      ParseHelper.append_url(%w[apt], nil, true),
      ParseHelper.append_url(%w[dists]),
      ParseHelper.extract_deb_platforms,
      lambda do |release, _|
        repo_path = ParseHelper.add_auth_to_url(release[:repo_url], auth)
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
    ParseHelper.parse_repository_recursive(
      config['path'], auth, ParseHelper.add_auth_to_url(config['key'], auth), 'mdbe_ci',
      %w[MariaDB-client MariaDB-server], ->(url) { url },
      ->(package, _) { /#{package}/ }, log, logger,
      { lambda: ParseHelper.append_to_field(:version),
        complete_condition: ParseHelper.dirs?(%w[apt yum bintar sourcetar]) },
      { lambda: ParseHelper.append_url(%w[yum]) },
      { lambda: ParseHelper.split_rpm_platforms },
      { lambda: ParseHelper.extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}) },
      { lambda: lambda do |release, _|
        release[:version] = release[:version].join('/')
        release[:repo] = ParseHelper.add_auth_to_url(release[:url], auth)
        release
      end }
    )
  end

  def self.parse_mdbe_ci_es_repo_deb_repository(config, auth, log, logger)
    ParseHelper.parse_repository_recursive(
      config['path'], auth, ParseHelper.add_auth_to_url(config['key'], auth), 'mdbe_ci',
      %w[mariadb-client mariadb-server], ->(url) { generate_mdbe_ci_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ }, log, logger,
      { lambda: ParseHelper.append_to_field(:version),
        complete_condition: ParseHelper.dirs?(%w[apt yum bintar sourcetar]) },
      { lambda: ParseHelper.append_url(%w[apt], nil, true) },
      { lambda: ParseHelper.append_url(%w[dists]) }, { lambda: ParseHelper.extract_deb_platforms },
      { lambda: lambda do |release, _|
        repo_path = ParseHelper.add_auth_to_url(release[:repo_url], auth)
        release[:version] = release[:version].join('/')
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release
      end }
    )
  end
end
