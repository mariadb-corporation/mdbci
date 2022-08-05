#!/usr/bin/env ruby
# frozen_string_literal: true

# This script outputs all instance types that satisfy the given AMI and Amazon Availability Zone

require 'aws-sdk-core'
require 'aws-sdk-ec2'
require 'optparse'
require 'yaml'
require_relative '../../core/services/configuration_reader'

MDBCI_CONFIG_FILE_NAME = 'mdbci/config.yaml'

# Returns a list of instance types that match the image requirements
#
# @param client [Aws::EC2::Client] An initialized EC2 client.
# @param architecture [String] CPU architecture type ('x86_64' | 'arm64')
# @param virtualization_type [String] AMI virtualization type ('hvm' | 'vp')
def list_types_from_requirements(client, architecture, virtualization_type)
  response = client.get_instance_types_from_instance_requirements(
    {
      architecture_types: [architecture],
      virtualization_types: [virtualization_type],
      instance_requirements: {
        v_cpu_count: {
          min: 1
        },
        memory_mi_b: {
          min: 1
        }
      }
    }
  )
  response.instance_types.map(&:instance_type)
end

# Returns a list of instance types in the given Availability Zone
#
# @param client [Aws::EC2::Client] An initialized EC2 client.
# @param zone [String] Availability Zone to search for in (e.g. 'eu-west-1a')
def list_types_from_zone(client, zone)
  response = client.describe_instance_type_offerings(
    {
      location_type: 'availability-zone',
      filters: [
        {
          name: 'location',
          values: [zone]
        }
      ]
    }
  )
  response.instance_type_offerings.map(&:instance_type)
end

# Searches for an image by AMI and obtains required CPU architecture and virtualization type
#
# @param client [Aws::EC2::Client] An initialized EC2 client.
# @param ami [String] Amazon Machine Image id
def get_ami_parameters(client, ami)
  response = client.describe_images({ image_ids: [ami] })
  return {} if response.images.empty?

  image = response.images.first
  {
    architecture: image.architecture,
    virtualization_type: image.virtualization_type
  }
end

# Parses script arguments
def parse_options
  options = {}
  OptionParser.new do |opt|
    opt.on('-z', '--zone AVAILABILITY_ZONE', 'Amazon availability zone (required)') do |o|
      options[:zone] = o
    end
    opt.on('-a', '--ami AMI', 'Amazon Machine Image id (required)') do |o|
      options[:ami] = o
    end
  end.parse!
  unless options[:zone] && options[:ami]
    puts '--zone and --ami parameters are required! Use --help for more details'
    exit 1
  end
  options
end

# Obtains AWS credentials from MDBCI configuration
def load_mdbci_aws_configuration
  config_path = ConfigurationReader.path_to_user_file(MDBCI_CONFIG_FILE_NAME)
  config = YAML.safe_load(File.read(config_path))
  config['aws']
end

# Initializes an EC2 client and configures its credentials
def configure_ec2_client
  aws_config = load_mdbci_aws_configuration
  credentials = Aws::Credentials.new(aws_config['access_key_id'], aws_config['secret_access_key'])
  Aws::EC2::Client.new(region: aws_config['region'], credentials: credentials)
end

# Displays suitable instance types in JSON format
#
# @param client [Aws::EC2::Client] An initialized EC2 client.
# @param options [Hash] Given AMI and Zone parsed from script arguments
def print_supported_instance_types(client, options)
  ami_params = get_ami_parameters(client, options[:ami])
  types_from_requirements = list_types_from_requirements(client,
                                                         ami_params[:architecture],
                                                         ami_params[:virtualization_type])
  types_from_zone = list_types_from_zone(client, options[:zone])
  puts types_from_requirements.intersection(types_from_zone).to_json
rescue Aws::EC2::Errors::InvalidAMIIDMalformed, Aws::EC2::Errors::InvalidAMIIDNotFound
  puts "Invalid AMI: #{options[:ami]}"
  exit 1
end

def main
  options = parse_options
  client = configure_ec2_client
  print_supported_instance_types(client, options)
end

main if $PROGRAM_NAME == __FILE__
