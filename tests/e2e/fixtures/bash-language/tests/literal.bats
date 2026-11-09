#!/usr/bin/env bats

@test "literal [a+b]?.ü" {
  printf 'BATS_LITERAL ü\n'
  [ 42 -eq 42 ]
}

@test "literal [a+b]?.ü neighbor" {
  printf yes >"${BATS_TEST_DIRNAME}/../literal-neighbor-ran.txt"
  false
}
