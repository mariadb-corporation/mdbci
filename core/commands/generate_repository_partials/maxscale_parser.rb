# frozen_string_literal: true

require_relative 'repository_parser_core'
require_relative '../../services/sem_version_parser'

# This module handles the Maxscale repository
module MaxscaleParser
  extend RepositoryParserCore

  def self.parse(config, product_version, log, logger)
    releases = []
    releases.concat(parse_maxscale_rpm_repository(config['repo']['rpm'], product_version, log, logger))
    releases.concat(parse_maxscale_deb_repository(config['repo']['deb'], product_version, log, logger))
    releases
  end

  def self.setup_old_key(old_keys)
    lambda do |release, _|
      version = SemVersionParser.new_sem_version(release[:version])
      old_keys.each do |old_key_data|
        use_old_key = if old_key_data.key?('versions_upper_bound') && !version.nil?
                        old_key_data['versions_upper_bound'].all? do |old_key_version|
                          old_key_version.nil? ||
                            !(version.satisfies?("~> #{old_key_version.to_s}") &&
                              version.minor == old_key_version.minor)
                        end
                      else
                        false
                      end
        release[:repo_key] = old_key_data['key'] if use_old_key
      end
      release
    end
  end

  def self.generate_old_keys_data(old_keys)
    old_keys.map do |old_key_data|
      next old_key_data unless old_key_data.key?('versions_upper_bound')

      versions_upper_bound = old_key_data['versions_upper_bound'].map do |version|
        SemVersionParser.new_sem_version(version)
      end
      old_key_data.merge({ 'versions_upper_bound' => versions_upper_bound })
    end
  end

  def self.parse_maxscale_rpm_repository(config, product_version, log, logger)
    old_keys = generate_old_keys_data(config['old_keys'])
    parse_repository(
      config['path'], nil, config['key'], 'maxscale', product_version,
      %w[maxscale],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end,
      setup_old_key(old_keys)
    )
  end

  def self.parse_maxscale_deb_repository(config, product_version, log, logger)
    old_keys = generate_old_keys_data(config['old_keys'])
    parse_repository(
      config['path'], nil, config['key'], 'maxscale', product_version,
      %w[maxscale],
      ->(url, repo) { ["#{url}main/binary-amd64/", "#{repo[:repo_url]}/pool/main/m/maxscale/"] },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      append_url(%w[debian ubuntu], :platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        release[:repo] = "#{release[:repo_url]} #{release[:platform_version]} main"
        release
      end,
      setup_old_key(old_keys)
    )
  end
end
