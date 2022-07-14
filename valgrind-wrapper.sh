#!/bin/bash

# valgrind_wrapper.sh runs valgrind on a binary, and also:
# 1) Adds a bunch of handy options (see below)
# 2) Kills (sends SIGINT) the executable if it's running too long
# 3) Checks for file descriptor leaks, exiting (non-zero) error code if they've been found
# This wrapper exits with code 1 if valgrind has detected some problems in the code, or 2 if internal error occurred

EXIT_CODE_SUCCESS=0
EXIT_CODE_PROBLEMS_FOUND=1
EXIT_CODE_INTERNAL_ERROR=2

# Usage: fail "message" [error_code]
function fail {
    printf '%s\n' "$1" >&2 ## Send message to stderr.
    exit "${2-1}" ## Return a code from arg $2, or 1 by default.
}

# Expect two arguments
[[ $# -ne 2 ]] && fail "usage: $0 binary_file timeout_seconds" 2
BINARY=$1
SECONDS=$2

# Write valgrind output to file
stderr_file='/tmp/valgrind_stderr.log'

# Run valgrind with a timeout
timeout --preserve-status --signal=SIGINT $SECONDS \
    valgrind --leak-check=full   \
         --error-exitcode=1      \
         --show-leak-kinds=all   \
         --track-origins=yes     \
         --track-fds=yes         \
         --quiet                 \
         --log-file=$stderr_file \
         $BINARY

# Check if valgrind has detected any memory problems
if [[ $? -ne 0 ]]; then
  cat $stderr_file >/dev/stderr
  exit $EXIT_CODE_PROBLEMS_FOUND
fi

# Check FD leaks: because we redirect valgrind to file, this adds one extra open FD at exit
# (see https://stackoverflow.com/questions/72977881/valgrind-track-fds-yes-exit-code-0-even-when-there-are-fd-leaks).
# So the amount of (opened file descriptors) minus (opened std file descriptors) should be exactly one; otherwise, there's a leak.
# ==874818== FILE DESCRIPTORS: 4 open (3 std) at exit. -- valgrind 3.17.0
#                              ^-f4    ^-f6
pattern="== FILE DESCRIPTORS: [0-9]\+ open"
cat $stderr_file | grep "$pattern" >/dev/null || fail "FILE DESCRIPTORS pattern not found in $stderr_file" $EXIT_CODE_INTERNAL_ERROR
num_open=$(cat $stderr_file | grep "$pattern" | cut -d " " -f 4)
num_std=$(cat $stderr_file | grep "$pattern" | cut -d " " -f 6 | cut -c2-)
num_leaked=$(($num_open - $num_std - 1))

if [[ $num_leaked -ne 0 ]]; then
  echo "Valgrind detected $num_leaked file descriptor(s) leaked (besides $num_std std and one $stderr_file)" >/dev/stderr
  cat $stderr_file >/dev/stderr
  exit $EXIT_CODE_PROBLEMS_FOUND
fi

exit $EXIT_CODE_SUCCESS
