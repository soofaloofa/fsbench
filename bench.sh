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

RESULTS_DIR=results
ITERATIONS=10

# Parse options
while getopts ":t" opt; do
  case ${opt} in
    t )
      ITERATIONS=$OPTARG
      ;;
   \? )
     echo "Invalid Option: -$OPTARG" 1>&2
     exit 1
     ;;
  esac
done
shift $((OPTIND -1))

JOB_FILE=$1
if [[ -z "${JOB_FILE}" ]]; then
  echo "Usage:"
  echo "    bench <job_file>    Run FIO job at <job_file>."
  exit 0
fi

if [[ ! -f "${JOB_FILE}" ]]; then
  echo "Job file at ${JOB_FILE} does not."
  exit 1
fi


rm -rf ${RESULTS_DIR}
mkdir -p ${RESULTS_DIR}

run_fio_job() {
  job_file=$1
  bench_file=$2
  mount_dir=$3
  iterations=$4

  echo "run_fio_job"
  echo ${job_file}
  echo ${bench_file}
  echo ${mount_dir}
  echo ${iterations}

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
      --filename=${bench_file} \
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

# set bench file
bench_file=${BENCH_FILE}
# run against small file if the job file ends with small.fio
if [[ $job_file == *small.fio ]]; then
  bench_file=${SMALL_BENCH_FILE}
fi

# if [[ ! -f "${bench_file}" ]]; then
#   echo "Bench file ${bench_file} not found"
#   exit 1
# fi

# run the benchmark
echo $JOB_FILE
echo $bench_file
echo $ITERATIONS
echo $RESULTS_DIR

run_fio_job $JOB_FILE $bench_file $MOUNT_DIR $ITERATIONS
