# frozen_string_literal: true

require_relative 'parse_helper'

# This module handles the MySQL repository
module MysqlParser
  def self.parse(config, log, logger)
    releases = []
    releases.concat(parse_mysql_rpm_repository(config['repo']['rpm'], log, logger))
    releases.concat(parse_mysql_deb_repository(config['repo']['deb'], log, logger))
    releases
  end

  def self.parse_mysql_deb_repository(config, log, logger)
    ParseHelper.parse_repository(
      config['path'], nil, config['key'], 'mysql', %w[mysql],
      ->(url) { generate_mysql_url(url) },
      ->(package, _) { /#{package}/ },
      log, logger,
      ParseHelper.append_url(%w[debian ubuntu], :platform, true),
      ParseHelper.append_url(%w[dists]),
      ParseHelper.save_as_field(:platform_version),
      ParseHelper.extract_field(:version, %r{^mysql-(\d+\.?\d+(-[^\/]*)?)(\/?)$}),
      lambda do |release, _|
        release[:repo] = "deb #{release[:repo_url]} #{release[:platform_version]}"\
                       " mysql-#{release[:version]}"
        release
      end
    )
  end

  # Method parses MySQL repositories that correspond to the following scheme:
  # http://repo.mysql.com/yum/mysql-8.0-community/el/7/x86_64/
  def self.parse_mysql_rpm_repository(config, log, logger)
    ParseHelper.parse_repository(
      config['path'], nil, config['key'], 'mysql', %w[mysql],
      ->(url) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      ParseHelper.extract_field(:version, %r{^mysql-(\d+\.?\d+)-community(\/?)$}),
      ParseHelper.split_rpm_platforms,
      ParseHelper.save_as_field(:platform_version),
      ParseHelper.append_url(%w[x86_64], :repo),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def self.generate_mysql_url(incorrect_url)
    split_url = incorrect_url.split('/')
    split_url.pop(3)
    url = split_url.join('/')
    mysql_version = '5.6' if incorrect_url.include?('5.6')
    mysql_version = '5.7' if incorrect_url.include?('5.7')
    mysql_version = '5.7-dmr' if incorrect_url.include?('5.7-dmr')
    mysql_version = '8.0' if incorrect_url.include?('8.0')
    mysql_version = '9.0' if incorrect_url.include?('9.0')
    "#{url}/pool/mysql-#{mysql_version}/m/mysql-community"
  end
end
