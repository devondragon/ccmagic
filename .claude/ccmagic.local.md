---
# ccmagic project config for this repo (consumed by ccmagic skills on both
# laptop and Cyrus runs). Pins the tracker so the auto-ticket prompt-relay
# transport detects Linear deterministically inside the Cyrus container, where
# there is no Linear MCP to probe and an `ENG-123`-shaped ID is otherwise
# ambiguous between Linear and JIRA. See docs/ccmagic.local.md.example for the
# full set of available keys.
tracker: linear
github_repo: devondragon/ccmagic
---
