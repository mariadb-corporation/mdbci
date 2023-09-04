# frozen_string_literal: true

require 'uri'

# This module provides logic for processing repositories
module RepositoryParserCore
  def add_auth_to_url(url, auth)
    url.dup.insert(url.index('://') + 3, "#{auth['username']}:#{auth['password']}@")
  end

  # Save all values that present in current level as field contents
  # @param field [Symbol] field to save data to
  # @param save_path [Boolean] whether to save path to :repo_url field or not
  def save_as_field(field, save_path = false)
    lambda do |release, links|
      links.map do |link|
        result = {
          link: link,
          field => link[:href].delete('/')
        }
        result[:repo_url] = URI.join(release[:url], link[:href]).to_s if save_path
        result
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
      link_names = links.map { |link| link[:content].delete('/') }
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

  # Append URL to the current search path if this URL exists
  # @param paths [Array<String>] appending paths
  def append_path_if_exists(paths)
    lambda do |release, links|
      paths.map do |path|
        if links.map { |link| link[:content].delete('/') }.include?(path)
          release.merge(url: "#{release[:url]}#{path}/")
        else
          release
        end
      end
    end
  end

  def save_key(logger, auth, candidate_key)
    lambda do |release, _|
      key_link = get_links(release[:url], logger, auth).select { |link| key_link?(link) }
      key_name = key_link.map { |link| link[:content].delete('/') }
      release[:repo_key] = if key_name.empty?
                             candidate_key
                           else
                             add_auth_to_url("#{release[:url]}#{key_name[0]}", auth)
                           end
      release
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
      link_names = links.map { |link| link[:content].delete('/') }
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

  DEB_VERSIONS = {
    '8' => 'jessie',
    '9' => 'stretch',
    '10' => 'buster',
    '11' => 'bullseye',
    '12' => 'bookworm',
    '1604' => 'xenial',
    '1804' => 'bionic',
    '2004' => 'focal',
    '2204' => 'jammy'
  }.freeze
  def add_platform_and_version(platform)
    lambda do |release, links|
      link_names = links.map { |link| link[:content].delete('/') }
      releases = []
      link_names.each do |platform_and_version|
        platform_version = if platform == :deb
                             DEB_VERSIONS[platform_and_version.split('-').last]
                           else
                             platform_and_version.split('-').last
                           end
        releases << {
          url: "#{release[:url]}#{platform_and_version}/",
          platform: platform_and_version.split('-').first,
          platform_version: platform_version
        }
      end
      releases
    end
  end

  # Filter all links via regular expressions and then place captured first element as version
  # @param field [Symbol] name of the field to write result to
  # @param rexexp [RegExp] expression that should have first group designated to field extraction
  # @param save_path [Boolean] whether to save current path to the release or not
  def extract_field(field, regexp, save_path = false)
    lambda do |release, links|
      possible_releases = links.select do |link|
        link[:content] =~ regexp
      end
      possible_releases.map do |link|
        result = {
          link: link,
          field => link[:content].match(regexp).captures.first
        }
        result[:repo_url] = "#{release[:url]}#{link[:href]}" if save_path
        result
      end
    end
  end

  DEB_PLATFORMS = {
    'jammy' => 'ubuntu',
    'bionic' => 'ubuntu',
    'buster' => 'debian',
    'bullseye' => 'debian',
    'bookworm' => 'debian',
    'focal' => 'ubuntu',
    'jessie' => 'debian',
    'stretch' => 'debian',
    'xenial' => 'ubuntu'
  }.freeze
  def extract_deb_platforms
    lambda do |release, links|
      links.map do |link|
        link[:content].delete('/')
      end.select do |link|
        DEB_PLATFORMS.keys.any? { |platform| link.start_with?(platform) }
      end.map do |link|
        { url: "#{release[:url]}#{link}/",
          platform: DEB_PLATFORMS[link],
          platform_version: link }
      end
    end
  end

  # Parse the repository and provide required configurations
  def parse_repository(
    base_url,
    auth,
    key,
    product,
    product_version,
    packages,
    full_url,
    comparison_template,
    log,
    logger,
    *steps
  )
    # Recursively go through the site and apply steps on each level
    result = parse_web_directories(base_url, auth, product_version, log, logger, *steps)
    result = remove_corrupted_releases(result, packages, full_url, auth, comparison_template)
    add_key_and_product_to_releases(result, key, product)
  end

  # Parse web directories and apply step for each of directory level
  def parse_web_directories(base_url, auth, product_version, log, logger, *steps)
    steps.reduce([{ url: base_url }]) do |releases, step|
      next_releases = Workers.map(releases) do |release|
        begin
          links = get_directory_links(release[:url], logger, auth)
        rescue StandardError => e
          error_and_log("Unable to get information from link '#{release[:url]}',"\
                        " message: '#{e.message}'", log, logger)
          next
        end
        apply_step_to_links(step, links, release)
      end
      filter_releases(next_releases.flatten, product_version)
    end
  end

  # Send error message to both direct output and logger facility
  def error_and_log(message, log, logger)
    log.error(message)
    logger.error(message)
  end

  # Links that look like directories from the list of all links
  # @param url [String] path to the site to be checked
  # @param auth [Hash] basic auth data in format { username, password }
  # @return [Array] possible link locations
  def get_directory_links(url, logger, auth = nil)
    get_links(url, logger, auth).select do |link|
      dir_link?(link) && sub_link?(url, link)
    end
  end

  # Get links list on the page
  # @param url [String] path to the site to be checked
  # @param auth [Hash] basic auth data in format { username, password }
  # @return [Array] possible link locations
  def get_links(url, logger, auth = nil)
    uri = url.gsub(%r{([^:])\/+}, '\1/')
    logger.info("Loading URLs '#{uri}'")
    options = {}
    options[:http_basic_authentication] = [auth['username'], auth['password']] unless auth.nil?
    doc = get_html_document(uri, options)
    doc.css('a').map do |css_element|
      {
        href: css_element[:href],
        content: css_element.content
      }
    end
  end

  # Check that passed link is possibly a directory or not
  # @param link link to check
  # @return [Boolean] whether link is directory or not
  def dir_link?(link)
    link[:content].match?(%r{/$}) ||
      link[:href].match?(%r{.*/$})
  end

  def key_link?(link)
    link[:href].match?(%r{.*public$})
  end

  # Check whether a passed link is a sub link for the base url
  # @param base_url [String] the page url that is being processed
  # @param link [String] the link that is found on the page
  # @return [Boolean] whether true or false
  def sub_link?(base_url, link)
    test_link = URI.join(base_url, link[:href])
    base_link = URI.parse(base_url)
    test_link_parts = test_link.path.split('/')
    base_link_parts = base_link.path.split('/')
    return false if test_link_parts.size <= base_link_parts.size

    base_link_parts.zip(test_link_parts).all? do |first, second|
      first == second
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
        result[:url] = URI.join(release[:url], next_release[:link][:href]).to_s
        result.delete(:link)
      end
      result[:url] += '/' unless result[:url].end_with?('/')
      result
    end
  end

  # Method filters releases, removing empty ones and by version, if it required
  def filter_releases(releases, product_version)
    next_releases = releases.reject(&:nil?)
    next_releases.select do |release|
      if product_version.nil? || release[:version].nil?
        true
      else
        release[:version] == product_version
      end
    end
  end

  def remove_corrupted_releases(releases, packages, full_url, auth, comparison_template)
    Workers.map(releases) do |release|
      dirs_for_check = [full_url.call(release[:url], release)].flatten
      content = dirs_for_check.map { |url| generate_content(url, auth) }.join('')
      next unless packages.all? do |package|
        comparison_template.call(package, release[:platform_version]) =~ content
      end

      release
    end.compact
  end

  # Append key and product to the releases
  # @param releases [Array<Hash>] list of releases
  # @param key [String] text to put into key field
  # @param product [String] name of the product
  def add_key_and_product_to_releases(releases, key, product)
    releases.each do |release|
      release[:repo_key] ||= key unless key.nil?
      release[:product] = product
    end
  end

  # Generate HTML content as a string
  def generate_content(url, auth)
    options = {}
    options[:http_basic_authentication] = [auth['username'], auth['password']] unless auth.nil?
    doc = get_html_document(url, options)
    doc.css('a').to_s
  end

  # Create a HTML document for a link, or an empty one if request did not happen
  def get_html_document(uri, options)
    Nokogiri::HTML(URI.open(uri, options).read)
  rescue OpenURI::HTTPError, Net::OpenTimeout
    Nokogiri::HTML('')
  end

  # Parse the repository and provide required configurations
  # @param [Array] steps - array of Hash in format { lambda, complete_condition }
  def parse_repository_recursive(
    base_url, auth, key, product, product_version, packages, full_url, comparison_template, log, logger, *steps
  )
    # Recursively go through the site and apply steps on each level
    result = steps.reduce([{ url: base_url }]) do |input_releases, step|
      completed_releases = []
      processed_releases = input_releases
      # Traversing directories in depth as part of a single step.
      # 25 - maximum depth to avoid looping
      25.times do
        next_releases = Workers.map(processed_releases) do |release|
          begin
            links = get_directory_links(release[:url], logger, auth)
          rescue StandardError => e
            error_and_log("Unable to get information from link '#{release[:url]}',"\
                          " message: '#{e.message}'", log, logger)
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
        next_releases = filter_releases(next_releases.flatten, product_version)
        completed_releases += next_releases.select { |release| release[:continue_step] == false }
        processed_releases = next_releases - completed_releases
        break if processed_releases.empty?
      end
      completed_releases
    end
    result = remove_corrupted_releases(result, packages, full_url, auth, comparison_template)
    add_key_and_product_to_releases(result, key, product)
  end

  # Append all values that present in current level to fields
  # @param field [Symbol] field to save data to
  def append_to_field(field)
    lambda do |release, links|
      links.map do |link|
        release.clone.merge({ link: link,
                              field => release.fetch(field, []) + [link[:content].delete('/')] })
      end
    end
  end

  def dirs?(dirs)
    lambda do |links|
      repo_dirs = links.map { |link| link[:content].delete('/').strip.chomp }
      (repo_dirs & dirs).any?
    end
  end

  def setup_private_key(path, private_key)
    return path if private_key.nil?

    path.sub('$PRIVATE_KEY$', private_key)
  end

  def set_deb_architecture(auth)
    lambda do |release, _links|
      content = generate_content("#{release[:url]}main/", auth)
      architectures = []
      architectures << 'amd64' if content =~ /binary-amd64/
      architectures << 'aarch64' if content =~ /binary-arm64/
      architectures.map { |architecture| release.merge({ architecture: architecture }) }
    end
  end

  # Determines the architecture of debian repository based on `binary-ARCH` string
  def determine_deb_architecture(string)
    architecture = string.split('-').last
    architecture = 'aarch64' if architecture == 'arm64'
    architecture
  end

  def determine_rpm_architecture(string)
    case string
    when 'x86_64'
      'amd64'
    else
      string
    end
  end

  def generate_mariadb_deb_full_url(incorrect_url)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')

    mariadb_version = '10.5' if url.include?('10.5')
    mariadb_version = '10.0' if url.include?('10.0')
    mariadb_version = '10.1' if url.include?('10.1')
    mariadb_version = '10.2' if url.include?('10.2')
    mariadb_version = '10.3' if url.include?('10.3')
    mariadb_version = '10.4' if url.include?('10.4')
    mariadb_version = '10.6' if url.include?('10.6')
    mariadb_version = '23.08' if url.include?('23.08')
    if mariadb_version == '23.08'
      "#{url}/pool/main/m/mariadb/"
    else
      "#{url}/pool/main/m/mariadb-#{mariadb_version}/"
    end
  end

  # Generate full URL for MariaDB Community and Enterprise from CI repo
  def generate_mariadb_ci_deb_full_url(incorrect_url, logger, log, auth)
    url = go_up(incorrect_url, 2)
    pool_url = URI.join(url, 'pool/main/').to_s
    pool_sub_links = get_directory_links(pool_url, logger, auth)
    has_mariadb_dir = false
    pool_sub_links.map do |pool_dir|
      has_mariadb_dir = true if pool_dir[:href] == 'm/'
    end
    if has_mariadb_dir
      pool_url = URI.join(pool_url, 'm/').to_s
    else
      error_and_log('MariaDB directory not found in repo. Skipped.', log, logger)
    end
    package_list_url = get_directory_links(pool_url, logger, auth).first
    URI.join(pool_url, package_list_url[:href]).to_s
  end

  # Returns the url obtained by jumping number_of_levels above
  # @param url {String} base path to start
  # @param number_of_levels {Integer} number of levels to go up
  def go_up(url, number_of_levels)
    split_url = url.split('/')
    split_url.pop(number_of_levels)
    "#{split_url.join('/')}/"
  end

  def add_unsupported_repo(main_path, unsupported_path, auth, log, logger)
    lambda do |release, _links|
      additional_link = release[:url].sub(main_path, unsupported_path)
      begin
        get_directory_links(additional_link, logger, auth)
        release[:unsupported_repo] = release[:repo].sub(
          add_auth_to_url(main_path, auth), add_auth_to_url(unsupported_path, auth)
        )
      rescue StandardError
        error_and_log("Failed to generate an unsupported repository for #{release[:url]}", log,
                      logger)
      end
      release
    end
  end
end
