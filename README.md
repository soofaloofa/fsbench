## Benchmarking

Mountpoint for Amazon S3 is a simple, high-throughput file client for
mounting an Amazon S3 bucket as a local file system. To avoid new changes
introducing performance regressions, we run a performance benchmark on
every commit using [fio](https://github.com/axboe/fio), an awesome
open-source application for file system benchmarking.

### Workloads

***read workload*** - we measure two aspects of the read operation,
throughput and latency. For the first part, we use fio to simulate IO
workloads for sequential read or random read for a specific duration then
measure their throughput. On the latency side, we are using time to first
byte as data points by running workloads that read one byte off of
existing files on Mountpoint and measure the time it takes to complete
the operation. Each of the test is defined in a separate .fio file, and
the file name indicates what is the test case for that file, for example
`seq_read.fio` is the benchmark for sequential read. All of fio
configuration files can be found at path
[fio/read/](../fio/read) and
[fio/read_latency/](../fio/read_latency).

In general, we run each IO operation for 30 seconds against a 100 GiB
file. But there are some variants in configuration where we also want to
test to see how Mountpoint would perform with these configurations. Here
is the list of all the variants we have tested.

* **four_threads**: running the workload concurrently by spawning four
  fio threads to do the same job.
* **direct_io**: bypassing kernel page cache by opening the files with
  `O_DIRECT` option. This option is only available on Linux.
* **small_file**: run the IO operation against smaller files (5 MiB
  instead of 100 GiB).

***readdir workload*** - we measure how long it takes to run `ls` command
against directories with different size. Each directory has no
subdirectory and contains a specific number of files, range from 100 to
100000 files, which we have to create manually using fio then upload them
to S3 bucket before running the benchmark. The fio configuration files
for creating them can be found at path
[fio/create/](../fio/create).

***write workload*** - we measure write throughput by using fio to
simulate sequential write workloads. The fio configuration files for
write workloads can be found at path
[fio/write/](../fio/write).

### Running the benchmark

You can use the following steps to run the benchmark.

1. Install dependencies and configure FUSE by running the following
   script in the repository:

        bash install.sh \
                --fuse-version 2 \
                --with-fio --with-libunwind

2. Set environment variables related to the benchmark. There are four
   required environment variables you need to set in order to run the
   benchmark.

        export BENCH_DIR=directory_name
        export BENCH_FILE=bench_file_name
        export SMALL_BENCH_FILE=small_bench_file_name

3. Create the bench files manually in your bucket. The size of the files
   must be exactly the same as the size defined in fio configuration
   files. The easiest way to do this is running fio against your local
   file system first to let fio create the files for you, and then upload
   them to your S3 bucket using the AWS CLI. For example:

        fio --directory=your_local_dir --filename=your_file_name fio/read/seq_read_small.fio
        aws s3 cp your_local_dir/your_file_name s3://${S3_BUCKET_NAME}/${S3_BUCKET_TEST_PREFIX}

4. Run the benchmark script for [throughput](../fsbench.sh) or
   [latency](../fsbench_latency.sh).

        ./fsbench.sh

5. You should see the benchmark logs in `bench.out` file in the project
   root directory. The combined results will be saved into a JSON file at
   `results/output.json`.
