# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MariaDB prestaging repository
module MdbePrestagingParser
  extend RepositoryParserCore

  def self.parse(config, product_version, auth_config, log, logger)
    auth = auth_config['es_repo']
    releases = []
    releases.concat(
      parse_mdbe_prestaging_rpm_repository(config['repo']['rpm'], product_version, auth, log,
                                           logger, config['unsupported'])
    )
    releases.concat(
      parse_mdbe_prestaging_deb_repository(config['repo']['rpm'], product_version, auth, log,
                                           logger, config['unsupported'])
    )
    releases
  end

  def self.parse_mdbe_prestaging_rpm_repository(config, product_version, auth, log, logger, unsupported_path)
    parse_repository(
      config['path'], auth, config['key'], 'mdbe_prestaging', product_version,
      %w[MariaDB-client MariaDB-server],
      ->(url, _) { "#{url}rpms/" },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      append_url(%w[rpm]),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)/?$}),
      append_url(%w[x86_64 aarch64], :architecture),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end,
      add_unsupported_repo(config['path'], unsupported_path, auth, log, logger)
    )
  end

  def self.parse_mdbe_prestaging_deb_repository(config, product_version, auth, log, logger, unsupported_path)
    parse_repository(
      config['path'], auth, config['key'], 'mdbe_prestaging', product_version, %w[mariadb-client mariadb-server],
      ->(url, _) { generate_mariadb_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ },
      log, logger,
      save_as_field(:version),
      append_url(%w[deb], nil, true),
      append_url(%w[dists]),
      extract_deb_platforms,
      set_deb_architecture(auth),
      lambda do |release, _|
        repo_path = add_auth_to_url(release[:repo_url], auth)
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release
      end,
      add_unsupported_repo(config['path'], unsupported_path, auth, log, logger)
    )
  end
end
