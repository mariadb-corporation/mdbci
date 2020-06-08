# frozen_string_literal: true

# This module handles the MDBE repository
module MdbeParser
  def self.parse(config, mdbe_private_key)
    releases = []
    releases.concat(parse_mdbe_repository(config['repo']['rpm'], mdbe_private_key))
    releases.concat(parse_mdbe_repository(config['repo']['deb'], mdbe_private_key, true))
    releases
  end

  def self.replace_template_by_mdbe_private_key(path, mdbe_private_key)
    return path if mdbe_private_key.nil?

    path.sub('$PRIVATE_KEY$', mdbe_private_key)
  end

  MDBE_PLATFORMS = {
    'centos' => 'rhel',
    'rhel' => 'rhel',
    'sles' => 'sles'
  }.freeze
  def self.generate_mdbe_repo_path(path, version, platform, platform_version, mdbe_private_key)
    replace_template_by_mdbe_private_key(path, mdbe_private_key)
      .sub('$MDBE_VERSION$', version)
      .sub('$PLATFORM$', MDBE_PLATFORMS[platform] || '')
      .sub('$PLATFORM_VERSION$', platform_version)
  end

  def self.mdbe_release_link?(link)
    link.content =~ /^MariaDB Enterprise Server [0-9]*\.?.*$/
  end

  def self.get_mdbe_release_links(path)
    uri = path.gsub(%r{([^:])\/+}, '\1/')
    doc = Nokogiri::HTML(URI.open(uri))
    all_links = doc.css('ul:not(.nav) a')
    all_links.select do |link|
      mdbe_release_link?(link)
    end
  end

  def self.get_mdbe_release_versions(config, mdbe_private_key)
    path = replace_template_by_mdbe_private_key(config['path'], mdbe_private_key)
    path_uri = URI.parse(path)
    major_release_links = get_mdbe_release_links(path)
    minor_release_links = major_release_links.map do |major_release_link|
      major_release_path = URI.parse(major_release_link.attribute('href').to_s).path
      get_mdbe_release_links("#{path_uri.scheme}://#{path_uri.host}/#{major_release_path}")
    end.flatten
    (major_release_links + minor_release_links).map do |link|
      link.content.match(/^MariaDB Enterprise Server (.*)$/).captures[0].lstrip
    end
  end

  def self.generate_mdbe_release_info(baseurl, key, version, platform,
                                      platform_version, mdbe_private_key, deb_repo = false)
    repo_path = generate_mdbe_repo_path(
      baseurl, version, platform, platform_version, mdbe_private_key
    )
    repo_path = "#{repo_path} #{platform_version}" if deb_repo
    {
      repo: repo_path,
      repo_key: key,
      platform: platform,
      platform_version: platform_version,
      product: 'mdbe',
      version: version
    }
  end

  def self.parse_mdbe_repository(config, mdbe_private_key, deb_repo = false)
    get_mdbe_release_versions(config, mdbe_private_key).map do |version|
      config['platforms'].map do |platform_and_version|
        platform, platform_version = platform_and_version.split('_')
        generate_mdbe_release_info(config['baseurl'], config['key'], version,
                                   platform, platform_version, mdbe_private_key, deb_repo)
      end
    end.flatten
  end
end
