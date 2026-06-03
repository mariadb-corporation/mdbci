# frozen_string_literal: true

require_relative 'repository_parser_core'

# This module handles the MDBE CI repository
module MdbeCiParser
  extend RepositoryParserCore
  DEFAULT_MDBE_VERSION = '10.5'

  def self.parse(config, product_version, mdbe_ci_config, log, logger)
    return [] if mdbe_ci_config.nil?

    auth_mdbe_ci_repo = mdbe_ci_config['mdbe_ci_repo']
    auth_pergamon_repo = mdbe_ci_config['pergamon_repo']
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
                                   auth_pergamon_repo, logger))
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

  def self.parse_cs_repos(url, yum_key, auth_mdbe_ci_repo, logger)
    releases = []
    retrive_stable_branches(url, auth_mdbe_ci_repo).each do |branch_dir|
      # pp "!!!", url, branch_dir
      # pp "___"
      versions = retrive_versions(url, auth_mdbe_ci_repo, branch_dir)
      # pp "!!!", versions
      # pp "___"
      if versions.include?("latest")
        # pp 'versions.include?("latest")'
        # pp 'url, auth_mdbe_ci_repo, branch_dir', url, auth_mdbe_ci_repo, branch_dir
        retrive_latest_versions(url, auth_mdbe_ci_repo, branch_dir).each do |version|
          # pp version
          releases.concat(generate_cspkg_latest_repositories(url, branch_dir, version,
                                                            yum_key, auth_mdbe_ci_repo, logger))
        end
      end
      # pp "___"
      if versions.include?("pull_request")
        # pp 'versions.include?("pull_request")'
        # pp "url, branch_dir", url, branch_dir
        retrive_pull_request_versions(url, auth_mdbe_ci_repo, branch_dir).each do |pull_request_version|
          releases.concat(generate_cspkg_pull_request_repositories(url, branch_dir, pull_request_version,
                                                            yum_key, auth_mdbe_ci_repo, logger))
        end
      end
    end
    releases
  end

  def self.retrive_stable_branches(url, auth)
    perform_span_parsing(url, auth).filter do |release|
      release.start_with?('stable-')
    end
  end

  def self.retrive_latest_versions(url, auth, branch)
    perform_span_parsing("#{url}/#{branch}/latest/", auth)
  end

  def self.retrive_pull_request_versions(url, auth, branch)
    perform_span_parsing("#{url}/#{branch}/pull_request/", auth)
  end

  def self.retrive_versions(url, auth, branch)
    # # pp "#{url}/#{branch}/"
    perform_span_parsing("#{url}/#{branch}/", auth)
  end

  ARCHITECTURE_DIRECTORIES = {
    'amd64' => 'amd64',
    'aarch64' => 'arm64',
    'ppc64le' => 'ppc64le'
  }.freeze
  DEB_PLATFORMS = %w[debian ubuntu].freeze

  def self.generate_cspkg_latest_repositories(repo_url, branch, s3_version, yum_key, auth, logger)
     # pp "generate_cspkg_latest_repositories repo_url, branch, s3_version #{repo_url}, #{branch}, #{s3_version}"
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
                                       arch, s3_version, yum_key, auth))
      end
    end
    releases
  end

  def self.generate_cspkg_pull_request_repositories(repo_url, branch, pull_request_version, yum_key, auth, logger)
    #  # pp "generate_cspkg_pull_request_repositories repo_url, branch, pull_request_version #{repo_url}, #{branch}, #{pull_request_version}"
    releases = []
    s3_versions = perform_span_parsing("#{repo_url}/#{branch}/pull_request/#{pull_request_version}/", auth)
    # # pp "s3_versions #{s3_versions}"
    s3_versions.each do |s3_version|
      archs = retrive_archs("#{repo_url}#{branch}/pull_request/#{pull_request_version}/#{s3_version}/", auth)
      # # pp "archs #{archs}"
      archs.each do |arch|
        platforms = retrive_platforms("#{repo_url}#{branch}/pull_request/#{pull_request_version}/#{s3_version}/#{arch}/", auth)
        platforms.each do |platform|
          platform, platform_feature = platform.split('_')
          platform_info = get_mdbe_platforms[platform]
          if platform_info.nil?
            logger.write("Unknown platform #{platform}, skipped.")
            next
          end
          releases.append(form_repo_info(platform_info, repo_url, branch, platform, platform_feature,
                                        arch, s3_version, yum_key, auth))
        end
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
    retries = 0
    begin
      uri = URI(link)
      response = nil

      Net::HTTP.start(uri.host, uri.port,
                      use_ssl: uri.scheme == 'https',
                      read_timeout: 60,
                      open_timeout: 30) do |http|
        request = Net::HTTP::Get.new(uri)
        request.basic_auth(auth['username'], auth['password'])
        response = http.request(request)
      end

      doc = Nokogiri.HTML(response.body)
      doc.css('span.name').map { |document| document.text.sub('/', '') }
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET => e
      retries += 1
      if retries <= 3
        sleep(5)
        retry
      else
        puts "Failed after 3 retries: #{e.message}"
        []
      end
    end
  end

  def self.form_repo_info(platform_info, repo_url, branch, platform, platform_feature, arch, s3_version, yum_key, auth)
    url = URI(repo_url)
    repo_url = "#{url.scheme}://#{auth['username']}:#{auth['password']}@#{url.host}#{url.path}"
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
