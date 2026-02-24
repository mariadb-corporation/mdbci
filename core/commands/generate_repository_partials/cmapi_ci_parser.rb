require_relative 'repository_parser_core'

# This module handles the Cmapi CI repository
module CmapiCiParser
  extend RepositoryParserCore

  def self.parse(config, product_version, mdbe_ci_config, cmapi_ci_product, log, logger)
    return [] if mdbe_ci_config.nil?

    auth = mdbe_ci_config['mdbe_ci_repo']
    releases = []
    releases.concat(parse_cmapi_ci_rpm_repository(config['repo'], product_version, auth,
                                                  cmapi_ci_product, log, logger))
    releases.concat(parse_cmapi_ci_deb_repository(config['repo'], product_version, auth,
                                                  cmapi_ci_product, log, logger))
    releases.uniq! do |release|
      [release[:architecture], release[:platform], release[:platform_version], release[:product],
       release[:version]]
    end
    releases
  end

  def self.parse_cmapi_ci_rpm_repository(config, product_version, auth, cmapi_ci_product, log, logger)
    parse_repository(
      config['path'], auth, nil, cmapi_ci_product, product_version,
      %w[MariaDB-columnstore-cmapi],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ }, nil, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['new_key'], auth)),
      append_url(%w[yum]),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)/?$}),
      append_url(%w[x86_64 aarch64 ppc64le], :architecture),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_cmapi_ci_deb_repository(config, product_version, auth, cmapi_ci_product, log, logger)
    cmapi_ci_release = 'mariadb-columnstore-cmapi'
    parse_repository(
      config['path'], auth, nil, cmapi_ci_product, product_version,
      [cmapi_ci_release],
      ->(url, _) { generate_cmapi_ci_deb_full_url(url, cmapi_ci_release) },
      ->(package, platform) { /#{package}.*#{platform_to_repo_name(platform)}/ }, nil, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['new_key'], auth)),
      append_url(%w[apt], nil, true),
      append_url(%w[dists]),
      extract_deb_platforms,
      set_deb_architecture(auth),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:repo_url], auth)
        release[:components] = ['main']
        release
      end
    )
  end

  def self.generate_cmapi_ci_deb_full_url(incorrect_url, release)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')
    "#{url}/pool/main/m/#{release}/"
  end
end
