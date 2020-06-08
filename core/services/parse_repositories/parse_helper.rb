# frozen_string_literal: true

# This module provides logic for processing repositories
module ParseHelper
  def self.add_auth_to_url(url, auth)
    url.dup.insert(url.index('://') + 3, "#{auth['username']}:#{auth['password']}@")
  end

  # Save all values that present in current level as field contents
  # @param field [Symbol] field to save data to
  # @param save_path [Boolean] whether to save path to :repo_url field or not
  def self.save_as_field(field, save_path = false)
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

  # Append URL to the current search path, possibly saving it to the key
  # and saving it to repo_url for future use
  # @param paths [Array<String>] array of paths that should be checked for presence
  # @param key [Symbol] field to save data to
  # @param save_path [Boolean] whether to save path to :repo_url field or not
  def self.append_url(paths, key = nil, save_path = false)
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

  RPM_PLATFORMS = {
    'el' => %w[centos rhel],
    'sles' => %w[sles],
    'centos' => %w[centos],
    'rhel' => %w[rhel],
    'opensuse' => %w[opensuse]
  }.freeze
  def self.split_rpm_platforms
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

  # Filter all links via regular expressions and then place captured first element as version
  # @param field [Symbol] name of the field to write result to
  # @param rexexp [RegExp] expression that should have first group designated to field extraction
  # @param save_path [Boolean] whether to save current path to the release or not
  def self.extract_field(field, regexp, save_path = false)
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

  DEB_PLATFORMS = {
    'bionic' => 'ubuntu',
    'buster' => 'debian',
    'focal' => 'ubuntu',
    'jessie' => 'debian',
    'stretch' => 'debian',
    'xenial' => 'ubuntu'
  }.freeze
  def self.extract_deb_platforms
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

  # Parse the repository and provide required configurations
  def self.parse_repository(
    base_url, auth, key, product, packages, full_url, comparison_template, log, logger, *steps
  )
    # Recursively go through the site and apply steps on each level
    result = steps.reduce([{ url: base_url }]) do |releases, step|
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
      filter_releases(next_releases.flatten)
    end
    result = remove_corrupted_releases(result, packages, full_url, auth, comparison_template)
    add_key_and_product_to_releases(result, key, product)
  end

  # Send error message to both direct output and logger facility
  def self.error_and_log(message, log, logger)
    log.error(message)
    logger.error(message)
  end

  # Links that look like directories from the list of all links
  # @param url [String] path to the site to be checked
  # @param auth [Hash] basic auth data in format { username, password }
  # @return [Array] possible link locations
  def self.get_directory_links(url, logger, auth = nil)
    get_links(url, logger, auth).select { |link| dir_link?(link) && !parent_dir_link?(link) }
  end

  # Get links list on the page
  # @param url [String] path to the site to be checked
  # @param auth [Hash] basic auth data in format { username, password }
  # @return [Array] possible link locations
  def self.get_links(url, logger, auth = nil)
    uri = url.gsub(%r{([^:])\/+}, '\1/')
    logger.info("Loading URLs '#{uri}'")
    options = {}
    options[:http_basic_authentication] = [auth['username'], auth['password']] unless auth.nil?
    doc = Nokogiri::HTML(URI.open(uri, options).read)
    doc.css('a')
  end

  # Check that passed link is possibly a directory or not
  # @param link link to check
  # @return [Boolean] whether link is directory or not
  def self.dir_link?(link)
    link.content.match?(%r{\/$}) ||
      link[:href].match?(%r{^(?!((http|https):\/\/|\.{2}|\/|\?)).*\/$})
  end

  # Check that passed link is possibly a parent directory link or not
  # @param link link to check
  # @return [Boolean] whether link is parent directory link or not
  def self.parent_dir_link?(link)
    link[:href] == '../'
  end

  # Helper method that applies the specified step to the current release
  # @param step [Lambda] the executable lambda that should be applied here
  # @param links [Array] the list of elements got from the page
  # @param release [Hash] information about the release collected so far
  def self.apply_step_to_links(step, links, release)
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

  # Method filters releases, removing empty ones and by version, if it required
  def self.filter_releases(releases)
    next_releases = releases.reject(&:nil?)
    next_releases.select do |release|
      if @product_version.nil? || release[:version].nil?
        true
      else
        release[:version] == @product_version
      end
    end
  end

  def self.remove_corrupted_releases(releases, packages, full_url, auth, comparison_template)
    Workers.map(releases) do |release|
      content = generate_content(full_url.call(release[:url]), auth)
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
  def self.add_key_and_product_to_releases(releases, key, product)
    releases.each do |release|
      release[:repo_key] = key
      release[:product] = product
    end
  end

  # Generate HTML content as a string
  def self.generate_content(url, auth)
    options = {}
    options[:http_basic_authentication] = [auth['username'], auth['password']] unless auth.nil?
    doc = Nokogiri::HTML(URI.open(url, options).read)
    doc.css('a').to_s
  rescue OpenURI::HTTPError
    ''
  end

  # Parse the repository and provide required configurations
  # @param [Array] steps - array of Hash in format { lambda, complete_condition }
  def self.parse_repository_recursive(
    base_url, auth, key, product, packages, full_url, comparison_template, log, logger, *steps
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
        next_releases = filter_releases(next_releases.flatten)
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
  def self.append_to_field(field)
    lambda do |release, links|
      links.map do |link|
        release.clone.merge({ link: link,
                              field => release.fetch(field, []) + [link.content.delete('/')] })
      end
    end
  end

  def self.dirs?(dirs)
    lambda do |links|
      repo_dirs = links.map { |link| link.content.delete('/').strip.chomp }
      (repo_dirs & dirs).any?
    end
  end
end
