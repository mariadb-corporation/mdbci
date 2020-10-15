# frozen_string_literal: true

require 'xdg'
require 'json'
require_relative 'sem_version_parser'
require_relative '../models/return_codes'
require_relative '../models/tool_configuration'
require_relative 'product_attributes'

# A class that provides access to list of repositories that are defined in MDBCI
class RepoManager
  include ReturnCodes

  attr_accessor :repos

  # The list of the directories to search data in.
  # The last directory takes presence over the first one.
  BOX_DIRECTORIES = [
    File.expand_path('../../config/repo.d/', __dir__),
    File.join(XDG::Config.new.home, 'mdbci', 'repo.d')
  ].freeze

  def initialize(logger, box_definitions, extra_path = nil)
    @ui = logger
    @box_definitions = box_definitions
    if !extra_path.nil? && !File.exist?(extra_path)
      raise ArgumentError, "The specified repository definition path is absent: '#{extra_path}'"
    end

    @repos = {}
    paths = Array.new(BOX_DIRECTORIES).push(extra_path).compact
    paths.each do |path|
      lookup(path)
    end
    raise 'Repositories was not found' if @repos.empty?

    @ui.info("Loaded repos: #{@repos.size}")
  end

  def find_repository(product_name, product, box)
    @ui.info('Looking for repo')
    if ProductAttributes.uses_version_as_repository?(product_name, product['version'])
      @ui.warning('MDBCI cannot determine the existence/correctness of the specified version of the product!')
      return { 'version' => product['version'] }
    end
    repository_key = @box_definitions.platform_key(box)
    if !product.key?('version')
      repo = find_last_repository_version(product, repository_key)
    else
      version = product['version']
      repository_name = ProductAttributes.repository(product_name)
      repo_key = "#{repository_name}@#{version}+#{repository_key}"
      repo = @repos[repo_key]
    end
    if product.key?('version') && repo.nil?
      repo = find_last_repository_by_major_version(product, repository_key)
      unless repo.nil?
        @ui.warning("MDBCI could not find the specified version #{product['version']}, "\
                    "automatically using the closes version #{repo['version']}")
        repo_key = "#{repository_name}@#{repo['version']}+#{repository_key}"
      end
    end
    @ui.info("Repo key is '#{repo_key}': #{repo.nil? ? 'Not found' : 'Found'}")
    repo
  end

  def show
    @repos.each_key do |key|
      @ui.out key + ' => [' + @repos[key]['repo'] + ']'
    end
    0
  end

  def getRepo(key)
    repo = @repos[key]
    raise "Repository for key #{key} was not found" if repo.nil?

    repo
  end

  def lookup(path)
    @ui.info("Looking up for repos in '#{path}'")
    Dir.glob(path + '/**/*.json', File::FNM_DOTMATCH) do |f|
      addRepo(f)
    end
  end

  def knownRepo?(repo)
    @repos.key?(repo)
  end

  def productName(repo)
    repo.to_s.split('@')[0]
  end

  def makeKey(product, version, platform, platform_version)
    version = '?' if version.nil?

    product.to_s + '@' + version.to_s + '+' + platform.to_s + '^' + platform_version.to_s
  end

  def addRepo(file)
    repo = JSON.parse(IO.read(file))

    if repo.is_a?(Array)
      # in repo file arrays are allowed
      repo.each do |r|
        @repos[makeKey(r['product'], r['version'], r['platform'], r['platform_version'])] = r
      end
    else
      @repos[makeKey(repo['product'], repo['version'], repo['platform'], repo['platform_version'])] = repo
    end
  rescue StandardError
    @ui.warning 'Invalid file format: ' + file.to_s + ' SKIPPED!'
  end

  private

  # Find all available product repositories by repository_key
  # @param product [Hash] hash array with information about product
  # @param repository_key [String] key of repository
  def find_available_repo(product, repository_key)
    @repos.find_all do |elem|
      elem[1]['product'] == product['name'] &&
        elem[1]['platform'] + '^' + elem[1]['platform_version'] == repository_key
    end
  end

  # Find the latest available repository version
  # @param product [Hash] hash array with information about product
  # @param repository_key [String] key of repository
  def find_last_repository_version(product, repository_key)
    all_available_repo = find_available_repo(product, repository_key)
    repo = all_available_repo.last[1]
    all_available_repo.delete_if { |elem| elem[1]['version'].include?('debug') }
    repo = all_available_repo.last[1] unless all_available_repo.nil?
    repo
  end

  # Find the latest available repository version by major version if it's not exists.
  # For example, for 10.2 version it returns latest 10.2.33-8 version.
  # @param product [Hash] hash array with information about product
  # @param repository_key [String] key of repository
  def find_last_repository_by_major_version(product, repository_key)
    version = SemVersionParser.parse_sem_version(product['version'])
    return nil if version.nil?

    find_available_repo(product, repository_key).select do |repo|
      repo[1]['sem_version'] = SemVersionParser.parse_sem_version(repo[1]['version'])
      next false if repo[1]['sem_version'].nil?
      version.each_with_index.all? { |version_part, index| version_part == repo[1]['sem_version'][index]  }
    end.max do |a, b|
      a[1]['sem_version'] <=> b[1]['sem_version']
    end&.fetch(1, nil)
  end
end
