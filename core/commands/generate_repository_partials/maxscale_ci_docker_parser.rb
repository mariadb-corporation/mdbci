# frozen_string_literal: true

require_relative '../../models/return_codes'

# This module handles the Maxscale CI Docker repository
module MaxscaleCiDockerParser
  include ReturnCodes

  def self.parse(log, tool_config)
    releases = []
    releases.concat(parse_maxscale_ci_repository_for_docker(log, tool_config))
    releases
  end

  def self.get_maxscale_ci_release_version_for_docker(base_url, username, password, log)
    uri_with_tags = URI.join(base_url, '/v2/mariadb/maxscale-ci/tags/list')
    begin
      doc_tags = JSON.parse(URI.open(uri_with_tags,
                                     http_basic_authentication: [username, password]).read)
      doc_tags.dig('tags')
    rescue OpenURI::HTTPError => e
      log.error("Failed to get tags for docker from #{uri_with_tags}: #{e}")
      ERROR_RESULT
    rescue StandardError
      log.error('Failed to get tags for docker')
      ERROR_RESULT
    end
  end

  # Generate information about releases
  def self.generate_maxscale_ci_releases_for_docker(base_url, tags)
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

  def self.parse_maxscale_ci_repository_for_docker(log, tool_config)
    base_url = tool_config.dig('docker', 'ci-server').to_s
    username = tool_config.dig('docker', 'username').to_s
    password = tool_config.dig('docker', 'password').to_s

    tags = get_maxscale_ci_release_version_for_docker(base_url, username, password, log)
    return [] if tags == ERROR_RESULT

    generate_maxscale_ci_releases_for_docker(base_url, tags)
  end
end
