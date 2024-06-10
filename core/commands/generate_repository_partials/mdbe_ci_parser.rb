# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MDBE CI repository
module MdbeCiParser
  extend RepositoryParserCore
  DEFAULT_MDBE_VERSION = '10.5'

  def self.parse(config, product_version, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth_mdbe_ci_repo = mdbe_ci_config['mdbe_ci_repo']
    auth_es_repo = mdbe_ci_config['es_repo']
    releases = []
    releases.concat(
      parse_mdbe_ci_rpm_repository(config['repo']['mdbe_ci_repo'], product_version,
                                   auth_mdbe_ci_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_deb_repository(config['repo']['mdbe_ci_repo'], product_version,
                                   auth_mdbe_ci_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_es_repo_rpm_repository(config['repo']['es_repo'], product_version,
                                           auth_es_repo, log, logger)
    )
    releases.concat(
      parse_mdbe_ci_es_repo_deb_repository(config['repo']['es_repo'], product_version,
                                           auth_es_repo, log, logger)
    )
    releases.concat(parse_cs_repos(config['repo']['cs_repo']['path'],
                                   config['repo']['cs_repo']['yum_key'],
                                   config['repo']['cs_repo']['branches'],
                                   config['repo']['cs_repo']['latest_branches'],
                                   ))

    releases
  end

  def self.parse_mdbe_ci_rpm_repository(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mdbe_ci', product_version,
      %w[MariaDB-client MariaDB-server],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      save_as_field(:version),
      save_key(logger, auth, add_auth_to_url(config['key'], auth)),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)/?$}),
      append_url(%w[x86_64 aarch64], :architecture),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def self.parse_mdbe_ci_deb_repository(config, product_version, auth, log, logger)
    parse_repository(
      config['path'], auth, nil, 'mdbe_ci', product_version,
      %w[mariadb-client mariadb-server],
      ->(url, _) { generate_mariadb_ci_deb_full_url(url, logger, log, auth) },
      ->(package, _) { /#{package}/ }, log, logger,
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

  def self.parse_mdbe_ci_es_repo_rpm_repository(config, product_version, auth, log, logger)
    parse_repository_recursive(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci', product_version,
      %w[MariaDB-client MariaDB-server], ->(url, _) { url },
      ->(package, _) { /#{package}/ }, log, logger,
      { lambda: append_to_field(:version),
        complete_condition: dirs?(%w[apt yum bintar sourcetar DEB RPMS]) },
      { lambda: append_url(%w[RPMS]) },
      { lambda: add_platform_and_version(:rpm) },
      { lambda: lambda do |release, _|
        release[:version] = release[:version].join('/')
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end }
    )
  end

  def self.parse_mdbe_ci_es_repo_deb_repository(config, product_version, auth, log, logger)
    parse_repository_recursive(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci', product_version,
      %w[mariadb-client mariadb-server],
      ->(url, _) { url },
      ->(package, _) { /#{package}/ }, log, logger,
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


  def self.parse_cs_repos(url, yum_key, branches, latest_branches)
    releases = []
    branches.each do |branch_dir|
      releases.concat(parse_s3_dirs(url, yum_key, branch_dir, '10.6-enterprise'))
    end
    latest_branches.each do |branch_dir|
      releases.concat(parse_s3_latest(url, yum_key, branch_dir, '10.6-enterprise'))
    end
    releases
  end

  def self.parse_s3_latest(repo_url, yum_key, branch, repo_product_ver)
    releases = []
    platforms = get_mdbe_platforms
    platforms.keys.map do |platform|
      releases << (platforms[platform].merge({
                                                repo: "#{repo_url}#{branch}/latest/#{repo_product_ver}/amd64/#{platform}/",
                                                version: "columnstore/#{branch}/latest/#{repo_product_ver}",
                                                product: 'mdbe_ci',
                                                architecture: 'amd64',
                                                repo_key: yum_key,
                                                disable_gpgcheck: true
                                            }))
      releases << (platforms[platform].merge({
                                                repo: "#{repo_url}#{branch}/latest/#{repo_product_ver}/arm64/#{platform}/",
                                                version: "columnstore/#{branch}/latest/#{repo_product_ver}",
                                                product: 'mdbe_ci',
                                                architecture: 'aarch64',
                                                repo_key: yum_key,
                                                disable_gpgcheck: true
                                            }))
    end
    releases
  end

  def self.parse_s3_dirs(repo_url, yum_key, branch_dir, repo_product_ver)
    links = []
    platforms = get_mdbe_platforms
    full_url = "#{repo_url}?prefix=#{branch_dir}/&delimiter=/"
    doc = Nokogiri.XML(URI.open(full_url))
    doc_array = doc.at_css("ListBucketResult").children
    elements = doc_array.count
    doc_array.each do |file|
      file_link = file.to_s.match(/<Prefix>.*<\/Prefix>/).to_s[8..-10]
      links.append(file_link)
    end
    
    links.compact!
    links.map! { |link| link.match(/(?<=(#{branch_dir})\/)[0-9]+/).to_s }
    links = links.reject { |element| element.empty? }

    releases = []

    links.each do |link|
      platforms.keys.map do |platform|
        releases << (platforms[platform].merge({
                                                  repo: "#{repo_url}#{branch_dir}/#{link}/#{repo_product_ver}/amd64/#{platform}/",
                                                  version: "columnstore/#{branch_dir}/#{link}/#{repo_product_ver}",
                                                  product: 'mdbe_ci',
                                                  architecture: 'amd64',
                                                  repo_key: yum_key,
                                                  disable_gpgcheck: true
                                              }))
        releases << (platforms[platform].merge({
                                                  repo: "#{repo_url}#{branch_dir}/#{link}/#{repo_product_ver}/arm64/#{platform}/",
                                                  version: "columnstore/#{branch_dir}/#{link}/#{repo_product_ver}",
                                                  product: 'mdbe_ci',
                                                  architecture: 'aarch64',
                                                  repo_key: yum_key,
                                                  disable_gpgcheck: true
                                              }))
      end
    end
    releases
  end
end

