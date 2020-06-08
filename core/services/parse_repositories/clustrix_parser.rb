# frozen_string_literal: true

# This module handles the Clusrtix repository
module ClustrixParser
  def self.parse(config)
    config['platforms'].map do |platform|
      config['versions'].map do |version|
        path = config['path'].sub('$VERSION$', version)
        generate_clustrix_release_info(path, version, platform)
      end
    end.flatten
  end

  def self.generate_clustrix_release_info(path, version, platform_with_version)
    platform, platform_version = platform_with_version.split('_')
    {
      repo: path,
      repo_key: nil,
      platform: platform,
      platform_version: platform_version,
      product: 'clustrix',
      version: version
    }
  end
end
