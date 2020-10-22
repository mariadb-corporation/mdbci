# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MDBE CI repository
module MdbeCiParser
  extend RepositoryParserCore
  DEFAULT_MDBE_VERSION = '10.5'

  def self.parse(config, product_version, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth_mdbe_ci_repo = mdbe_ci_config['mdbe_ci_repo']
    auth_es_repo = mdbe_ci_config['es_repo']
    releases = []
    releases.concat(
      parse_mdbe_ci_rpm_repository(config['repo']['mdbe_ci_repo'], product_version, auth_mdbe_ci_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_deb_repository(config['repo']['mdbe_ci_repo'], product_version, auth_mdbe_ci_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_es_repo_rpm_repository(config['repo']['es_repo'], product_version, auth_es_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_es_repo_deb_repository(config['repo']['es_repo'], product_version, auth_es_repo, log, logger)
    )
    releases
  end

  def self.parse_mdbe_ci_rpm_repository(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mdbe_ci', product_version,
      %w[MariaDB-client MariaDB-server],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['key'], auth)),
      append_url(%w[yum]),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      append_path_if_exists('x86_64'),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_mdbe_ci_deb_repository(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mdbe_ci', product_version,
      %w[mariadb-client mariadb-server],
      ->(url, repo) { generate_mdbe_ci_deb_full_url(url, repo[:version]) },
      ->(package, platform) { /#{package}.*#{platform}/ }, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['key'], auth)),
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

  # An example of the url param is https://mdbe-ci-repo.mariadb.net/MariaDBEnterprise/version/apt/dists/focal/
  # The last two paths are unnecessary (dists, focal)
  def self.generate_mdbe_ci_deb_full_url(url, version)
    mariadb_version = version.match(/^\D*(\d+\.\d+).*$/)&.captures&.fetch(0) || DEFAULT_MDBE_VERSION
    splited_url = url.split('/')
    splited_url.pop(2)
    "#{splited_url.join('/')}/pool/main/m/mariadb-#{mariadb_version}/"
  end

  def self.parse_mdbe_ci_es_repo_rpm_repository(config, product_version, auth, log, logger)
    parse_repository_recursive(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci', product_version,
      %w[MariaDB-client MariaDB-server], ->(url, _) { url },
      ->(package, _) { /#{package}/ }, log, logger,
      { lambda: append_to_field(:version),
        complete_condition: dirs?(%w[apt yum bintar sourcetar DEB RPMS]) },
      { lambda: append_url(%w[RPMS]) },
      { lambda: add_platform_and_version(:rpm) },
      { lambda: lambda do |release, _|
        release[:version] = release[:version].join('/')
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end }
    )
  end

  def self.parse_mdbe_ci_es_repo_deb_repository(config, product_version, auth, log, logger)
    parse_repository_recursive(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci', product_version,
      %w[mariadb-client mariadb-server],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ }, log, logger,
      { lambda: append_to_field(:version),
        complete_condition: dirs?(%w[apt yum bintar sourcetar DEB RPMS]) },
      { lambda: append_url(%w[DEB]) },
      { lambda: add_platform_and_version(:deb) },
      { lambda: lambda do |release, _|
        release[:version] = release[:version].join('/')
        release[:repo] = generate_deb_path(release[:url], auth)
        release
      end }
    )
  end

  def self.generate_deb_path(path, auth)
    split_path = path.split('/')
    platform_and_version = split_path.pop
    full_url = split_path.join('/')
    "#{add_auth_to_url(full_url, auth)}/ #{platform_and_version}/"
  end
end
