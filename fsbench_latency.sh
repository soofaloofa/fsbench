#!/bin/bash

if ! command -v fio &> /dev/null; then
  echo "fio must be installed to run this benchmark"
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

rm -rf ${results_dir}
mkdir -p ${results_dir}

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

  jq -n 'inputs.jobs[] | if (."job options".rw == "read")
    then {name: .jobname, value: (.read.lat_ns.mean / 1000000), unit: "milliseconds"}
    elif (."job options".rw == "randread") then {name: .jobname, value: (.read.lat_ns.mean / 1000000), unit: "milliseconds"}
    elif (."job options".rw == "randwrite") then {name: .jobname, value: (.write.lat_ns.mean / 1000000), unit: "milliseconds"}
    else {name: .jobname, value: (.write.lat_ns.mean / 1000000), unit: "milliseconds"} end' ${results_dir}/${job_name}.json | tee ${results_dir}/${job_name}_parsed.json

done

# combine all bench results into one json file
jq -n '[inputs]' ${results_dir}/*.json | tee ${results_dir}/output.json
