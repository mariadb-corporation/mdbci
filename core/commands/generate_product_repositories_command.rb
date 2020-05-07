# frozen_string_literal: true

require 'open-uri'
require 'uri'
require 'optparse'
require 'nokogiri'
require 'pp'
require 'json'
require 'fileutils'
require 'logger'
require 'workers'

require_relative 'base_command'

# The command generates the repository configuration
# rubocop:disable Metrics/ClassLength
class GenerateProductRepositoriesCommand < BaseCommand
  CONFIGURATION_FILE = 'generate_repository_config.yaml'
  PRODUCTS_DIR_NAMES = {
    'columnstore' => 'columnstore',
    'mariadb' => 'mariadb',
    'maxscale_ci' => 'maxscale_ci',
    'maxscale' => 'maxscale',
    'mdbe' => 'mdbe',
    'mysql' => 'mysql',
    'maxscale_ci_docker' => 'maxscale_ci_docker',
    'clustrix' => 'clustrix',
    'mdbe_ci' => 'mdbe_ci',
    'galera_enterprise_ci' => 'galera_enterprise_ci'
  }.freeze
  COMMAND_NAME = 'generate-product-repositories'

  def self.synopsis
    'Generate product repository configuration for all known products'
  end

  # rubocop:disable Metrics/MethodLength
  def show_help
    info = <<-HELP

'#{COMMAND_NAME} [REPOSITORY PATH]' creates product repository configuration.

Supported options:

--configuration-file path to the configuration file to use during generation. Optional.
--product name of the product to generate repository configuration for. Optional.
--product-version version of the product to generate configuration for.
--attempts number of attempts to try to get data from the remote repository. Default is 3 attempts.

In order to generate repo.d for all products using the default configuration.

  mdbci #{COMMAND_NAME}

You can create custom configuration file and use it during the repository creation:

  mdbci #{COMMAND_NAME} --configuration-file ~/mdbci/config/generate_repository_config.yaml

In order to specify the target directory pass it as the first parameter to the script.

  mdbci #{COMMAND_NAME} ~/mdbci/repo.d

In orded to generate configuration for a specific product use --product option.

  mdbci #{COMMAND_NAME} --product mdbe

MDBCI currently supports the following products: #{PRODUCTS_DIR_NAMES.keys.sort.join(', ')}

In order to generate configuration for a specific product version use --product-version option. You must also specify the name of the product to generate configuration for.

  mdbci #{COMMAND_NAME} --product maxscale_ci --product-version develop

In order to specify the number of retries for repository configuration use --attempts option.

  mdbci generate-product-repositories --product columnstore --attempts 5
    HELP
    @ui.out(info)
  end
  # rubocop:enable Metrics/MethodLength

  def initialize(args, env, default_logger)
    super(args, env, default_logger)
    path = @env.data_path('generate_product_repository.log')
    @ui.info("Writing log file to #{path}")
    @logger = Logger.new(File.new(path, 'w'), 'weekly')
  end

  # Send info message to both user output and logger facility
  def info_and_log(message)
    @ui.info(message)
    @logger.info(message)
  end

  # Send error message to both direct output and logger facility
  def error_and_log(message)
    @ui.error(message)
    @logger.error(message)
  end

  # Send iformation about the error to the error stream
  def error_and_log_error(error)
    error_and_log(error.message)
    error_and_log(error.backtrace.reverse.join("\n"))
  end

  def load_configuration_file
    config_path = @env.configuration_file || @env.find_configuration(CONFIGURATION_FILE)
    unless File.exist?(config_path)
      error_and_log("Unable to find configuration file: '#{config_path}'.")
      return false
    end
    info_and_log("Configuring repositories using configuration: '#{config_path}'.")
    @config = YAML.safe_load(File.read(config_path))
  end

  def determine_products_to_parse
    if @env.nodeProduct
      unless PRODUCTS_DIR_NAMES.key?(@env.nodeProduct)
        error_and_log("Unknown product #{@env.nodeProduct}.\n"\
                      "Known products: #{PRODUCTS_DIR_NAMES.keys.join(', ')}")
        return false
      end
      @products = [@env.nodeProduct]
    else
      @products = PRODUCTS_DIR_NAMES.keys
    end
    info_and_log("Configuring repositories for products: #{@products.join(', ')}.")
    true
  end

  def determine_product_version_to_parse
    if @env.productVersion
      unless @env.nodeProduct
        error_and_log('When specifying product version you must also specify the product.')
        return false
      end
      @product_version = @env.productVersion
    end
    true
  end

  def determine_number_of_attempts
    @attempts = if @env.attempts
                  @env.attempts.to_i
                else
                  3
                end
    info_and_log("The configuration will be attempted #{@attempts} times.")
  end

  def setup_destination_directory
    @destination = if @args.empty?
                     @env.configuration_path('repo.d')
                   else
                     @args.first
                   end
    info_and_log("Repository configuration will be written to '#{@destination}'.")
  end

  # Use data provided via constructor to configure the command.
  def configure_command
    load_configuration_file
    return false unless determine_products_to_parse
    return false unless determine_product_version_to_parse

    determine_number_of_attempts
    setup_destination_directory
    Workers.pool.resize(10)
    true
  end

  # Get links list on the page
  # @param url [String] path to the site to be checked
  # @param auth [Hash] basic auth data in format { username, password }
  # @return [Array] possible link locations
  def get_links(url, auth = nil)
    uri = url.gsub(%r{([^:])\/+}, '\1/')
    @logger.info("Loading URLs '#{uri}'")
    options = {}
    options[:http_basic_authentication] = [auth['username'], auth['password']] unless auth.nil?
    doc = Nokogiri::HTML(URI.open(uri, options).read)
    doc.css('a')
  end

  # Links that look like directories from the list of all links
  # @param url [String] path to the site to be checked
  # @param auth [Hash] basic auth data in format { username, password }
  # @return [Array] possible link locations
  def get_directory_links(url, auth = nil)
    get_links(url, auth).select { |link| dir_link?(link) && !parent_dir_link?(link) }
  end

  # Check that passed link is possibly a directory or not
  # @param link link to check
  # @return [Boolean] whether link is directory or not
  def dir_link?(link)
    link.content.match?(%r{\/$}) ||
      link[:href].match?(%r{^(?!((http|https):\/\/|\.{2}|\/|\?)).*\/$})
  end

  # Check that passed link is possibly a parent directory link or not
  # @param link link to check
  # @return [Boolean] whether link is parent directory link or not
  def parent_dir_link?(link)
    link[:href] == '../'
  end

  def parse_maxscale_ci(config)
    releases = []
    releases.concat(parse_maxscale_ci_rpm_repository(config['repo']['rpm']))
    releases.concat(parse_maxscale_ci_deb_repository(config['repo']['deb']))
    releases
  end

  def parse_maxscale_ci_rpm_repository(config)
    parse_repository(
      config['path'], nil, config['key'], 'maxscale_ci',
      save_as_field(:version),
      append_url(%w[mariadb-maxscale]),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def parse_maxscale_ci_deb_repository(config)
    parse_repository(
      config['path'], nil, config['key'], 'maxscale_ci',
      save_as_field(:version),
      append_url(%w[mariadb-maxscale]),
      append_url(%w[debian ubuntu], :platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        release[:repo] = "#{release[:repo_url]} #{release[:platform_version]} main"
        release
      end
    )
  end

  def parse_maxscale_ci_docker(_)
    releases = []
    releases.concat(parse_maxscale_ci_repository_for_docker)
    releases
  end

  def get_maxscale_ci_release_version_for_docker(base_url, username, password)
    uri_with_tags = URI.join(base_url, '/v2/mariadb/maxscale-ci/tags/list')
    begin
      doc_tags = JSON.parse(URI.open(uri_with_tags,
                                     http_basic_authentication: [username, password]).read)
      doc_tags.dig('tags')
    rescue OpenURI::HTTPError => e
      @ui.error("Failed to get tags for docker from #{uri_with_tags}: #{e}")
      ERROR_RESULT
    rescue StandardError
      @ui.error('Failed to get tags for docker')
      ERROR_RESULT
    end
  end

  # Generate information about releases
  def generate_maxscale_ci_releases_for_docker(base_url, tags)
    server_info = URI.parse(base_url)
    package_path = "#{server_info.host}:#{server_info.port}/mariadb/maxscale-ci"
    result = []
    tags.each do |tag|
      result << {
        platform: 'docker',
        repo_key: '',
        platform_version: 'latest',
        product: 'maxscale_ci',
        version: tag,
        repo: "#{package_path}:#{tag}"
      }
    end
    result
  end

  def parse_maxscale_ci_repository_for_docker
    config = @env.tool_config
    base_url = config.dig('docker', 'ci-server').to_s
    username = config.dig('docker', 'username').to_s
    password = config.dig('docker', 'password').to_s

    tags = get_maxscale_ci_release_version_for_docker(base_url, username, password)
    return [] if tags == ERROR_RESULT

    generate_maxscale_ci_releases_for_docker(base_url, tags)
  end

  def parse_maxscale(config)
    releases = []
    releases.concat(parse_maxscale_rpm_repository(config['repo']['rpm']))
    releases.concat(parse_maxscale_deb_repository(config['repo']['deb']))
    releases
  end

  def parse_maxscale_rpm_repository(config)
    parse_repository(
      config['path'], nil, config['key'], 'maxscale',
      save_as_field(:version),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def parse_maxscale_deb_repository(config)
    parse_repository(
      config['path'], nil, config['key'], 'maxscale',
      save_as_field(:version),
      append_url(%w[debian ubuntu], :platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        release[:repo] = "#{release[:repo_url]} #{release[:platform_version]} main"
        release
      end
    )
  end

  def parse_mdbe(config)
    releases = []
    releases.concat(parse_mdbe_repository(config['repo']['rpm']))
    releases.concat(parse_mdbe_repository(config['repo']['deb'], true))
    releases
  end

  def replace_template_by_mdbe_private_key(path)
    return path if @env.mdbe_private_key.nil?

    path.sub('$PRIVATE_KEY$', @env.mdbe_private_key)
  end

  MDBE_PLATFORMS = {
    'centos' => 'rhel',
    'rhel' => 'rhel',
    'sles' => 'sles'
  }.freeze
  def generate_mdbe_repo_path(path, version, platform, platform_version)
    replace_template_by_mdbe_private_key(path)
      .sub('$MDBE_VERSION$', version)
      .sub('$PLATFORM$', MDBE_PLATFORMS[platform] || '')
      .sub('$PLATFORM_VERSION$', platform_version)
  end

  def mdbe_release_link?(link)
    link.content =~ /^MariaDB Enterprise Server [0-9]*\.?.*$/
  end

  def get_mdbe_release_links(path)
    uri = path.gsub(%r{([^:])\/+}, '\1/')
    doc = Nokogiri::HTML(URI.open(uri))
    all_links = doc.css('ul:not(.nav) a')
    all_links.select do |link|
      mdbe_release_link?(link)
    end
  end

  def get_mdbe_release_versions(config)
    path = replace_template_by_mdbe_private_key(config['path'])
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

  # rubocop:disable Metrics/ParameterLists
  def generate_mdbe_release_info(baseurl, key, version, platform,
                                 platform_version, deb_repo = false)
    repo_path = generate_mdbe_repo_path(baseurl, version, platform, platform_version)
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
  # rubocop:enable Metrics/ParameterLists

  def parse_mdbe_repository(config, deb_repo = false)
    get_mdbe_release_versions(config).map do |version|
      config['platforms'].map do |platform_and_version|
        platform, platform_version = platform_and_version.split('_')
        generate_mdbe_release_info(config['baseurl'], config['key'], version,
                                   platform, platform_version, deb_repo)
      end
    end.flatten
  end

  def parse_mariadb(config)
    releases = []
    version_regexp = %r{^(\p{Digit}+\.\p{Digit}+(\.\p{Digit}+)?)\/?$}
    releases.concat(parse_mariadb_rpm_repository(config['repo']['rpm'], 'mariadb', version_regexp))
    releases.concat(parse_mariadb_deb_repository(config['repo']['deb'], 'mariadb', version_regexp))
    releases
  end

  def parse_mariadb_rpm_repository(config, product, version_regexp)
    parse_repository(
      config['path'], nil, config['key'], product,
      extract_field(:version, version_regexp),
      append_url(%w[centos rhel sles opensuse], :platform),
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def parse_mariadb_deb_repository(config, product, version_regexp)
    parse_repository(
      config['path'], nil, config['key'], product,
      extract_field(:version, version_regexp),
      save_as_field(:platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        release[:repo] = "#{release[:repo_url]} #{release[:platform_version]} main"
        release
      end
    )
  end

  def parse_columnstore(config)
    releases = []
    releases.concat(parse_columnstore_rpm_repository(config['repo']['rpm']))
    releases.concat(parse_columnstore_deb_repository(config['repo']['deb']))
    releases
  end

  def parse_columnstore_rpm_repository(config)
    parse_repository(
      config['path'], nil, config['key'], 'columnstore',
      save_as_field(:version),
      append_url(%w[yum]),
      split_rpm_platforms,
      save_as_field(:platform_version),
      append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def parse_columnstore_deb_repository(config)
    parse_repository(
      config['path'], nil, config['key'], 'columnstore',
      save_as_field(:version),
      append_url(%w[repo]),
      extract_field(:platform, %r{^(\p{Alpha}+)\p{Digit}+\/?$}, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      lambda do |release, _|
        release[:repo] = release[:repo_url]
        release
      end
    )
  end

  def parse_mysql(config)
    releases = []
    releases.concat(parse_mysql_rpm_repository(config['repo']['rpm']))
    releases.concat(parse_mysql_deb_repository(config['repo']['deb']))
    releases
  end

  def parse_mysql_deb_repository(config)
    parse_repository(
      config['path'], nil, config['key'], 'mysql',
      append_url(%w[debian ubuntu], :platform, true),
      append_url(%w[dists]),
      save_as_field(:platform_version),
      extract_field(:version, %r{^mysql-(\d+\.?\d+(-[^\/]*)?)(\/?)$}),
      lambda do |release, _|
        release[:repo] = "deb #{release[:repo_url]} #{release[:platform_version]}"\
                         " mysql-#{release[:version]}"
        release
      end
    )
  end

  # Method parses MySQL repositories that correspond to the following scheme:
  # http://repo.mysql.com/yum/mysql-8.0-community/el/7/x86_64/
  def parse_mysql_rpm_repository(config)
    parse_repository(
      config['path'], nil, config['key'], 'mysql',
      extract_field(:version, %r{^mysql-(\d+\.?\d+)-community(\/?)$}),
      split_rpm_platforms,
      save_as_field(:platform_version),
      append_url(%w[x86_64], :repo),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def generate_clustrix_release_info(path, version, platform_with_version)
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

  def parse_clustrix(config)
    config['platforms'].map do |platform|
      config['versions'].map do |version|
        path = config['path'].sub('$VERSION$', version)
        generate_clustrix_release_info(path, version, platform)
      end
    end.flatten
  end

  def parse_mdbe_ci(config)
    return [] if @env.mdbe_ci_config.nil?

    auth_mdbe_ci_repo = @env.mdbe_ci_config['mdbe_ci_repo']
    auth_es_repo = @env.mdbe_ci_config['es_repo']
    releases = []
    releases.concat(parse_mdbe_ci_rpm_repository(config['repo']['mdbe_ci_repo'], auth_mdbe_ci_repo))
    releases.concat(parse_mdbe_ci_deb_repository(config['repo']['mdbe_ci_repo'], auth_mdbe_ci_repo))
    releases.concat(parse_mdbe_ci_es_repo_rpm_repository(config['repo']['es_repo'], auth_es_repo))
    releases.concat(parse_mdbe_ci_es_repo_deb_repository(config['repo']['es_repo'], auth_es_repo))
    releases
  end

  def parse_mdbe_ci_rpm_repository(config, auth)
    parse_repository(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci',
      save_as_field(:version),
      append_url(%w[yum]),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end
    )
  end

  def parse_mdbe_ci_deb_repository(config, auth)
    parse_repository(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci',
      save_as_field(:version),
      append_url(%w[apt], nil, true),
      append_url(%w[dists]),
      extract_deb_platforms,
      lambda do |release, _|
        repo_path = add_auth_to_url(release[:repo_url], auth)
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release
      end
    )
  end

  def parse_mdbe_ci_es_repo_rpm_repository(config, auth)
    parse_repository_recursive(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci',
      { lambda: append_to_field(:version),
        complete_condition: has_dirs?(%w[apt yum bintar sourcetar]) },
      { lambda: append_url(%w[yum]) },
      { lambda: split_rpm_platforms },
      { lambda: extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}) },
      { lambda: lambda do |release, _|
        release[:version] = release[:version].join('/')
        release[:repo] = add_auth_to_url(release[:url], auth)
        release
      end }
    )
  end

  def parse_mdbe_ci_es_repo_deb_repository(config, auth)
    parse_repository_recursive(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'mdbe_ci',
      { lambda: append_to_field(:version),
        complete_condition: has_dirs?(%w[apt yum bintar sourcetar]) },
      { lambda: append_url(%w[apt], nil, true) },
      { lambda: append_url(%w[dists]) },
      { lambda: extract_deb_platforms },
      { lambda: lambda do |release, _|
        repo_path = add_auth_to_url(release[:repo_url], auth)
        release[:version] = release[:version].join('/')
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release
      end }
    )
  end

  def parse_galera_enterprise_ci(config)
    raise 'Product mdbe_ci is not configured' if @env.mdbe_ci_config.nil?

    auth = @env.mdbe_ci_config['mdbe_ci_repo']
    releases = []
    releases.concat(parse_galera_enterprise_ci_rpm_repository(config['repo']['rpm'], auth))
    releases.concat(parse_galera_enterprise_ci_deb_repository(config['repo']['deb'], auth))
    releases
  end

  def add_auth_to_url(url, auth)
    url.dup.insert(url.index('://') + 3, "#{auth['username']}:#{auth['password']}@")
  end

  def parse_galera_enterprise_ci_rpm_repository(config, auth)
    parse_repository(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'galera_enterprise_ci',
      save_as_field(:version),
      save_url_to_field(:release_root),
      append_url(%w[yum]),
      split_rpm_platforms,
      extract_field(:platform_version, %r{^(\p{Digit}+)\/?$}),
      lambda do |release, _|
        release[:repo] = add_auth_to_url(release[:url], auth)
        release[:has_packages] = check_packages_in_dir(
          "#{release[:release_root]}/packages/#{release[:platform]}/#{release[:platform_version]}/",
          auth
        )
        release
      end
    ).select { |release| release[:has_packages] }
  end

  def parse_galera_enterprise_ci_deb_repository(config, auth)
    parse_repository(
      config['path'], auth, add_auth_to_url(config['key'], auth), 'galera_enterprise_ci',
      save_as_field(:version),
      save_url_to_field(:release_root),
      append_url(%w[apt], nil, true),
      append_url(%w[dists]),
      extract_deb_platforms,
      lambda do |release, _|
        repo_path = add_auth_to_url(release[:repo_url], auth)
        release[:repo] = "#{repo_path} #{release[:platform_version]} main"
        release[:has_packages] = check_packages_in_dir(
          "#{release[:release_root]}/packages/#{release[:platform]}/#{release[:platform_version]}/",
          auth
        )
        release
      end
    ).select { |release| release[:has_packages] }
  end

  def check_packages_in_dir(url, auth)
    begin
      links = get_links(url, auth)
    rescue StandardError => e
      error_and_log("Unable to get information from link '#{url}', message: '#{e.message}'")
      return false
    end
    links.map { |link| link.content.delete('/') }.any? { |link| link =~ /.+(.rpm|.deb)$/ }
  end

  STORED_KEYS = %i[repo repo_key platform platform_version product version].freeze
  # Extract only required fields from the passed release before writing it to the file
  def extract_release_fields(release)
    STORED_KEYS.each_with_object({}) do |key, sliced_hash|
      unless release.key?(key)
        raise "Unable to find key #{key} in repository_configuration #{release}."
      end

      sliced_hash[key] = release[key]
    end
  end

  # Method filters releases, removing empty ones and by version, if it required
  def filter_releases(releases)
    next_releases = releases.reject(&:nil?)
    next_releases.select do |release|
      if @product_version.nil? || release[:version].nil?
        true
      else
        release[:version] == @product_version
      end
    end
  end

  # Parse the repository and provide required configurations
  def parse_repository(base_url, auth, key, product, *steps)
    # Recursively go through the site and apply steps on each level
    result = steps.reduce([{ url: base_url }]) do |releases, step|
      next_releases = Workers.map(releases) do |release|
        begin
          links = get_directory_links(release[:url], auth)
        rescue StandardError => e
          error_and_log("Unable to get information from link '#{release[:url]}',"\
                        " message: '#{e.message}'")
          next
        end
        apply_step_to_links(step, links, release)
      end
      filter_releases(next_releases.flatten)
    end
    add_key_and_product_to_releases(result, key, product)
  end

  # Parse the repository and provide required configurations
  # @param [Array] steps - array of Hash in format { lambda, complete_condition }
  def parse_repository_recursive(base_url, auth, key, product, *steps)
    # Recursively go through the site and apply steps on each level
    result = steps.reduce([{ url: base_url }]) do |input_releases, step|
      completed_releases = []
      processed_releases = input_releases
      # Traversing directories in depth as part of a single step.
      # 25 - maximum depth to avoid looping
      25.times do
        next_releases = Workers.map(processed_releases) do |release|
          begin
            links = get_directory_links(release[:url], auth)
          rescue StandardError => e
            error_and_log("Unable to get information from link '#{release[:url]}',"\
                          " message: '#{e.message}'")
            next
          end
          release[:continue_step] = !step[:complete_condition].nil? &&
                                    !step[:complete_condition].call(links)
          if step[:complete_condition].nil? || release[:continue_step]
            apply_step_to_links(step[:lambda], links, release)
          else
            [release]
          end
        end
        next_releases = filter_releases(next_releases.flatten)
        completed_releases += next_releases.select { |release| release[:continue_step] == false }
        processed_releases = next_releases - completed_releases
        break if processed_releases.empty?
      end
      completed_releases
    end
    add_key_and_product_to_releases(result, key, product)
  end

  # Append key and product to the releases
  # @param releases [Array<Hash>] list of releases
  # @param key [String] text to put into key field
  # @param product [String] name of the product
  def add_key_and_product_to_releases(releases, key, product)
    releases.each do |release|
      release[:repo_key] = key
      release[:product] = product
    end
  end

  # Helper method that applies the specified step to the current release
  # @param step [Lambda] the executable lambda that should be applied here
  # @param links [Array] the list of elements got from the page
  # @param release [Hash] information about the release collected so far
  def apply_step_to_links(step, links, release)
    # Delegate creation of next releases to the lambda
    next_releases = step.call(release, links)
    next_releases = [next_releases] unless next_releases.is_a?(Array)
    # Merge processing results into a new array
    next_releases.map do |next_release|
      result = release.merge(next_release)
      if result.key?(:link)
        result[:url] = "#{release[:url]}#{next_release[:link][:href]}"
        result.delete(:link)
      end
      result[:url] += '/' unless result[:url].end_with?('/')
      result
    end
  end

  # Filter all links via regular expressions and then place captured first element as version
  # @param field [Symbol] name of the field to write result to
  # @param rexexp [RegExp] expression that should have first group designated to field extraction
  # @param save_path [Boolean] whether to save current path to the release or not
  def extract_field(field, regexp, save_path = false)
    lambda do |release, links|
      possible_releases = links.select do |link|
        link.content =~ regexp
      end
      possible_releases.map do |link|
        result = {
          link: link,
          field => link.content.match(regexp).captures.first
        }
        result[:repo_url] = "#{release[:url]}#{link[:href]}" if save_path
        result
      end
    end
  end

  def has_dirs?(dirs)
    lambda do |links|
      repo_dirs = links.map { |link| link.content.delete('/').strip.chomp }
      (repo_dirs & dirs).any?
    end
  end

  DEB_PLATFORMS = {
    'bionic' => 'ubuntu',
    'buster' => 'debian',
    'focal' => 'ubuntu',
    'jessie' => 'debian',
    'stretch' => 'debian',
    'xenial' => 'ubuntu'
  }.freeze
  def extract_deb_platforms
    lambda do |release, links|
      links.map do |link|
        link.content.delete('/')
      end.select do |link|
        DEB_PLATFORMS.keys.any? { |platform| link.start_with?(platform) }
      end.map do |link|
        { url: "#{release[:url]}#{link}/",
          platform: DEB_PLATFORMS[link],
          platform_version: link }
      end
    end
  end

  RPM_PLATFORMS = {
    'el' => %w[centos rhel],
    'sles' => %w[sles],
    'centos' => %w[centos],
    'rhel' => %w[rhel],
    'opensuse' => %w[opensuse]
  }.freeze
  def split_rpm_platforms
    lambda do |release, links|
      link_names = links.map { |link| link.content.delete('/') }
      releases = []
      RPM_PLATFORMS.each_pair do |keyword, platforms|
        next unless link_names.include?(keyword)

        platforms.each do |platform|
          releases << {
            url: "#{release[:url]}#{keyword}/",
            platform: platform
          }
        end
      end
      releases
    end
  end

  # Save all values that present in current level as field contents
  # @param field [Symbol] field to save data to
  # @param save_path [Boolean] whether to save path to :repo_url field or not
  def save_as_field(field, save_path = false)
    lambda do |release, links|
      links.map do |link|
        result = {
          link: link,
          field => link.content.delete('/')
        }
        result[:repo_url] = "#{release[:url]}#{link[:href]}" if save_path
        result
      end
    end
  end

  # Append all values that present in current level to fields
  # @param field [Symbol] field to save data to
  def append_to_field(field)
    lambda do |release, links|
      links.map do |link|
        release.clone.merge({ link: link,
                              field => release.fetch(field, []) + [link.content.delete('/')] })
      end
    end
  end

  # Append URL to the current search path, possibly saving it to the key
  # and saving it to repo_url for future use
  # @param paths [Array<String>] array of paths that should be checked for presence
  # @param key [Symbol] field to save data to
  # @param save_path [Boolean] whether to save path to :repo_url field or not
  def append_url(paths, key = nil, save_path = false)
    lambda do |release, links|
      link_names = links.map { |link| link.content.delete('/') }
      repositories = []
      paths.each do |path|
        next unless link_names.include?(path)

        repository = {
          url: "#{release[:url]}#{path}/"
        }
        repository[:repo_url] = "#{release[:url]}#{path}" if save_path
        repository[key] = path if key
        repositories << repository
      end
      repositories
    end
  end

  # Save URL to the key
  # @param key [Symbol] field to save data to
  def save_url_to_field(key)
    lambda do |release, _links|
      [release.clone.merge({ key => release[:url] })]
    end
  end

  # Write all information about releases to the JSON documents
  def write_repository(product_dir, releases)
    platforms = releases.map { |release| release[:platform] }.uniq
    platforms.each do |platform|
      configuration_directory = File.join(product_dir, platform)
      FileUtils.mkdir_p(configuration_directory)
      releases_by_version = Hash.new { |hash, key| hash[key] = [] }
      releases.each do |release|
        next if release[:platform] != platform

        releases_by_version[release[:version]] << extract_release_fields(release)
      end
      releases_by_version.each_pair do |version, version_releases|
        File.write(File.join(configuration_directory, "#{version.gsub('/', '-')}.json"),
                   JSON.pretty_generate(version_releases))
      end
    end
  end

  # Create repository in the target directory.
  def write_product(product, releases)
    info_and_log("Writing generated configuration for #{product} to the repository.")
    product_name = PRODUCTS_DIR_NAMES[product]
    product_dir = File.join(@destination, product_name)
    if @product_version.nil?
      FileUtils.rm_rf(product_dir, secure: true)
      FileUtils.mkdir_p(product_dir)
    else
      releases = releases.select do |release|
        release[:version] == @product_version
      end
    end
    write_repository(product_dir, releases)
  end

  # Create repository by calling appropriate method using reflection and writing results
  # @param product [String] name of the product to generate
  # @returns [Boolean] whether generation was successful or not
  def create_repository(product)
    info_and_log("Generating repository configuration for #{product}")
    begin
      releases = send("parse_#{product}".to_sym, @config[product])
      if releases.empty?
        error_and_log("#{product} was not generated. Skiped.")
      else
        write_product(product, releases)
      end
      true
    rescue StandardError => e
      error_and_log("Error message: #{e.message}")
      error_and_log("#{product} was not generated.")
      false
    end
  end

  # Print summary information about the created products
  # @param products_with_errors [Array<String>] product names that were not generated
  def print_summary(products_with_errors)
    info_and_log("\n--------\nSUMMARY:\n")
    @products.sort.each do |product|
      result = products_with_errors.include?(product) ? '-' : '+'
      info_and_log("  #{product}: #{result}")
    end
  end

  # Starting point of the application
  def execute
    if @env.show_help
      show_help
      return SUCCESS_RESULT
    end
    return ARGUMENT_ERROR_RESULT unless configure_command

    remainning_products = @products.dup
    @attempts.times do
      remainning_products = remainning_products.reject do |product|
        create_repository(product)
      end
      break if remainning_products.empty?
    end
    print_summary(remainning_products)
    SUCCESS_RESULT
  end
end
# rubocop:enable Metrics/ClassLength
