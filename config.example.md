# Local Configuration Example

Public agent definitions reference local values through environment variables. Keep actual values outside this repository, for example:

```text
~/.config/agent-rules/local-values.env
```

```bash
NOTES_DIR="$HOME/Notes"
REPOS_DIR="$HOME/src/repos"
CLAUDE_PROJECTS_DIR="$HOME/.claude/projects"

NOTION_KEYCHAIN_SERVICE="notion-personal-token"
NOTION_TASKS_BLOCK_ID="<notion-block-id>"
NOTION_WEEKLY_REPORT_PAGE_ID="<notion-page-id>"

TISTORY_BLOG_NAME="<blog-name>"
TISTORY_BLOG_HOST="<blog-name>.tistory.com"
DEV_NOTES_REPO="<github-owner>/<repository>"
OBSIDIAN_BLOG_DIR="$HOME/Documents/Obsidian Vault/Blog"
WEEKLY_REPORT_DIR="$HOME/Documents/Weekly Reports"

SLACK_BRIEFING_CHANNEL="#briefing"

NOTICE_SOURCE_1_LABEL="Department"
NOTICE_SOURCE_1_URL="https://example.edu/notices"
NOTICE_SOURCE_1_LIMIT="5"
NOTICE_SOURCE_2_LABEL="Institute"
NOTICE_SOURCE_2_URL="https://example.edu/institute/notices"
NOTICE_SOURCE_2_LIMIT="3"
NOTICE_SOURCE_3_LABEL="International"
NOTICE_SOURCE_3_URL="https://example.edu/international/notices"
NOTICE_SOURCE_3_LIMIT="3"
```

Do not commit `local-values.env`, API tokens, passwords, cookies, or private identifiers.

Antigravity currently reads compatible global settings from `~/.gemini/`. Keep actual values in the private local file and commit only this example.
