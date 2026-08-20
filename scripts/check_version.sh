#!/usr/bin/env bash
# Version single-source-of-truth guard.
#
# SoT = pubspec.yaml `version:`. This asserts the README version badge and the
# newest CHANGELOG entry match it, so the three can't drift again (they had:
# pubspec 1.3.0 / README 1.2.0 / commit msgs "Ver 1.0.6"). Wire into CI.
set -euo pipefail
cd "$(dirname "$0")/.."

pub_ver="$(grep -m1 '^version:' pubspec.yaml | sed -E 's/^version:[[:space:]]*//; s/\+.*$//' | tr -d '[:space:]')"
if [ -z "$pub_ver" ]; then
  echo "check_version: could not read version from pubspec.yaml" >&2
  exit 2
fi

fail=0

# README shields.io badge: .../badge/version-X.Y.Z-...
readme_ver="$(grep -oE 'badge/version-[0-9]+\.[0-9]+\.[0-9]+' README.md | head -1 | sed -E 's#badge/version-##')"
if [ "$readme_ver" != "$pub_ver" ]; then
  echo "check_version: README badge ($readme_ver) != pubspec ($pub_ver)" >&2
  fail=1
fi

# Newest concrete CHANGELOG entry (skip [Unreleased]).
changelog_ver="$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | head -1 | sed -E 's/^## \[//; s/\]//')"
if [ "$changelog_ver" != "$pub_ver" ]; then
  echo "check_version: newest CHANGELOG entry ($changelog_ver) != pubspec ($pub_ver)" >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "check_version: FAILED — align all to pubspec $pub_ver" >&2
  exit 1
fi
echo "check_version: OK — version $pub_ver consistent across pubspec, README, CHANGELOG"
