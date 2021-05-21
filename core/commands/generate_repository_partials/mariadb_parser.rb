# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MariaDB repository
module MariadbParser
  extend RepositoryParserCore

  def self.parse(config, product_version, log, logger)
    releases = []
    version_regexp = %r{^(\p{Digit}+\.\p{Digit}+(\.\p{Digit}+)?)\/?$}
    releases.concat(
      parse_mariadb_rpm_repository(config['repo']['rpm'], product_version, 'mariadb', version_regexp, log, logger)
    )
    releases.concat(
      parse_mariadb_deb_repository(config['repo']['deb'], product_version, 'mariadb', version_regexp, log, logger)
    )
    releases
  end

  def self.parse_mariadb_rpm_repository(config, product_version, product, version_regexp, log, logger)
    parse_repository(
      config['path'], nil, config['key'], product, product_version, %w[MariaDB-client MariaDB-server],
      ->(url, _) { "#{url}rpms/" },
      ->(package, _) { /#{package}/ },
      log, logger,
      extract_field(:version, version_regexp),
      append_url(%w[centos rhel sles opensuse], :platform),
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      append_url(%w[x86_64 aarch64], :architecture),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def self.parse_mariadb_deb_repository(config, product_version, product, version_regexp, log, logger)
    parse_repository(
      config['path'], nil, config['key'], product, product_version, %w[mariadb-client mariadb-server],
      ->(url, _) { generate_mariadb_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ },
      log, logger,
      extract_field(:version, version_regexp),
      save_as_field(:platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        release[:repo] = "#{release[:repo_url]} #{release[:platform_version]} main"
        release
      end
    )
  end

  def self.generate_mariadb_deb_full_url(incorrect_url)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')
    mariadb_version = '5.1' if url.include?('5.1')
    mariadb_version = '5.2' if url.include?('5.2')
    mariadb_version = '5.3' if url.include?('5.3')
    mariadb_version = '5.5' if url.include?('5.5')
    mariadb_version = '10.0' if url.include?('10.0')
    mariadb_version = '10.1' if url.include?('10.1')
    mariadb_version = '10.2' if url.include?('10.2')
    mariadb_version = '10.3' if url.include?('10.3')
    mariadb_version = '10.4' if url.include?('10.4')
    mariadb_version = '10.5' if url.include?('10.5')
    mariadb_version = '10.6' if url.include?('10.6')
    "#{url}/pool/main/m/mariadb-#{mariadb_version}/"
  end
end
