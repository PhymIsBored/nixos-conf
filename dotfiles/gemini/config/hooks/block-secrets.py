#!/usr/bin/env python3
"""PreToolUse hook to block access to .env and common secret files."""

import glob
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

QUOTE_CHARS = "\"'`"
COMMAND_STRIP_CHARS = QUOTE_CHARS + ",:;}]["


def exists(path: str, cwd: str) -> bool:
    full = os.path.join(cwd, path)
    if any(c in path for c in "*?["):
        return bool(glob.glob(full))
    return os.path.exists(full)


def is_secret_path(raw: str, *, cwd: str | None = None) -> str | None:
    """Return a reason string if raw looks like a secret file or path, else None.

    cwd is set for tokens taken from shell commands: suffix-only matches
    (.key/.pem/...) are then only denied if the file actually exists, since
    command text is full of things like `item.key` that aren't paths.
    """
    if not isinstance(raw, str):
        return None

    candidate = raw.strip().strip(
        COMMAND_STRIP_CHARS if cwd is not None else QUOTE_CHARS
    )
    candidate = candidate.removeprefix("file://")
    if not candidate:
        return None

    normalized = os.path.expanduser(candidate)
    path = PurePosixPath(normalized)
    base = path.name.lower()

    if base.endswith(".pub") or base in ALLOWED_ENV_NAMES:
        return None

    if ".ssh" in path.parts:
        return f"access to .ssh path ({candidate}) is restricted"

    for sub in SECRET_PATH_SUBSTRINGS:
        if sub in normalized or normalized.endswith(sub):
            return f"access to credential path ({candidate}) is restricted"

    if base == ".env" or base.startswith(".env."):
        return f"access to environment file ({candidate}) is restricted"

    if base in SECRET_EXACT_NAMES:
        return f"access to secret/key file ({candidate}) is restricted"

    if (
        base.endswith(SECRET_SUFFIXES)
        and not base.startswith(".")
        and (cwd is None or exists(normalized, cwd))
    ):
        return f"access to private key/certificate file ({candidate}) is restricted"

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


def check_command(command_line: str, cwd: str) -> str | None:
    """Inspect shell command tokens for references to secret files."""
    if not isinstance(command_line, str) or not command_line:
        return None

    try:
        tokens = shlex.split(command_line)
    except ValueError:
        tokens = command_line.split()

    for token in tokens:
        for part in re.split(r"[\s=<>|;&(){}\[\],]+", token):
            reason = is_secret_path(part, cwd=cwd)
            if reason:
                return reason
    return None


def decide(payload: dict) -> str | None:
    tool_call = payload.get("toolCall") or {}
    tool_name = (tool_call.get("name") or "").lower()
    args = tool_call.get("args") or {}
    if isinstance(args, str):
        try:
            args = json.loads(args)
        except json.JSONDecodeError:
            args = {"CommandLine": args}
    if not isinstance(args, dict):
        return None

    if tool_name in {"run_command", "shell_exec"}:
        cmd = args.get("CommandLine") or args.get("command") or args.get("cmd") or ""
        cwd = args.get("Cwd") or payload.get("cwd") or os.getcwd()
        return check_command(cmd, str(cwd).strip(QUOTE_CHARS))

    for path_val in iter_path_values(args):
        reason = is_secret_path(path_val)
        if reason:
            return reason
    return None


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        print(json.dumps({"decision": "allow"}))
        return 0

    try:
        reason = decide(payload) if isinstance(payload, dict) else None
    except Exception as exc:  # noqa: BLE001 - fail closed, but say why
        reason = f"block-secrets hook error: {type(exc).__name__}: {exc}"

    if reason:
        print(json.dumps({"decision": "deny", "reason": reason}))
    else:
        print(json.dumps({"decision": "allow"}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
