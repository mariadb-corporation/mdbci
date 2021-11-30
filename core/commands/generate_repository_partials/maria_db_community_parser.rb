# frozen_string_literal: true

require_relative 'repository_parser_core'

# The parser module for MariaDB repositories that are hosted on Google
module MariaDBCommunityParser
  extend RepositoryParserCore

  MARIADB_COMMUNITY = {
    label: 'Community Server',
    server: 'https://dlm.mariadb.com/repo/mariadb-server',
  }.freeze

  MAXSCALE_SERVER = {
    label: 'MariaDB MaxScale',
    server: 'https://dlm.mariadb.com/repo/maxscale',
  }.freeze

  def self.parse(config, product_config, product_name, product_version, user_ui, logger)
    repos = [].concat(
      parse_releases(
        config['deb'],
        product_config,
        product_name,
        product_version,
        :form_deb_repositories,
        user_ui,
        logger
      ),
      parse_releases(
        config['rpm'],
        product_config,
        product_name,
        product_version,
        :form_rpm_repositories,
        user_ui,
        logger
      ),
    )
    repos
  end

  def self.parse_releases(
    repo_config, product_config, product_name, product_version, link_parser, user_ui, logger
  )
    auth = nil
    releases = parse_web_directories(
      repo_config['path'],
      auth,
      product_version,
      user_ui,
      logger,
      extract_field(:base_version, %r{^#{product_config[:label]} (.*)$}),
      extract_field(:version, %r{^#{product_config[:label]} (.*)$}),
    )
    releases = Workers.map(releases) do |release|
      flat_url = URI.join(release[:url], '?flat=1').to_s
      all_links = get_links(flat_url, logger, auth).map do |link|
        link_parts = link[:content].split('/')
        link.merge({parts: link_parts})
      end

      method(link_parser).call(all_links, release, product_config[:server])
    end.flatten
    add_key_and_product_to_releases(releases, repo_config['key'], product_name)
  end


  def self.form_deb_repositories(links, release, server_location)
    # Filter out debian releases based on the /repo/PROVIDER/dists/RELESASE/ content strings
    links.select do |link|
      link[:parts].first == 'repo' &&
        link[:parts].fetch(2, '') == 'dists' &&
        link[:parts].fetch(4, '') == 'main' &&
        link[:parts].fetch(5, '').start_with?('binary-')
    end.map do |link|
      platform = link[:parts].fetch(1, '')
      platform_version = link[:parts].fetch(3, '')
      architecture = determine_deb_architecture(link[:parts].fetch(5, ''))
      release.merge(
        {
          platform: platform,
          platform_version: platform_version,
          architecture: architecture,
          repo: "#{server_location}/#{release[:version]}/repo/#{platform} #{platform_version} main"
        }
      )
    end
  end

  def self.form_rpm_repositories(links, release, server_location)
    # Filter out MDBE releasese based on /yum/PLATFORM/PLATFORM_VERSION/ARCHITECTURE/repodata/ link
    links.select do |link|
      link[:parts].fetch(0, '') == 'yum' &&
        link[:parts].fetch(4, '') == 'repodata' &&
        link[:parts].fetch(5, '') == 'repomd.xml'
    end.map do |link|
      platform = link[:parts].fetch(1, '')
      platform_version = link[:parts].fetch(2, '')
      raw_architecture = link[:parts].fetch(3, '')
      architecture = determine_rpm_architecture(raw_architecture)
      release.merge(
        {
          platform: platform,
          platform_version: platform_version,
          architecture: architecture,
          repo: "#{server_location}/#{release[:version]}/yum/#{platform}/#{platform_version}/#{raw_architecture}"
        }
      )
    end
  end
end
