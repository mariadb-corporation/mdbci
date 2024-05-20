packages = %w[gdb valgrind]

package packages do
  if platform?('redhat', 'centos', 'rocky', 'alma')
    flush_cache({ before: true })
  end
end
