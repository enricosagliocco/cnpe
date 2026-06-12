#!/usr/bin/env bash

prepare_question_layout() {
  local course_dir="$1"
  local questions_file="$2"
  local directory_style="${3:-padded}"
  local question_count
  local directory
  local number
  local heading

  [ -f "$questions_file" ] || {
    echo "[ERR] questions file not found: $questions_file" >&2
    return 1
  }

  question_count="$(
    awk '/^### Q[0-9]+ - / { count++ } END { print count + 0 }' \
      "$questions_file"
  )"
  [ "$question_count" -gt 0 ] || {
    echo "[ERR] no questions found in $questions_file" >&2
    return 1
  }

  for number in $(seq 1 "$question_count"); do
    if [ "$directory_style" = "plain" ]; then
      directory="$number"
    else
      directory="$(printf '%02d' "$number")"
    fi
    mkdir -p "$course_dir/$directory"
    rm -f "$course_dir/$directory/QUESTION.md"
    touch "$course_dir/$directory/evidence.txt"
  done

  awk -v course_dir="$course_dir" -v directory_style="$directory_style" '
    /^### Q[0-9]+ - / {
      heading = $0
      sub(/^### Q/, "", heading)
      split(heading, fields, " ")
      if (directory_style == "plain") {
        question = fields[1] + 0
      } else {
        question = sprintf("%02d", fields[1])
      }
      output = course_dir "/" question "/QUESTION.md"
      print $0 > output
      next
    }
    /^## Soluzioni/ {
      question = ""
      next
    }
    /^### / {
      question = ""
    }
    question != "" {
      print $0 > output
    }
  ' "$questions_file"

  {
    echo "# Question index"
    echo
    for number in $(seq 1 "$question_count"); do
      if [ "$directory_style" = "plain" ]; then
        directory="$number"
      else
        directory="$(printf '%02d' "$number")"
      fi
      if [ ! -s "$course_dir/$directory/QUESTION.md" ]; then
        echo "[ERR] Q${number#0} was not extracted from $questions_file" >&2
        return 1
      fi
      heading="$(head -n 1 "$course_dir/$directory/QUESTION.md")"
      heading="${heading#\#\#\# }"
      printf -- '- [%s](%s/QUESTION.md)\n' "$heading" "$directory"
    done
  } > "$course_dir/questions-index.md"
}
