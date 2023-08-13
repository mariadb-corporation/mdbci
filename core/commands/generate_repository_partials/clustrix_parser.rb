# frozen_string_literal: true

require_relative 'repository_parser_core'
require_relative '../../services/sem_version_parser'

# This module handles the Clustrix repository
module ClustrixParser
  extend RepositoryParserCore
  CLUSTRIX_PLATFORMS = %w[centos_7 rhel_7].freeze
  CLUSTRIX_STAGING_PLATFORMS = %w[centos_7 rhel_7 centos_9 rhel_9].freeze

  def self.parse(config, private_key, link_name, product_name)
    parse_clustrix_repository(config['repo'], private_key, link_name, product_name)
  end

  def self.clustrix_release_link?(link, link_name)
    link.content =~ /^#{link_name} \d+(\.\d+)*$/
  end

  def self.clustrix_tar_link?(link)
    link.content =~ /^.*\.tar\.bz2$/
  end

  def self.get_clustrix_links(path)
    uri = path.gsub(%r{([^:])/+}, '\1/')
    doc = Nokogiri::HTML(URI.open(uri))
    all_links = doc.css('a')
    all_links.select do |link|
      yield(link) if block_given?
    end
  end

  def self.get_clustrix_release_links(path, link_name)
    get_clustrix_links(path) { |link| clustrix_release_link?(link, link_name) }
  end

  def self.get_clustrix_tar_links(path)
    get_clustrix_links(path) { |link| clustrix_tar_link?(link) }
  end

  def self.generate_url_by_link(path_uri, link)
    path = URI.parse(link.attribute('href').to_s).path
    "#{path_uri.scheme}://#{path_uri.host}/#{path}"
  end

  def self.get_release_paths(path_uri, paths, link_name)
    paths.map do |path|
      get_clustrix_release_links(path, link_name).map do |major_release_link|
        generate_url_by_link(path_uri, major_release_link)
      end
    end.flatten
  end

  def self.get_clustrix_release_versions(config, private_key, link_name)
    paths = [setup_private_key(config['path'], private_key)]
    path_uri = URI.parse(paths.first)
    2.times do
      paths = get_release_paths(path_uri, paths, link_name)
    end
    paths.map do |path|
      get_clustrix_tar_links(path)
    end.flatten.map do |link|
      path = generate_url_by_link(path_uri, link)
      version = link.content.match(%r{^.*/xpand-(.+)\.[^.]+\.tar\.bz2$}).captures[0].strip
      { repo: path, version: version }
    end
  end

  def self.get_platform_version_by_link(link)
    link.match(/el\d+.tar.bz/i).to_s.split(/[^\d]/).join
  end

  def self.generate_clustrix_release_info(platforms, release_info, product_name)
    platforms.map do |platform_and_version|
      platform, platform_version = platform_and_version.split('_')
      platform_version = get_platform_version_by_link(release_info[:repo])
      release_info.merge({ repo_key: nil, platform: platform, platform_version: platform_version,
                           product: product_name })
    end.flatten
  end

  def self.parse_clustrix_repository(config, private_key, link_name, product_name)
    get_clustrix_release_versions(config, private_key, link_name).map do |release_info|
      case product_name
      when 'clustrix'
        supported_platforms = CLUSTRIX_PLATFORMS
      when 'clustrix_staging'
        supported_platforms = CLUSTRIX_STAGING_PLATFORMS
      end
      generate_clustrix_release_info(supported_platforms, release_info, product_name).uniq
    end.flatten
  end
end
