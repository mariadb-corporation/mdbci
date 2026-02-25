package 'binutils' do
  flush_cache({ before: true }) if platform?('redhat', 'centos', 'rocky', 'almalinux', 'oracle')
end
