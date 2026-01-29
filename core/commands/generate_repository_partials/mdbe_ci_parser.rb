# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MDBE CI repository
module MdbeCiParser
  extend RepositoryParserCore
  DEFAULT_MDBE_VERSION = '10.5'
  S3_VERS = ['10.6-enterprise', '11.4-enterprise', '11.8-enterprise']

  def self.parse(config, product_version, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth_mdbe_ci_repo = mdbe_ci_config['mdbe_ci_repo']
    auth_es_repo = mdbe_ci_config['es_repo']
    releases = []
    releases.concat(
      parse_mdbe_ci_rpm_repository(config['repo']['mdbe_ci_repo'], product_version,
                                   config['scan_mode'], auth_mdbe_ci_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_rpm_repository_yum(config['repo']['mdbe_ci_repo'], product_version,
                                       config['scan_mode'], auth_mdbe_ci_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_deb_repository(config['repo']['mdbe_ci_repo'], product_version,
                                   config['scan_mode'], auth_mdbe_ci_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_es_repo_rpm_repository(config['repo']['es_repo'], product_version,
                                           config['scan_mode'], auth_es_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_es_repo_deb_repository(config['repo']['es_repo'], product_version,
                                           config['scan_mode'], auth_es_repo, log, logger)
    )
    releases.concat(parse_cs_repos(config['repo']['cs_repo']['path'],
                                   config['repo']['cs_repo']['yum_key'],
                                   config['repo']['cs_repo']['latest_branches'],
                                   auth_mdbe_ci_repo, logger))
    releases.uniq! do |release|
      [release[:architecture], release[:platform], release[:platform_version], release[:product],
       release[:version]]
    end
    releases
  end

  def self.parse_mdbe_ci_rpm_repository(config, product_version, scan_mode, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mdbe_ci', product_version,
      %w[MariaDB-client MariaDB-server],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ },
      scan_mode,
      log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['key'], auth)),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)/?$}),
      append_url(%w[x86_64 aarch64 ppc64le], :architecture),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_mdbe_ci_rpm_repository_yum(config, product_version, scan_mode, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mdbe_ci', product_version,
      %w[MariaDB-client MariaDB-server],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ },
      scan_mode,
      log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['key'], auth)),
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

  def self.parse_mdbe_ci_deb_repository(config, product_version, scan_mode, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mdbe_ci', product_version,
      %w[mariadb-client mariadb-server],
      ->(url, _) { generate_mariadb_ci_deb_full_url(url, scan_mode, logger, log, auth) },
      ->(package, _) { /#{package}/ }, scan_mode, log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['key'], auth)),
      append_url(%w[apt], nil, true),
      append_url(%w[dists]),
      extract_deb_platforms,
      set_deb_architecture(auth),
      lambda do |release, _|
        repo_path = add_auth_to_url(release[:repo_url], auth)
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release
      end
    )
  end

  def self.parse_mdbe_ci_es_repo_rpm_repository(config, product_version, scan_mode, auth, log, logger)
    parse_repository_recursive(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci', product_version,
      %w[MariaDB-client MariaDB-server], ->(url, _) { url },
      ->(package, _) { /#{package}/ }, scan_mode, log, logger,
      { lambda: append_to_field(:version),
        complete_condition: dirs?(%w[apt yum bintar sourcetar DEB RPMS]) },
      { lambda: append_url(%w[RPMS]) },
      { lambda: add_platform_and_version(:rpm) },
      { lambda: lambda do |release, _|
        release[:version] = release[:version].join('/')
        release[:repo] = add_auth_to_url(release[:url], auth)
        release[:disable_gpgcheck] = true
        release
      end }
    )
  end

  def self.parse_mdbe_ci_es_repo_deb_repository(config, product_version, scan_mode, auth, log, logger)
    parse_repository_recursive(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci', product_version,
      %w[mariadb-client mariadb-server],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ }, scan_mode, log, logger,
      { lambda: append_to_field(:version),
        complete_condition: dirs?(%w[apt yum bintar sourcetar DEB RPMS]) },
      { lambda: append_url(%w[DEB]) },
      { lambda: add_platform_and_version(:deb) },
      { lambda: lambda do |release, _|
        release[:version] = release[:version].join('/')
        release[:repo] = generate_deb_path(release[:url], auth)
        release[:disable_gpgcheck] = true
        release
      end }
    )
  end

  def self.generate_deb_path(path, auth)
    split_path = path.split('/')
    platform_and_version = split_path.pop
    full_url = split_path.join('/')
    "#{add_auth_to_url(full_url, auth)}/ #{platform_and_version}/"
  end

  def self.parse_cs_repos(url, yum_key, latest_branches, auth_mdbe_ci_repo, logger)
    releases = []
    latest_branches.each do |branch_dir|
      S3_VERS.each do |version|
        releases.concat(generate_cspkg_latest_repositories(url, branch_dir, version,
                                                           yum_key, auth_mdbe_ci_repo, logger))
      end
    end
    releases
  end

  ARCHITECTURE_DIRECTORIES = {
    'amd64' => 'amd64',
    'aarch64' => 'arm64',
    'ppc64le' => 'ppc64le'
  }.freeze
  DEB_PLATFORMS = %w[debian ubuntu].freeze

  def self.generate_cspkg_latest_repositories(repo_url, branch, s3_version, yum_key, auth, logger)
    releases = []
    archs = retrive_archs("#{repo_url}#{branch}/latest/#{s3_version}/", auth)
    archs.each do |arch|
      platforms = retrive_platforms("#{repo_url}#{branch}/latest/#{s3_version}/#{arch}/", auth)
      platforms.each do |platform|
        platform, platform_feature = platform.split('_')
        platform_info = get_mdbe_platforms[platform]
        if platform_info.nil?
          logger.write("Unknown platform #{platform}, skipped.")
          next
        end
        releases.append(form_repo_info(platform_info, repo_url, branch, platform, platform_feature,
                                       arch, s3_version, yum_key))
      end
    end
    releases
  end

  def self.retrive_archs(link, auth)
    perform_span_parsing(link, auth)
  end

  def self.retrive_platforms(link, auth)
    perform_span_parsing(link, auth)
  end

  def self.perform_span_parsing(link, auth)
    doc = Nokogiri.HTML(URI.open(link,
                                 http_basic_authentication: [auth['username'],
                                                             auth['password']]))
    doc.css('span.name').map { |document| document.text.sub('/', '') }
  end

  def self.form_repo_info(platform_info, repo_url, branch, platform, platform_feature, arch, s3_version, yum_key)
    base_repo_link = "#{repo_url}#{branch}/latest/#{s3_version}/#{arch}"
    repo = if DEB_PLATFORMS.include?(platform_info[:platform])
             "#{base_repo_link}/ #{platform}/"
           else
             "#{base_repo_link}/#{platform}/"
           end
    platform_feature = "-#{platform_feature}" if platform_feature
    platform_info.merge({
                          repo: repo,
                          version: "columnstore/#{branch}/latest#{platform_feature}/#{s3_version}",
                          product: 'mdbe_ci',
                          architecture: arch,
                          repo_key: yum_key,
                          disable_gpgcheck: true
                        })
  end
end
