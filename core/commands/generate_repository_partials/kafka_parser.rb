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
      archives = RepositoryParserCore.append_releases_platforms(archives_links)
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
      latest_version = find_latest_kafka_version(releases)
      RepositoryParserCore.append_latest_version(latest_version, releases, 'kafka', 'amd64')
      releases
    end

  def self.find_latest_kafka_version(releases)
    max_version = releases.max { |a, b| a[:version] <=> b[:version] }
    max_version
  end
end
