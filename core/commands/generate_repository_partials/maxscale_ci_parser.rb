# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the Maxscale CI repository
module MaxscaleCiParser
  extend RepositoryParserCore

  def self.parse(config, product_version, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth = mdbe_ci_config['mdbe_ci_repo']
    releases = []
    releases.concat(parse_maxscale_ci_rpm_repository_new(config['repo'], product_version, auth,
                                                         log, logger))
    releases.concat(parse_maxscale_ci_deb_repository_new(config['repo'], product_version, auth,
                                                         log, logger))
    releases.concat(parse_maxscale_ci_rpm_repository_old(config['repo'], product_version, auth,
                                                         log, logger))
    releases.concat(parse_maxscale_ci_deb_repository_old(config['repo'], product_version, auth,
                                                         log, logger))
    releases
  end

  def self.parse_maxscale_ci_rpm_repository_new(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'maxscale_ci', product_version,
      %w[maxscale],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ }, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['new_key'], auth)),
      append_url(%w[yum]),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)/?$}),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_maxscale_ci_deb_repository_new(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'maxscale_ci', product_version,
      %w[maxscale],
      ->(url, _) { generate_maxscale_ci_deb_full_url(url) },
      ->(package, platform) { /#{package}.*#{platform}/ }, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['new_key'], auth)),
      append_url(%w[apt], nil, true),
      append_url(%w[dists]),
      extract_deb_platforms,
      set_deb_architecture(auth),
      lambda do |release, _|
        repo_path = add_auth_to_url(release[:repo_url], auth)
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release
      end
    )
  end

  def self.generate_maxscale_ci_deb_full_url(incorrect_url)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')
    "#{url}/pool/main/m/maxscale/"
  end

  def self.parse_maxscale_ci_rpm_repository_old(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'maxscale_ci', product_version,
      %w[maxscale],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ }, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['old_key'], auth)),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)/?$}),
      append_url(%w[x86_64 aarch64], :architecture),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_maxscale_ci_deb_repository_old(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'maxscale_ci', product_version,
      %w[maxscale], ->(url, _) { "#{url}main/binary-amd64/" },
      ->(package, _) { /#{package}/ }, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['old_key'], auth)),
      append_url(%w[debian ubuntu], :platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        url = add_auth_to_url(release[:repo_url], auth)
        release[:repo] = "#{url} #{release[:platform_version]} main"
        release
      end
    )
  end
end
