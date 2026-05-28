# Terminal Command Policy

When using terminal commands, you MUST follow these rules.

- Run exactly one command per terminal execution.
- Do not combine multiple commands into one shell line.
- Do not use command chaining or shell composition.
- Forbidden operators and constructs include: `&&`, `||`, `;`, `|`, `>`, `>>`, `2>`, `2>&1`, backticks, `$()`, heredoc, `printf` separators, `sed` just for output slicing, and `awk` just for output slicing.
- Do not combine validation, listing, status checks, file reads, or test commands into a single command.
- If multiple checks are needed, run them one at a time and wait for each result before running the next command.
- This rule applies even when combining commands would save time or reduce round trips.

Bad:

```bash
openspec list --json && printf '\n--- specs validate ---\n' && openspec validate --specs