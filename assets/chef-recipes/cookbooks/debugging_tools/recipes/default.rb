packages = %w[gdb valgrind]

package packages do
  if platform?('redhat', 'centos', 'rocky', 'almalinux', 'oracle')
    flush_cache({ before: true })
  end
end
