package 'binutils' do
  if platform?('redhat', 'centos', 'rocky', 'alma')
    flush_cache({ before: true })
  end
end
