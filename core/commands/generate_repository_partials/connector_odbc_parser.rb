# frozen_string_literal: true

require_relative 'repository_parser_core'

# Handles the ODBC connector repository
module ConnectorOdbcParser
  extend RepositoryParserCore

  def self.parse(config, product_version, user_ui, logger, product = 'connector_odbc', private_key = nil)
    base_url = setup_private_key(config['repo']['path'], private_key)
    archive_directories = parse_web_directories(
      base_url,
      nil,
      product_version,
      user_ui,
      logger,
      extract_field(:base_version, /(\d.+)/),
      extract_field(:version, /(\d.+)/)
    )
    releases = archive_directories.each_with_object([]) do |directory, releases|
      archives_links = get_links(directory[:url], logger).filter { |link| link[:content].match?(/(x86_64)|(amd64)/) }
      archives = get_releases_platform_info(archives_links)
      next unless !archives.nil? && !archives.empty?

      archives.each do |archive|
        releases.append(archive.merge({
                                        version: directory[:version],
                                        product: product,
                                        architecture: 'amd64'
                                      }))
      end
    end
    releases += find_similar_rpm_releases(releases)

    releases
  end

  # Creates new releases for rpm platforms based on releases of similar platforms, if no releases was found.
  def self.find_similar_rpm_releases(releases)
    rpm_platforms = %w[rhel centos rocky]
    rpm_releases = releases.filter { |release| rpm_platforms.include?(release[:platform]) }
                           .each_with_object({}) do |release, versions|
      versions[release[:version]] = [] unless versions.key?(:version)
      versions[release[:version]] << release
    end
    similar_releases = []
    rpm_releases.each do |_, founded_releases|
      missing_platforms = rpm_platforms - founded_releases.map { |release| release[:platform] }
      similar_releases += missing_platforms.map { |platform| founded_releases.first.merge({ platform: platform }) }
    end
    similar_releases
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
