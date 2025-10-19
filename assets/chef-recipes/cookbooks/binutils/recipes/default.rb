package 'binutils' do
  if platform?('redhat', 'centos', 'rocky', 'almalinux', 'oracle')
    flush_cache({ before: true })
  end
end
