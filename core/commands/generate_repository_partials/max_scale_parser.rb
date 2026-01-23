# frozen_string_literal: true

require_relative 'repository_parser_core'
require_relative 'maria_db_community_parser'

# Modification of MariaDB public repository parser for MaxScale repositories
module MaxScaleParser
  extend RepositoryParserCore

  MAX_SCALE_SERVER = {
    label: 'MariaDB MaxScale',
    server: 'https://dlm.mariadb.com/repo/maxscale'
  }.freeze

  def self.parse(config, product_version, mdbe_private_key, product_name, user_ui, logger)
    deb_config = config['deb']
    rpm_config = config['rpm']
    if product_name.include? 'maxscale_enterprise'
      deb_config['path'] = setup_private_key(deb_config['path'], mdbe_private_key)
      rpm_config['path'] = setup_private_key(rpm_config['path'], mdbe_private_key)
      maxscale_config = {
        label: 'MariaDB MaxScale Enterprise',
        server: "https://dlm.mariadb.com/repo/#{mdbe_private_key}/maxscale-enterprise"
      }
    else
      maxscale_config = MAX_SCALE_SERVER
    end
    [].concat(
      MariaDBCommunityParser.parse_releases(
        deb_config,
        maxscale_config,
        product_name,
        product_version,
        method(:form_deb_repositories),
        config['scan_mode'],
        user_ui,
        logger
      ),
      MariaDBCommunityParser.parse_releases(
        rpm_config,
        maxscale_config,
        product_name,
        product_version,
        MariaDBCommunityParser.method(:form_rpm_repositories),
        config['scan_mode'],
        user_ui,
        logger
      )
    )
  end

  def self.form_deb_repositories(links, release, server_location)
    # Filter out debian releases based on the /PROVIDER/dists/RELESASE/ content strings
    links.select do |link|
      %w[debian ubuntu].include?(link[:parts].fetch(0, '')) &&
        link[:parts].fetch(1, '') == 'dists' &&
        link[:parts].fetch(3, '') == 'main' &&
        link[:parts].fetch(4, '').start_with?('binary-')
    end.map do |link|
      platform = link[:parts].fetch(0, '')
      platform_version = link[:parts].fetch(2, '')
      architecture = determine_deb_architecture(link[:parts].fetch(4, ''))
      release.merge(
        {
          platform: platform,
          platform_version: platform_version,
          architecture: architecture,
          repo: "#{server_location}/#{release[:version]}/apt",
          components: ['main']
        }
      )
    end
  end
end
