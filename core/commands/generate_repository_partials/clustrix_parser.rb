# frozen_string_literal: true

require_relative 'repository_parser_core'
require_relative '../../services/sem_version_parser'

# This module handles the Clustrix repository
module ClustrixParser
  extend RepositoryParserCore
  PRODUCT_NAME = 'clustrix'

  def self.parse(config, private_key, link_name)
    parse_clustrix_repository(config['repo'], private_key, link_name)
  end

  def self.clustrix_release_link?(link, link_name)
    link.content =~ /^#{link_name} \d+(\.\d+)*$/
  end

  def self.clustrix_tar_link?(link)
    link.content =~ /^.*\.tar\.bz2$/
  end

  def self.get_clustrix_links(path)
    uri = path.gsub(%r{([^:])\/+}, '\1/')
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

  def self.generate_latest_release(releases)
    releases
      .map { |release| release.merge({ sem_version: SemVersionParser.parse_sem_version(release[:version]) }) }
      .max { |a, b| a[:sem_version] <=> b[:sem_version] }
      .merge({ version: 'latest' })
  end

  def self.get_clustrix_release_versions(config, private_key, link_name)
    paths = [setup_private_key(config['path'], private_key)]
    path_uri = URI.parse(paths.first)
    2.times do
      paths = get_release_paths(path_uri, paths, link_name)
    end
    releases_info = paths.map do |path|
      get_clustrix_tar_links(path)
    end.flatten.map do |link|
      path = generate_url_by_link(path_uri, link)
      version = link.content.match(/^.*\/xpand-(.+)\.[^.]+\.tar\.bz2$/).captures[0].strip
      { repo: path, version: version }
    end
    releases_info.push(generate_latest_release(releases_info))
  end

  def self.generate_clustrix_release_info(platforms, release_info)
    platforms.map do |platform_and_version|
      platform, platform_version = platform_and_version.split('_')
      release_info.merge({ repo_key: nil, platform: platform, platform_version: platform_version,
                           product: PRODUCT_NAME })
    end.flatten
  end

  def self.parse_clustrix_repository(config, private_key, link_name)
    get_clustrix_release_versions(config, private_key, link_name).map do |release_info|
      generate_clustrix_release_info(config['platforms'], release_info)
    end.flatten
  end
end
