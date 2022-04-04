# frozen_string_literal: true

require_relative 'repository_parser_core'

# Handles the ODBC connector repository
module ConnectorOdbcParser
  extend RepositoryParserCore

  def self.parse(config, product_version, user_ui, logger)
    archive_directories = parse_web_directories(
      config['repo']['path'],
      nil,
      product_version,
      user_ui,
      logger,
      extract_field(:base_version, /ODBC connector (\d.+)/),
      extract_field(:version, /ODBC connector (\d.+)/)
    )
    archive_directories.each_with_object([]) do |directory, releases|
      archives_links = get_links(directory[:url], logger).filter { |link| link[:content].match?(/(x86_64)|(amd64)/) }
      archives = get_releases_platform_info(archives_links)
      next unless !archives.nil? && !archives.empty?

      archives.each do |archive|
        releases.append(archive.merge({
                                        version: directory[:version],
                                        product: 'connector_odbc',
                                        architecture: 'amd64'
                                      }))
      end
    end
  end

  PLATFORMS = {
    'focal' => {
      platform: 'ubuntu',
      platform_version: 'focal'
    },
    'bionic' => {
      platform: 'ubuntu',
      platform_version: 'bionic'
    },
    'sles15' => {
      platform: 'sles',
      platform_version: '15'
    },
    'sles12' => {
      platform: 'sles',
      platform_version: '12'
    },
    'buster' => {
      platform: 'debian',
      platform_version: 'buster'
    },
    'stretch' => {
      platform: 'debian',
      platform_version: 'stretch'
    },
    'jessie' => {
      platform: 'debian',
      platform_version: 'jessie'
    },
    'debian8' => {
      platform: 'debian',
      platform_version: 'jessie'
    },
    'centos6' => {
      platform: 'centos',
      platform_version: '6'
    },
    'centos7' => {
      platform: 'centos',
      platform_version: '7'
    },
    'centos8' => {
      platform: 'centos',
      platform_version: '8'
    },
    'xenial' => {
      platform: 'ubuntu',
      platform_version: 'xenial'
    },
    'rhel6' => {
      platform: 'rhel',
      platform_version: '6'
    },
    'rhel7' => {
      platform: 'rhel',
      platform_version: '7'
    },
    'rhel8' => {
      platform: 'rhel',
      platform_version: '8'
    }
  }.freeze
  def self.get_releases_platform_info(links)
    links.each_with_object([]) do |link, releases|
      platform = PLATFORMS.keys.find { |image| link[:content].match?(image) }
      releases << (PLATFORMS[platform].merge({ repo: link[:href] })) if platform
    end
  end
end
