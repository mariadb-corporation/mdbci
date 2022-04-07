# frozen_string_literal: true

require_relative 'repository_parser_core'

# Handles the ODBC connector CI repository
module ConnectorOdbcCiParser
  extend RepositoryParserCore

  PRODUCT_NAME = 'connector_odbc_ci'

  def self.parse(config, product_version, mdbe_ci_config, ui, logger)
    return [] if mdbe_ci_config.nil?

    auth = mdbe_ci_config['mdbe_ci_repo']
    releases = parse_web_directories(
      config['repo']['path'],
      auth,
      product_version,
      ui,
      logger,
      save_as_field(:version),
      extract_field(:tmp, /bintar/),
      save_as_field(:platform),
      save_as_field(:platform_version),
      save_as_field(:architecture)
    )
    releases.each_with_object([]) do |release, result|
      archive = get_links(release[:url], logger, auth).find { |link| /connector-odbc.*tar\.gz/ =~ link[:content] }
      next if archive.nil?

      release[:architecture] = determine_architecture(release[:architecture])
      result << release.merge({
                                repo: add_auth_to_url(release[:url] + archive[:href], auth),
                                product: PRODUCT_NAME
                              })
    end
  end

  def self.determine_architecture(architecture)
    if architecture == 'x86_64'
      'amd64'
    else
      architecture
    end
  end
end
