require 'rspec'
require_relative '../spec_helper'
require_relative '../../core/session'
require_relative '../../core/services/repo_manager'
require_relative '../../core/boxes_manager'

describe 'RepoManager' do
  context '.repos' do
    it "Check repos loading..." do
      $mdbci_exec_dir = File.absolute_path('.')
      $session = Session.new
      $out = Out.new($session)
      $session.isSilent = true
      $session.mdbciDir = Dir.pwd
      boxesPath = './BOXES'
      $session.boxes = BoxesManager.new boxesPath
      reposPath = './config/repo.d'
      $session.repos = RepoManager.new reposPath
      $session.repos.repos.size().should be > 0
    end
  end
end
