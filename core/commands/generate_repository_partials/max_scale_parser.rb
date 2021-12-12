# frozen_string_literal: true

require_relative 'repository_parser_core'
require_relative 'maria_db_community_parser'

# Modification of MariaDB public repository parser for MaxScale repositories
module MaxScaleParser
  extend RepositoryParserCore

  MAX_SCALE_SERVER = {
    label: 'MariaDB MaxScale',
    server: 'https://dlm.mariadb.com/repo/maxscale',
  }.freeze

  def self.parse(config, product_version, user_ui, logger)
    repos = [].concat(
      MariaDBCommunityParser.parse_releases(
        config['deb'],
        MAX_SCALE_SERVER,
        'maxscale',
        product_version,
        method(:form_deb_repositories),
        user_ui,
        logger
      ),
      MariaDBCommunityParser.parse_releases(
        config['rpm'],
        MAX_SCALE_SERVER,
        'maxscale',
        product_version,
        MariaDBCommunityParser.method(:form_rpm_repositories),
        user_ui,
        logger
      ),
    )
    repos
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
          components: ["main"]
        }
      )
    end
  end
end
