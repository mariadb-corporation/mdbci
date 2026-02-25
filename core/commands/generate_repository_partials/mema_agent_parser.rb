# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MemaAgent repository
module MemaAgentParser
  extend RepositoryParserCore

  def self.parse(config, product_version, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth = mdbe_ci_config['mdbe_ci_repo']
    releases = []
    releases.concat(parse_mema_agent_rpm_repository(config['repo'], product_version, auth,
                                                    config['scan_mode'], log, logger))
    releases.concat(parse_mema_agent_deb_repository(config['repo'], product_version, auth,
                                                    config['scan_mode'], log, logger))
    releases.uniq! do |release|
      [release[:architecture], release[:platform], release[:platform_version], release[:product],
       release[:version]]
    end
    releases
  end

  def self.parse_mema_agent_rpm_repository(config, product_version, auth, scan_mode, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mema_agent', product_version,
      %w[mema-agent],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ }, scan_mode, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['key'], auth)),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)/?$}),
      append_url(%w[x86_64 aarch64 ppc64le], :architecture),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.generate_mema_agent_deb_full_url(incorrect_url, release)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')
    "#{url}/pool/main/m/#{release}/"
  end

  def self.parse_mema_agent_deb_repository(config, product_version, auth, scan_mode, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mema_agent', product_version,
      %w[mema-agent],
      ->(url, _) { generate_mema_agent_deb_full_url(url, 'mema-agent') },
      ->(package, platform) { /#{package}.*#{platform}/ }, scan_mode, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['key'], auth)),
      append_url(%w[apt], nil, true),
      append_url(%w[dists]),
      extract_deb_platforms,
      set_deb_architecture(auth),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:repo_url], auth)
        release[:components] = ['main']
        release
      end
    )
  end
end
