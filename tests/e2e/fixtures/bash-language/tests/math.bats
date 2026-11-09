#!/usr/bin/env bats
source "${BATS_TEST_DIRNAME}/../lib/math.sh"

@test "test_nearest_pass" {
  value=$(calculate_answer 21)
  printf 'BASH_TEST_VALUE %s\n' "$value"
  [ "$value" -eq 42 ]
}

function test_nearest_pass_neighbor_fail { # @test
  printf yes >"${BATS_TEST_DIRNAME}/../neighbor-ran.txt"
  [ 1 -eq 2 ]
}
