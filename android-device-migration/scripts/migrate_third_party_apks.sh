#!/usr/bin/env bash
set -u

dry_run=0
if [[ $# -eq 3 && $1 == "--dry-run" ]]; then
  dry_run=1
  src=$2
  dst=$3
elif [[ $# -eq 2 ]]; then
  src=$1
  dst=$2
else
  echo "用法: $0 [--dry-run] SOURCE_SERIAL TARGET_SERIAL" >&2
  exit 2
fi

work=${WORKDIR:-"$PWD/android-apk-migration-$(date +%Y%m%d-%H%M%S)"}
report="$work/report.tsv"
exclude_regex=${EXCLUDE_REGEX:-'^(com\.samsung|com\.sec\.|com\.sohu\.inputmethod\.sogou\.samsung|com\.google\.android\.apps\.agentspace|com\.google\.android\.syncadapters\.calendar|org\.chromium\.webapk\.)'}
mkdir -p "$work"
printf 'status\tpackage\tdetail\n' > "$report"

comm -23 \
  <(adb -s "$src" shell pm list packages -3 --user 0 </dev/null | sed 's/^package://' | sort) \
  <(adb -s "$dst" shell pm list packages -3 --user 0 </dev/null | sed 's/^package://' | sort) \
  | rg -v "$exclude_regex" \
  > "$work/pending.txt"

while IFS= read -r pkg; do
  dir="$work/apks/$pkg"
  mkdir -p "$dir"
  if [[ "$dry_run" -eq 1 ]]; then
    printf 'planned\t%s\tdry_run\n' "$pkg" >> "$report"
    continue
  fi
  mapfile -t paths < <(adb -s "$src" shell pm path --user 0 "$pkg" </dev/null | sed 's/^package://' | tr -d '\r')
  if [[ "${#paths[@]}" -eq 0 ]]; then
    printf 'failed\t%s\tsource_apk_path_unavailable\n' "$pkg" >> "$report"
    continue
  fi
  ok=1
  for i in "${!paths[@]}"; do
    adb -s "$src" pull "${paths[$i]}" "$dir/$i.apk" </dev/null >/dev/null 2>&1 || ok=0
  done
  if [[ "$ok" -ne 1 ]]; then
    printf 'failed\t%s\tapk_pull_failed\n' "$pkg" >> "$report"
    continue
  fi
  result=$(adb -s "$dst" install-multiple -r "$dir"/*.apk </dev/null 2>&1)
  if printf '%s' "$result" | rg -q '^Success'; then
    printf 'installed\t%s\t%s_apk_parts\n' "$pkg" "${#paths[@]}" >> "$report"
  else
    printf 'failed\t%s\t%s\n' "$pkg" "$(printf '%s' "$result" | tr '\n' ' ' | cut -c1-400)" >> "$report"
  fi
done < "$work/pending.txt"

echo "报告: $report"
awk -F'\t' 'NR>1 {count[$1]++} END {for (s in count) print s, count[s]}' "$report" | sort
