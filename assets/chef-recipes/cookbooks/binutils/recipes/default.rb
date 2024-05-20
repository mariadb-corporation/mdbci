package 'binutils' do
  if platform?('redhat', 'centos', 'rocky', 'almalinux')
    flush_cache({ before: true })
  end
end
