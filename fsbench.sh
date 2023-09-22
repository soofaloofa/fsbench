#!/bin/bash
set -e

if ! command -v fio &> /dev/null; then
  echo "fio must be installed to run this benchmark"
  exit 1
fi
if ! command -v jq &> /dev/null; then
  echo "jq must be installed to run this benchmark"
  exit 1
fi

if [[ -z "${MOUNT_DIR}" ]]; then
  echo "Set MOUNT_DIR to run this benchmark"
  exit 1
fi

if [[ -z "${BENCH_FILE}" ]]; then
  echo "Set BENCH_FILE to run this benchmark"
  exit 1
fi

if [[ -z "${SMALL_BENCH_FILE}" ]]; then
  echo "Set SMALL_BENCH_FILE to run this benchmark"
  exit 1
fi

results_dir=results
iterations=10

rm -rf ${results_dir}
mkdir -p ${results_dir}

run_fio_job() {
  job_file=$1
  bench_file=$2
  mount_dir=$3

  job_name=$(basename "${job_file}")
  job_name="${job_name%.*}"

  echo -n "Running job ${job_name} for ${iterations} iterations... "

  for i in $(seq 1 $iterations);
  do
    echo -n "${i};"
    fio --thread \
      --output=${results_dir}/${job_name}_iter${i}.json \
      --output-format=json \
      --directory=${mount_dir} \
      --filename=${bench_file}_${i} \
      --eta=never \
      ${job_file}
  done
  echo "done"

  # combine the results and find an average value
  jq -n 'reduce inputs.jobs[] as $job (null; .name = $job.jobname | .len += 1 | .value += (if ($job."job options".rw == "read")
      then $job.read.bw / 1024
      elif ($job."job options".rw == "randread") then $job.read.bw / 1024
      elif ($job."job options".rw == "randwrite") then $job.write.bw / 1024
      else $job.write.bw / 1024 end)) | {name: .name, value: (.value / .len), unit: "MiB/s"}' ${results_dir}/${job_name}_iter*.json | tee ${results_dir}/${job_name}_parsed.json
}

read_benchmark () {
  jobs_dir=fio/read

  for job_file in "${jobs_dir}"/*.fio; do
    # set bench file
    bench_file=${BENCH_FILE}
    # run against small file if the job file ends with small.fio
    if [[ $job_file == *small.fio ]]; then
      bench_file=${SMALL_BENCH_FILE}
    fi

    # run the benchmark
    run_fio_job $job_file $bench_file $MOUNT_DIR

    # cleanup benchmark directory
    rm -rf ${MOUNT_DIR}/*
  done
}

write_benchmark () {
  jobs_dir=fio/write

  for job_file in "${jobs_dir}"/*.fio; do
    # set bench file
    bench_file=${job_name}_${RANDOM}.dat

    # run the benchmark
    run_fio_job $job_file $bench_file $MOUNT_DIR

    # cleanup benchmark directory
    rm -rf ${MOUNT_DIR}/*
  done
}

latency_benchmark () {
  # start time to first byte benchmark
  jobs_dir=fio/read_latency
  for job_file in "${jobs_dir}"/*.fio; do
    job_name=$(basename "${job_file}")
    job_name="${job_name%.*}"

    echo "Running ${job_name}"

    # set bench file
    bench_file=${BENCH_FILE}
    # run against small file if the job file ends with small.fio
    if [[ $job_file == *small.fio ]]; then
      bench_file=${SMALL_BENCH_FILE}
    fi

    fio --thread \
      --output=${results_dir}/${job_name}.json \
      --output-format=json \
      --directory=${MOUNT_DIR} \
      --filename=${bench_file} \
      ${job_file}

    # combine results
    # latency benchmark outputs in a different format
    jq -n 'inputs.jobs[] | if (."job options".rw == "read")
      then {name: .jobname, value: (.read.lat_ns.mean / 1000000), unit: "milliseconds"}
      elif (."job options".rw == "randread") then {name: .jobname, value: (.read.lat_ns.mean / 1000000), unit: "milliseconds"}
      elif (."job options".rw == "randwrite") then {name: .jobname, value: (.write.lat_ns.mean / 1000000), unit: "milliseconds"}
      else {name: .jobname, value: (.write.lat_ns.mean / 1000000), unit: "milliseconds"} end' ${results_dir}/${job_name}.json | tee ${results_dir}/${job_name}_parsed.json
  done
}

read_benchmark
write_benchmark
latency_benchmark

# combine all bench results into one json file
jq -n '[inputs]' ${results_dir}/*_parsed.json | tee ${results_dir}/output.json
