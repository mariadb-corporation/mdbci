# frozen_string_literal: true

require_relative 'parse_helper'

# This module handles the MariaDB repository
module MariadbParser
  def self.parse(config, log, logger)
    releases = []
    version_regexp = %r{^(\p{Digit}+\.\p{Digit}+(\.\p{Digit}+)?)\/?$}
    releases.concat(
      parse_mariadb_rpm_repository(config['repo']['rpm'], 'mariadb', version_regexp, log, logger)
    )
    releases.concat(
      parse_mariadb_deb_repository(config['repo']['deb'], 'mariadb', version_regexp, log, logger)
    )
    releases
  end

  def self.parse_mariadb_rpm_repository(config, product, version_regexp, log, logger)
    ParseHelper.parse_repository(
      config['path'], nil, config['key'], product, %w[MariaDB-client MariaDB-server],
      ->(url) { "#{url}rpms/" },
      ->(package, _) { /#{package}/ },
      log, logger,
      ParseHelper.extract_field(:version, version_regexp),
      ParseHelper.append_url(%w[centos rhel sles opensuse], :platform),
      ParseHelper.extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      ParseHelper.append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def self.parse_mariadb_deb_repository(config, product, version_regexp, log, logger)
    ParseHelper.parse_repository(
      config['path'], nil, config['key'], product, %w[mariadb-client mariadb-server],
      ->(url) { generate_mariadb_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ },
      log, logger,
      ParseHelper.extract_field(:version, version_regexp),
      ParseHelper.save_as_field(:platform, true),
      ParseHelper.append_url(%w[dists]),
      ParseHelper.save_as_field(:platform_version),
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
    "#{url}/pool/main/m/mariadb-#{mariadb_version}/"
  end
end
