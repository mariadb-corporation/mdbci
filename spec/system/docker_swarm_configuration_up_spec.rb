# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

RSpec.describe 'Docker Swarm configuration', :benchmark do
  it 'should be able to spin-up several times with recreation' do
    labels = %w[backend first second maxscale] * 3
    labels.shuffle!
    labels.each_cons(2) do |first_label, second_label|
      test_dir = Dir.mktmpdir
      config = mdbci_create_configuration(test_dir, 'docker_swarm')
      result = mdbci_up_command(config, "--labels #{first_label}")
      result = mdbci_up_command(config, "--labels #{second_label} --recreate") if result.success?
      mdbci_destroy_command(config)
      FileUtils.rm_rf(test_dir)
      expect(result).to be_success
    end
  end
end

