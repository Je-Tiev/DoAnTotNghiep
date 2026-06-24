"""
bundle_skills.py — Regenerate skills.json from .agents/skills/**/SKILL.md.

Walks the local .agents/skills tree (relative to this script), reads the
frontmatter `name`/`description` from each SKILL.md, and writes skills.json
with portable relative paths. Run from anywhere:

    python bundle_skills.py
"""
import os
import re
import json

HERE = os.path.dirname(os.path.abspath(__file__))
SKILLS_ROOT = os.path.join(HERE, ".agents", "skills")

skills = []
for r, _d, files in os.walk(SKILLS_ROOT):
    for f in files:
        if f != "SKILL.md":
            continue
        filepath = os.path.join(r, f)
        with open(filepath, "r", encoding="utf-8") as fh:
            content = fh.read()
        name_match = re.search(r"^name:\s*(.+)$", content, re.MULTILINE)
        desc_match = re.search(r"^description:\s*(.+)$", content, re.MULTILINE)
        if not (name_match and desc_match):
            print(f"  skip (no frontmatter): {filepath}")
            continue
        rel = os.path.relpath(filepath, HERE).replace(os.sep, "/")
        skills.append({
            "name": name_match.group(1).strip().strip("\"'"),
            "description": desc_match.group(1).strip().strip("\"'"),
            "file": rel,
        })

skills.sort(key=lambda s: s["name"])

with open(os.path.join(HERE, "skills.json"), "w", encoding="utf-8") as f:
    json.dump(skills, f, indent=2, ensure_ascii=False)

print(f"Wrote skills.json with {len(skills)} skills.")
