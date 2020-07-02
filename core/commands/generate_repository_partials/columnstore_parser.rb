# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the Columnstore repository
module ColumnstoreParser
  extend RepositoryParserCore

  def self.parse(config, product_version, log, logger)
    releases = []
    releases.concat(parse_columnstore_rpm_repository(config['repo']['rpm'], product_version, log, logger))
    releases.concat(parse_columnstore_deb_repository(config['repo']['deb'], product_version, log, logger))
    releases
  end

  def self.parse_columnstore_rpm_repository(config, product_version, log, logger)
    parse_repository(
      config['path'], nil, config['key'], 'columnstore', product_version, %w[mariadb-columnstore],
      ->(url) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      append_url(%w[yum]),
      split_rpm_platforms,
      save_as_field(:platform_version),
      append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def self.parse_columnstore_deb_repository(config, product_version, log, logger)
    parse_repository(
      config['path'], nil, config['key'], 'columnstore', product_version, %w[mariadb-columnstore],
      ->(url) { generate_mdbe_ci_deb_full_url(url) },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      append_url(%w[repo]),
      extract_field(:platform, %r{^(\p{Alpha}+)\p{Digit}+\/?$}, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        release[:repo] = release[:repo_url]
        release
      end
    )
  end

  def self.generate_mdbe_ci_deb_full_url(incorrect_url)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')
    "#{url}/pool/main/m/"
  end
end
