"""Validate this skill package's structure; this is not a SQL compiler."""

from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

import yaml


def validate(root: Path) -> list[str]:
    errors = []
    entry = root / "SKILL.md"
    if not entry.is_file():
        return ["Missing SKILL.md"]
    text = entry.read_text(encoding="utf-8")
    frontmatter = re.match(r"\A---\n(.*?)\n---(?:\n|$)", text, re.S)
    if frontmatter is None:
        return ["Missing or malformed frontmatter"]
    try:
        metadata = yaml.safe_load(frontmatter.group(1))
    except yaml.YAMLError:
        return ["Invalid frontmatter YAML"]
    if not isinstance(metadata, dict):
        return ["Frontmatter must be a mapping"]
    name = metadata.get("name")
    description = metadata.get("description")
    if not isinstance(name, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
        errors.append("Skill name must be lowercase hyphen-case")
    elif len(name) > 64:
        errors.append("Skill name exceeds 64 characters")
    if not isinstance(description, str) or not description.strip() or len(description) > 1024:
        errors.append("Description must be nonempty and at most 1024 characters")
    allowed = {"name", "description", "license", "allowed-tools", "metadata"}
    if metadata.keys() - allowed:
        errors.append("Unsupported frontmatter keys")

    interface_path = root / "agents" / "openai.yaml"
    try:
        config = yaml.safe_load(interface_path.read_text(encoding="utf-8"))
        interface = config["interface"]
        for key in ("display_name", "short_description", "default_prompt"):
            if not isinstance(interface.get(key), str) or not interface[key].strip():
                errors.append(f"Missing UI field: {key}")
        short = interface.get("short_description", "")
        if isinstance(short, str) and not 25 <= len(short) <= 64:
            errors.append("UI short_description must be 25-64 characters")
        prompt = interface.get("default_prompt", "")
        if isinstance(name, str) and (not isinstance(prompt, str) or f"${name}" not in prompt):
            errors.append("UI prompt must mention the skill name")
    except (OSError, yaml.YAMLError, KeyError, TypeError, AttributeError):
        errors.append("Missing or malformed agents/openai.yaml")

    for path in sorted(root.rglob("*.md")):
        if any(part in {".git", ".venv", "__pycache__"} for part in path.relative_to(root).parts):
            continue
        content = path.read_text(encoding="utf-8")
        if "[TODO:" in content:
            errors.append(f"Unfinished scaffold in {path.relative_to(root)}")
        for target in re.findall(r"\[[^\]]*\]\(([^)\s]+)\)", content):
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            resolved = (path.parent / unquote(parsed.path)).resolve()
            if not resolved.is_relative_to(root.resolve()):
                errors.append(f"Local link leaves package: {target}")
            elif not resolved.exists():
                errors.append(f"Broken link in {path.relative_to(root)}: {target}")

    ddl_path = root / "assets" / "doris" / "ddl.sql"
    etl_path = root / "assets" / "doris" / "daily-etl.sql"
    if not ddl_path.is_file() or not etl_path.is_file():
        errors.append("Missing Doris DDL or ETL assets")
        return errors
    ddl = ddl_path.read_text(encoding="utf-8")
    table_pattern = (
        r"CREATE TABLE\s+([\w.]+)\s*\((.*?)\)\s*ENGINE=OLAP\s*"
        r"(?:DUPLICATE|UNIQUE|AGGREGATE)\s+KEY\s*\(([^)]+)\)"
    )
    tables = {}
    for match in re.finditer(table_pattern, ddl, re.S | re.I):
        table, definitions, keys = match.groups()
        columns = [line.strip().split()[0] for line in definitions.splitlines() if line.strip()]
        key_columns = [key.strip() for key in keys.split(",")]
        if columns[:len(key_columns)] != key_columns:
            errors.append(f"Key columns are not a matching column prefix: {table}")
        if len(columns) != len(set(columns)):
            errors.append(f"Duplicate column names: {table}")
        tables[table] = set(columns)
    if len(tables) != len(re.findall(r"\bCREATE TABLE\b", ddl, re.I)):
        errors.append("Some Doris CREATE TABLE statements could not be structurally checked")
    etl = etl_path.read_text(encoding="utf-8")
    insert_pattern = r"INSERT OVERWRITE TABLE\s+([\w.]+)\s+PARTITION\s*\([^)]+\)\s*\(([^)]+)\)"
    writes = list(re.finditer(insert_pattern, etl, re.S | re.I))
    if len(writes) != len(re.findall(r"\bINSERT OVERWRITE TABLE\b", etl, re.I)):
        errors.append("Every Doris overwrite template must have explicit partition and columns")
    for match in writes:
        table, names = match.groups()
        columns = [column.strip() for column in names.split(",")]
        if table not in tables or not set(columns) <= tables[table]:
            errors.append(f"Overwrite references an unknown table or column: {table}")
        if len(columns) != len(set(columns)) or "dt" not in columns:
            errors.append(f"Overwrite has duplicate columns or omits dt: {table}")
    return errors


if __name__ == "__main__":
    package = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    failures = validate(package)
    for failure in failures:
        print(f"FAIL: {failure}")
    if failures:
        sys.exit(1)
    print("PASS: skill structure, internal links, and Doris template structural checks")
    print("NOT_RUN: Doris compilation and native execution")
