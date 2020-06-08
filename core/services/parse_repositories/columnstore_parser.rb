# frozen_string_literal: true

# This module handles the Columnstore repository
module ColumnstoreParser
  def self.parse(config, log, logger)
    releases = []
    releases.concat(parse_columnstore_rpm_repository(config['repo']['rpm'], log, logger))
    releases.concat(parse_columnstore_deb_repository(config['repo']['deb'], log, logger))
    releases
  end

  def self.parse_columnstore_rpm_repository(config, log, logger)
    ParseHelper.parse_repository(
      config['path'], nil, config['key'], 'columnstore', %w[mariadb-columnstore],
      ->(url) { url },
      ->(package, _) { /#{package}/ },
      log, logger,
      ParseHelper.save_as_field(:version),
      ParseHelper.append_url(%w[yum]),
      ParseHelper.split_rpm_platforms,
      ParseHelper.save_as_field(:platform_version),
      ParseHelper.append_url(%w[x86_64]),
      lambda do |release, _|
        release[:repo] = release[:url]
        release
      end
    )
  end

  def self.parse_columnstore_deb_repository(config, log, logger)
    ParseHelper.parse_repository(
      config['path'], nil, config['key'], 'columnstore', %w[mariadb-columnstore],
      ->(url) { generate_mdbe_ci_deb_full_url(url) },
      ->(package, _) { /#{package}/ },
      log, logger,
      ParseHelper.save_as_field(:version),
      ParseHelper.append_url(%w[repo]),
      ParseHelper.extract_field(:platform, %r{^(\p{Alpha}+)\p{Digit}+\/?$}, true),
      ParseHelper.append_url(%w[dists]),
      ParseHelper.save_as_field(:platform_version),
      lambda do |release, _|
        release[:repo] = release[:repo_url]
        release
      end
    )
  end

  def self.generate_mdbe_ci_deb_full_url(incorrect_url)
    split_url = incorrect_url.split('/')
    split_url.pop(2)
    url = split_url.join('/')
    "#{url}/pool/main/m/"
  end
end
