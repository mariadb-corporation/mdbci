# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the Kafka repository
module KafkaParser
  extend RepositoryParserCore

  def self.parse(config, product_version, ui, logger)
    base_url = config['repo']['path']
    archive_directories = parse_web_directories(
      base_url,
      nil,
      product_version,
      ui,
      logger,
      extract_field(:base_version, /(\d+.\d+.\d+)/)
    )
    releases = archive_directories.each_with_object([]) do |directory, releases|
      archives_links = get_links(directory[:url], logger).filter {
        |link| link[:content].match?(/\d.tgz$/)
      }
      archives_links.map do |link|
        link[:href] = directory[:url] + link[:content]
      end
      archives = append_releases_platforms(archives_links)
      next unless !archives.nil? && !archives.empty?
      archives.each do |archive|
        version = archive[:repo].match(/\d+.\d+-\d.\d.\d/).to_s
        releases.append(archive.merge({
                                        version: version,
                                        product: 'kafka',
                                        architecture: 'amd64'
                                      }))
        end
      end
      releases
    end

  PLATFORMS = {
    'jammy' => {
      platform: 'ubuntu',
      platform_version: 'jammy'
    },
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
    'bullseye' => {
      platform: 'debian',
      platform_version: 'bullseye'
    },
    'bookworm' => {
      platform: 'debian',
      platform_version: 'bookworm'
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
    'centos9' => {
      platform: 'centos',
      platform_version: '9'
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
    },
    'rhel9' => {
      platform: 'rhel',
      platform_version: '9'
    }
  }.freeze

  def self.append_releases_platforms(links)
    links.each_with_object([]) do |link, releases|
      PLATFORMS.keys.map do |platform|
        releases << (PLATFORMS[platform].merge({ repo: link[:href] }))
      end
    end
  end
end
