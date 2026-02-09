#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob dotglob

usage() {
  cat <<'EOF'
Usage:
  99_admin/scripts/organize_task.sh --task <task_dir> [--apply]

Description:
  Organize messy task root files into a standard structure with emphasis on:
  - code/
  - output/

Default mode is dry-run (no files moved).

Options:
  --task <task_dir>   Task folder to organize (example: 01_tasks/mit)
  --apply             Execute moves (without this flag, only preview)
  -h, --help          Show this help
EOF
}

TASK_DIR=""
APPLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)
      if [[ $# -lt 2 ]]; then
        echo "Error: --task requires a value." >&2
        exit 1
      fi
      TASK_DIR="$2"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'." >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$TASK_DIR" ]]; then
  echo "Error: --task is required." >&2
  usage >&2
  exit 1
fi

if [[ ! -d "$TASK_DIR" ]]; then
  echo "Error: task directory not found: $TASK_DIR" >&2
  exit 1
fi

TASK_DIR="${TASK_DIR%/}"
LOG_FILE="$TASK_DIR/output/logs/organize_task.log"

standard_dirs=(
  "code/python"
  "code/r"
  "code/stata"
  "code/matlab"
  "code/notebooks"
  "code/sql"
  "code/shell"
  "code/other"
  "output/figures"
  "output/tables"
  "output/reports"
  "output/logs"
  "output/other"
  "docs/instructions"
  "docs/notes"
  "data/raw"
  "data/processed"
  "archive/zips"
  "archive/legacy_root"
)

if [[ "$APPLY" -eq 1 ]]; then
  for d in "${standard_dirs[@]}"; do
    mkdir -p "$TASK_DIR/$d"
  done
  {
    echo "==== organize_task run: $(date '+%Y-%m-%d %H:%M:%S') ===="
    echo "Task: $TASK_DIR"
  } >> "$LOG_FILE"
fi

resolve_target_rel() {
  src_name="$1"
  lower_name="$(printf '%s' "$src_name" | tr '[:upper:]' '[:lower:]')"

  ext=""
  if [[ "$src_name" == *.* ]]; then
    ext="${lower_name##*.}"
  fi

  case "$ext" in
    py) echo "code/python"; return ;;
    ipynb) echo "code/notebooks"; return ;;
    r|rmd|qmd) echo "code/r"; return ;;
    do) echo "code/stata"; return ;;
    m) echo "code/matlab"; return ;;
    sql) echo "code/sql"; return ;;
    sh) echo "code/shell"; return ;;
  esac

  case "$ext" in
    png|jpg|jpeg|svg|gif|tif|tiff|webp|bmp)
      echo "output/figures"
      return
      ;;
    tex)
      echo "output/tables"
      return
      ;;
    log)
      echo "output/logs"
      return
      ;;
    pdf)
      if [[ "$lower_name" == *instruction* ]] || [[ "$lower_name" == *guideline* ]] || [[ "$lower_name" == *task* ]]; then
        echo "docs/instructions"
      else
        echo "output/reports"
      fi
      return
      ;;
  esac

  case "$ext" in
    md|txt|doc|docx|rtf)
      if [[ "$lower_name" == *instruction* ]] || [[ "$lower_name" == *guideline* ]] || [[ "$lower_name" == *task* ]]; then
        echo "docs/instructions"
      else
        echo "docs/notes"
      fi
      return
      ;;
  esac

  case "$ext" in
    csv|tsv|xlsx|xls|dta|rds|parquet|feather|sav)
      if [[ "$lower_name" == *clean* ]] || [[ "$lower_name" == *processed* ]] || [[ "$lower_name" == *final* ]] || [[ "$lower_name" == *merged* ]] || [[ "$lower_name" == *harmonized* ]]; then
        echo "data/processed"
      else
        echo "data/raw"
      fi
      return
      ;;
  esac

  case "$ext" in
    zip|7z|rar|tar|gz)
      echo "archive/zips"
      return
      ;;
  esac

  echo "archive/legacy_root"
}

next_available_path() {
  target="$1"
  if [[ ! -e "$target" ]]; then
    echo "$target"
    return
  fi

  filename="$(basename "$target")"
  dirpath="$(dirname "$target")"

  base="$filename"
  suffix=""
  if [[ "$filename" == *.* ]]; then
    base="${filename%.*}"
    suffix=".${filename##*.}"
  fi

  idx=1
  candidate="$dirpath/${base}_$idx$suffix"
  while [[ -e "$candidate" ]]; do
    idx=$((idx + 1))
    candidate="$dirpath/${base}_$idx$suffix"
  done
  echo "$candidate"
}

total_files=0
planned_moves=0
skipped_hidden=0

for src in "$TASK_DIR"/*; do
  if [[ ! -e "$src" ]]; then
    continue
  fi
  if [[ ! -f "$src" ]]; then
    continue
  fi

  total_files=$((total_files + 1))
  name="$(basename "$src")"
  if [[ "$name" == "." ]] || [[ "$name" == ".." ]]; then
    continue
  fi

  if [[ "$name" == .* ]]; then
    case "$name" in
      .Rhistory|.RData)
        rel_target="archive/legacy_root"
        target="$TASK_DIR/$rel_target/$name"
        target="$(next_available_path "$target")"
        planned_moves=$((planned_moves + 1))
        echo "$src -> $target"
        if [[ "$APPLY" -eq 1 ]]; then
          mv "$src" "$target"
          echo "$src -> $target" >> "$LOG_FILE"
        fi
        continue
        ;;
      *)
        skipped_hidden=$((skipped_hidden + 1))
        continue
        ;;
    esac
  fi

  rel_target="$(resolve_target_rel "$name")"
  target="$TASK_DIR/$rel_target/$name"
  target="$(next_available_path "$target")"

  planned_moves=$((planned_moves + 1))
  echo "$src -> $target"

  if [[ "$APPLY" -eq 1 ]]; then
    mv "$src" "$target"
    echo "$src -> $target" >> "$LOG_FILE"
  fi
done

echo
if [[ "$APPLY" -eq 1 ]]; then
  echo "Applied organization for: $TASK_DIR"
  echo "Moved files: $planned_moves (hidden skipped: $skipped_hidden, root files seen: $total_files)"
  echo "Log: $LOG_FILE"
else
  echo "Dry-run only for: $TASK_DIR"
  echo "Planned moves: $planned_moves (hidden skipped: $skipped_hidden, root files seen: $total_files)"
  echo "Run with --apply to execute."
fi
