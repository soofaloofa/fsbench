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

# start readdir benchmarking
dir_size=100
while [ $dir_size -le 100000 ]
do
    sum=0
    job_name="readdir_${dir_size}"
    target_dir="${MOUNT_DIR}/bench_dir_${dir_size}"
    startdelay=30

    echo "Running ${job_name}"

    # verify that the target directory exists before running the benchmark
    if [ ! -d "${target_dir}" ]; then
      echo "Target directory ${target_dir} does not exist."
      exit 1
    fi

    sleep $startdelay
    # run each case for 10 iterations
    iteration=10
    for i in $(seq 1 $iteration);
    do
        /usr/bin/time -o ${results_dir}/time_output.txt -v ls -f "${target_dir}" >/dev/null 2>&1

        elapsed_time=$(awk '/Elapsed/ {print $8}' ${results_dir}/time_output.txt)

        # the result has m:ss format so we will split it into two parts and convert them to seconds
        IFS=':'; splitted_time=($elapsed_time); unset IFS;
        minutes=${splitted_time[0]}
        seconds=${splitted_time[1]}
        elapsed_time=$(awk "BEGIN {print ($minutes*60)+$seconds}")

        sum=$(awk "BEGIN {print $sum+$elapsed_time}")

        # pause for a while before running next iteration
        sleep 1
    done
    average=$(awk "BEGIN {print $sum/$iteration}")
    # now convert it to json
    json_data="{\"name\":\"$job_name\",\"value\":$average,\"unit\":\"seconds\"}"
    echo $json_data | jq '.' | tee ${results_dir}/${job_name}.json

    # cleanup mount directory
    rm -rf ${MOUNT_DIR}

    # increase directory size
    dir_size=$(awk "BEGIN {print $dir_size*10}")
done


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

  # delete the raw output file from fio
  rm ${results_dir}/${job_name}.json
done

# combine all bench results into one json file
jq -n '[inputs]' ${results_dir}/*.json | tee ${results_dir}/output.json
