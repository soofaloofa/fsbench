deps:
	bash install.sh --fuse-version 2 --with-fio --with-libunwind

gen-bench-files:
	fio --directory=. --filename=bench5MB.bin fio/read/seq_read_small.fio
	fio --directory=. --filename=bench100GB.bin fio/read/seq_read.fio

sync:
	rsync -aP --exclude .git --exclude .github ./ cloud9:~/environment/fsbench
