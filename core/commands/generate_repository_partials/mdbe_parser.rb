# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MDBE repository
module MdbeParser
  extend RepositoryParserCore

  def self.parse(config, mdbe_private_key, link_name, product_name)
    releases = []
    releases.concat(parse_mdbe_repository(config['repo']['rpm'], mdbe_private_key, link_name,
                                          product_name))
    releases.concat(parse_mdbe_repository(config['repo']['deb'], mdbe_private_key, link_name,
                                          product_name, true))
    releases
  end

  MDBE_PLATFORMS = {
    'centos' => 'rhel',
    'rhel' => 'rhel',
    'sles' => 'sles'
  }.freeze
  def self.generate_mdbe_repo_path(path, version, platform, platform_version, mdbe_private_key)
    setup_private_key(path, mdbe_private_key)
      .sub('$MDBE_VERSION$', version)
      .sub('$PLATFORM$', MDBE_PLATFORMS[platform] || '')
      .sub('$PLATFORM_VERSION$', platform_version)
  end

  def self.mdbe_release_link?(link, link_name)
    link.content =~ /^#{link_name} [0-9]*\.?.*$/
  end

  def self.get_mdbe_release_links(path, link_name)
    uri = path.gsub(%r{([^:])/+}, '\1/')
    doc = Nokogiri::HTML(URI.open(uri))
    all_links = doc.css('a')
    all_links.select do |link|
      mdbe_release_link?(link, link_name)
    end
  end

  def self.get_mdbe_release_versions(config, mdbe_private_key, link_name)
    path = setup_private_key(config['path'], mdbe_private_key)
    path_uri = URI.parse(path)
    major_release_links = get_mdbe_release_links(path, link_name)
    minor_release_links = major_release_links.map do |major_release_link|
      major_release_path = URI.parse(major_release_link.attribute('href').to_s).path
      get_mdbe_release_links("#{path_uri.scheme}://#{path_uri.host}/#{major_release_path}",
                             link_name)
    end.flatten
    minor_release_links.map do |link|
      link.content.match(/^#{link_name} (.*)$/).captures[0].lstrip
    end
  end

  def self.generate_mdbe_release_info(baseurl, key, version, architecture, platform,
                                      platform_version, mdbe_private_key, product_name, deb_repo = false)
    repo_path = generate_mdbe_repo_path(
      baseurl, version, platform, platform_version, mdbe_private_key
    )
    repo_path = "#{repo_path} #{platform_version}" if deb_repo
    {
      repo: repo_path,
      repo_key: key,
      platform: platform,
      platform_version: platform_version,
      product: product_name,
      version: version,
      architecture: architecture
    }
  end

  def self.parse_mdbe_repository(config, mdbe_private_key, link_name, product_name, deb_repo = false)
    get_mdbe_release_versions(config, mdbe_private_key, link_name).map do |version|
      config['platforms'].map do |platform_and_version|
        platform, platform_version = platform_and_version.split('_')
        config['architectures'].map do |architecture|
          generate_mdbe_release_info(config['baseurl'], config['key'], version, architecture,
                                     platform, platform_version, mdbe_private_key, product_name, deb_repo)
        end
      end
    end.flatten
  end
end
