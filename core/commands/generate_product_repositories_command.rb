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
require_relative 'generate_repository_partials/mdbe_ci_parser'
require_relative 'generate_repository_partials/maxscale_ci_parser'
require_relative 'generate_repository_partials/maxscale_ci_docker_parser'
require_relative 'generate_repository_partials/maxscale_parser'
require_relative 'generate_repository_partials/mdbe_parser'
require_relative 'generate_repository_partials/mariadb_parser'
require_relative 'generate_repository_partials/columnstore_parser'
require_relative 'generate_repository_partials/mysql_parser'
require_relative 'generate_repository_partials/clustrix_parser'
require_relative 'generate_repository_partials/galera_enterprise_ci_parser'

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
      releases = parse_repository(product, @config[product])
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

  def parse_repository(product, product_config)
    case product
    when 'mdbe_ci'
      MdbeCiParser.parse(product_config, @env.mdbe_ci_config, @ui, @logger)
    when 'maxscale_ci'
      MaxscaleCiParser.parse(product_config, @env.mdbe_ci_config, @ui, @logger)
    when 'maxscale_ci_docker'
      MaxscaleCiDockerParser.parse(@ui, @env.tool_config)
    when 'maxscale'
      MaxscaleParser.parse(product_config, @ui, @logger)
    when 'mdbe'
      MdbeParser.parse(product_config, @env.mdbe_private_key)
    when 'mariadb'
      MariadbParser.parse(product_config, @ui, @logger)
    when 'columnstore'
      ColumnstoreParser.parse(product_config, @ui, @logger)
    when 'mysql'
      MysqlParser.parse(product_config, @ui, @logger)
    when 'clustrix'
      ClustrixParser.parse(product_config)
    when 'galera_enterprise_ci'
      GaleraEnterpriseCiParser.parse(product_config, @env.mdbe_ci_config, @ui, @logger)
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
