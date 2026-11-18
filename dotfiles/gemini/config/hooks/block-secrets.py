#!/usr/bin/env python3
"""PreToolUse hook to block access to .env and common secret files."""

import json
import os
import re
import shlex
import sys
from pathlib import PurePosixPath

ALLOWED_ENV_NAMES = {
    ".env.example",
    ".env.sample",
    ".env.template",
    ".env.dist",
}

SECRET_EXACT_NAMES = {
    ".env",
    ".netrc",
    ".npmrc",
    ".pypirc",
    ".pgpass",
    ".htpasswd",
    "id_rsa",
    "id_dsa",
    "id_ecdsa",
    "id_ed25519",
    "id_ecdsa_sk",
    "id_ed25519_sk",
}

SECRET_SUFFIXES = (".pem", ".key", ".p12", ".pfx")

SECRET_PATH_SUBSTRINGS = (
    "/.ssh/",
    "/.aws/credentials",
    "/.kube/config",
    "/.docker/config.json",
)

PATH_ARG_KEYS = {
    "path",
    "file_path",
    "filepath",
    "target_file",
    "targetfile",
    "absolute_path",
    "absolutepath",
    "search_path",
    "searchpath",
    "directory_path",
    "directorypath",
    "search_directory",
    "searchdirectory",
    "source",
    "destination",
    "source_path",
    "dest_path",
    "notebook_path",
    "notebookpath",
    "uri",
    "target_path",
    "output_path",
}


def is_secret_path(raw: str, *, from_command: bool = False) -> str | None:
    """Return a reason string if raw looks like a secret file or path, else None."""
    if not raw or not isinstance(raw, str):
        return None

    candidate = raw.strip()
    if from_command:
        candidate = candidate.strip("\"'`,:;}][")
    if not candidate:
        return None
    candidate = candidate.removeprefix("file://")

    expanded = os.path.expanduser(candidate)
    normalized = expanded.replace("\\", "/")
    parts = PurePosixPath(normalized).parts
    base = PurePosixPath(normalized).name.lower()

    if ".ssh" in parts:
        return f"access to .ssh path ({raw}) is restricted"

    for sub in SECRET_PATH_SUBSTRINGS:
        if sub in normalized or normalized.endswith(sub.rstrip("/")):
            return f"access to credential path ({raw}) is restricted"

    if base in ALLOWED_ENV_NAMES or base.endswith(".pub"):
        return None

    if base == ".env" or base.startswith(".env."):
        return f"access to environment file ({raw}) is restricted"

    if base in SECRET_EXACT_NAMES:
        return f"access to secret/key file ({raw}) is restricted"

    for suffix in SECRET_SUFFIXES:
        if base.endswith(suffix) and len(base) > len(suffix):
            # Avoid false positives on jq selectors like `.key` or `.value.key`.
            if from_command and base.startswith("."):
                continue
            return f"access to private key/certificate file ({raw}) is restricted"

    return None


def iter_path_values(obj: object):
    """Yield string values for path-like keys in nested tool arguments."""
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key.lower() in PATH_ARG_KEYS and isinstance(value, str):
                yield value
            else:
                yield from iter_path_values(value)
    elif isinstance(obj, list):
        for item in obj:
            yield from iter_path_values(item)


def check_command(command_line: str) -> str | None:
    """Inspect shell command tokens for references to secret files."""
    if not command_line:
        return None

    try:
        tokens = shlex.split(command_line)
    except ValueError:
        tokens = command_line.split()

    for token in tokens:
        for part in re.split(r"[\s=<>|;&(){}\[\],]+", token):
            if not part:
                continue
            reason = is_secret_path(part, from_command=True)
            if reason:
                return reason
    return None


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        print(json.dumps({"decision": "allow"}))
        return 0

    tool_call = payload.get("toolCall") or {}
    tool_name = (tool_call.get("name") or "").lower()
    args = tool_call.get("args") or {}

    reason = None
    if tool_name in {"run_command", "shell_exec"}:
        cmd = args.get("CommandLine") or args.get("command") or args.get("cmd") or ""
        reason = check_command(cmd)
    else:
        for path_val in iter_path_values(args):
            reason = is_secret_path(path_val)
            if reason:
                break

    if reason:
        print(json.dumps({"decision": "deny", "reason": reason}))
    else:
        print(json.dumps({"decision": "allow"}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
