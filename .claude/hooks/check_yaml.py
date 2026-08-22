"""YAML の構文だけを検査する。post-edit-check.sh から呼ばれる。"""

import sys

import yaml

try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        yaml.safe_load(fh)
except yaml.YAMLError as exc:
    print(str(exc).strip())
    sys.exit(1)
