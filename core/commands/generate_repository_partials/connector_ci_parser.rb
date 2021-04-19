# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the Connectors CI repository
module ConnectorCiParser
  extend RepositoryParserCore

  def self.parse(config, connector_version, mdbe_ci_config, connector_name,
                 deb_package_name, rpm_package_name, log, logger)
    return [] if mdbe_ci_config.nil?

    auth_mdbe_ci_repo = mdbe_ci_config['mdbe_ci_repo']
    releases = []
    releases.concat(parse_connector_ci_rpm_repository(config['repo'], connector_version,
                                                      auth_mdbe_ci_repo, connector_name,
                                                      rpm_package_name, log, logger))
    releases.concat(parse_connector_ci_deb_repository(config['repo'], connector_version,
                                                      auth_mdbe_ci_repo, connector_name,
                                                      deb_package_name, log, logger))
    releases
  end

  def self.parse_connector_ci_rpm_repository(config, connector_version, auth,
                                             connector_name, package_name, log, logger)
    parse_repository(
      config['path'], auth, add_auth_to_url(config['key'], auth), connector_name, connector_version,
      [package_name],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)/?$}),
      append_path_if_exists('x86_64'),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_connector_ci_deb_repository(config, connector_version, auth,
                                             connector_name, package_name, log, logger)
    parse_repository(
      config['path'], auth, add_auth_to_url(config['key'], auth), connector_name, connector_version,
      [package_name],
      ->(url, _) { generate_connector_ci_deb_full_url(url, package_name) },
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

  def self.generate_connector_ci_deb_full_url(incorrect_url, package_name)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    "#{split_url.join('/')}/pool/main/m/#{package_name}/"
  end
end
