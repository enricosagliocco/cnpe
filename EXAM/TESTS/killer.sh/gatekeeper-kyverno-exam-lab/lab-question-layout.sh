#!/usr/bin/env bash

prepare_question_layout() {
  local course_dir="$1"
  local questions_file="$2"
  local number directory heading output

  for number in $(seq 1 20); do
    directory="$(printf '%02d' "$number")"
    mkdir -p "$course_dir/$directory"
    rm -f "$course_dir/$directory/QUESTION.md"
    touch "$course_dir/$directory/evidence.txt"
  done

  awk -v course_dir="$course_dir" '
    /^### Q[0-9]+ (–|-)/ {
      heading = $0
      sub(/^### Q/, "", heading)
      split(heading, fields, " ")
      question = sprintf("%02d", fields[1])
      output = course_dir "/" question "/QUESTION.md"
      print $0 > output
      next
    }
    /^### / { question = "" }
    question != "" { print $0 > output }
  ' "$questions_file"

  {
    echo "# Question index"
    echo
    for number in $(seq 1 20); do
      directory="$(printf '%02d' "$number")"
      [ -s "$course_dir/$directory/QUESTION.md" ] || return 1
      heading="$(head -n 1 "$course_dir/$directory/QUESTION.md")"
      printf -- '- [%s](%s/QUESTION.md)\n' "${heading#\#\#\# }" "$directory"
    done
  } > "$course_dir/questions-index.md"
}
