#!/usr/bin/env bash
FORGE_ANSWER=42

calculate_answer() {
  printf '%s\n' "$(($1 * 2))"
}
