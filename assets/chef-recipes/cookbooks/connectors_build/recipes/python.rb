# frozen_string_literal: true

if platform?('redhat') && node[:platform_version].to_i == 8
  package 'python36'
else
  package 'python3'
  package 'python3-pip'
end
