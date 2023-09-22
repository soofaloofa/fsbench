## Benchmarking

File system benchmarking using [fio](https://github.com/axboe/fio), an
awesome open-source application.

### Workloads

***read workload*** - we measure two aspects of the read operation,
throughput and latency. For the first part, we use fio to simulate IO
workloads for sequential read or random read for a specific duration then
measure their throughput. On the latency side, we are using time to first
byte as data points by running workloads that read one byte off of
existing files and measure the time it takes to complete the operation.
Each of the test is defined in a separate .fio file, and the file name
indicates what is the test case for that file, for example `seq_read.fio`
is the benchmark for sequential read. All of fio configuration files can
be found at path [fio/read/](./fio/read) and
[fio/read_latency/](./fio/read_latency).

In general, we run each IO operation for 30 seconds against a 5 MB and
100 GiB file.

* **four_threads**: running the workload concurrently by spawning four
  fio threads to do the same job.
* **direct_io**: bypassing kernel page cache by opening the files with
  `O_DIRECT` option. This option is only available on Linux.
* **small_file**: run the IO operation against smaller files (5 MiB
  instead of 100 GiB).

***write workload*** - we measure write throughput by using fio to
simulate sequential write workloads. The fio configuration files for
write workloads can be found at path
[fio/write/](./fio/write).

### Running the benchmark

You can use the following steps to run the benchmark.

1. Install dependencies and configure FUSE by running the following
   script in the repository:

   ```bash
   make install-deps
   ```

   or

   ```bash
   bash install.sh \
           --fuse-version 2 \
           --with-fio --with-libunwind
   ```

2. Create the bench files manually. The size of the files
   must be exactly the same as the size defined in fio configuration
   files. The easiest way to do this is running fio against your local
   file system first to let fio create the files for you. If benchmarking
   mountpoint-s3, upload them to your S3 bucket using the AWS
   CLI. For example:

   ```bash
   fio --directory=your_local_dir --filename=your_file_name fio/read/seq_read_small.fio
   ```

   If you are benchmarking
   [mountpoint-s3](https://github.com/awslabs/mountpoint-s3/), upload the
   files to the S3 bucket you are testing.

   ```bash
   aws s3 cp your_local_dir/your_file_name s3://${S3_BUCKET_NAME}
   ```

3. Set environment variables related to the benchmark. There are three
   required environment variables you need to set in order to run the
   benchmark.

   ```bash
   export MOUNT_DIR=directory_name_of_mounted_filesystem
   export BENCH_FILE=bench_file_name
   export SMALL_BENCH_FILE=small_bench_file_name
   ```

4. Run the benchmark script.

   ```bash
   ./fsbench.sh
   ```

5. You should see the benchmark logs. The combined results will be saved
   into a JSON file at `results/output.json`.
