# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the Galera CI repository
module GaleraCiParser
  extend RepositoryParserCore

  def self.parse(config, product_version, mdbe_ci_config, galera_version, log, logger)
    return [] if mdbe_ci_config.nil?

    auth_mdbe_ci_repo = mdbe_ci_config['mdbe_ci_repo']
    releases = []
    releases.concat(parse_galera_ci_rpm_repository(config['repo'], product_version, auth_mdbe_ci_repo, galera_version, log, logger))
    releases.concat(parse_galera_ci_deb_repository(config['repo'], product_version, auth_mdbe_ci_repo, galera_version, log, logger))
    releases
  end

  def self.parse_galera_ci_rpm_repository(config, product_version, auth, galera_version, log, logger)
    parse_repository(
        config['path'], auth, add_auth_to_url(config['key'], auth), galera_version, product_version,
        %w[galera],
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

  def self.parse_galera_ci_deb_repository(config, product_version, auth, galera_version, log, logger)
    parse_repository(
        config['path'], auth, add_auth_to_url(config['key'], auth), galera_version, product_version,
        %w[galera],
        ->(url) { generate_galera_ci_deb_full_url(url) },
        ->(package, platform) { /#{package}.*#{platform}/ },
        log, logger,
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

  def self.generate_galera_ci_deb_full_url(incorrect_url)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')
    galera_version = '3' if url.include?('3')
    galera_version = '4' if url.include?('4')
    if url.include?('Enterprise') && galera_version == '4'
      return "#{url}/pool/main/g/galera-enterprise-#{galera_version}/"
    end
    "#{url}/pool/main/g/galera-#{galera_version}/"
  end
end
