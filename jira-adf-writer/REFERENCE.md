# Jira ADF Writer – Reference

## ADF Document Skeleton
```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "paragraph",
      "content": [
        { "type": "text", "text": "Text goes here." }
      ]
    }
  ]
}
```

---

## Paragraph Granularity

- One paragraph = one logical block
- Do NOT split a single instruction across multiple paragraphs
- Do NOT merge unrelated content into one paragraph

---

## Label + Value Format

Correct:
```json
{
  "type": "paragraph",
  "content": [
    { "type": "text", "text": "Goal:", "marks": [{ "type": "strong" }] },
    { "type": "text", "text": " Build the API layer." }
  ]
}
```

Wrong:

- Label and value in separate paragraphs

---

## Bold Formatting

Correct:
```json
{ "type": "text", "text": "Milestone:", "marks": [{ "type": "strong" }] }
```

Never:
```json
{ "type": "text", "text": "**Milestone:**" }
```

---

## Line Break Normalization

Always:

1. Replace `\\\\n` → `\n`
2. Replace `\\n` → `\n`
3. Split on real newline

Never leave `\n` inside text nodes.

---

## Spacer Paragraphs

Optional:
```json
{ "type": "paragraph", "content": [{ "type": "text", "text": " " }] }
```

Use only between major sections.

---

## Standard Section Order (optional)

1. Milestone
2. Goal
3. Hypothesis
4. Acceptance Criteria
5. Tasks
6. Source

---

## Update API Usage

### Description
```
editJiraIssue
contentFormat: adf
fields: { "description": <ADF> }
```

### Comment
```
addCommentToJiraIssue
contentFormat: adf
body: <ADF>
```

---

## Python Builder (optional helper)
```python
def build_adf(raw_text: str) -> dict:
    normalized = raw_text.replace('\\\\n', '\n').replace('\\n', '\n')
    blocks = normalized.split('\n')

    return {
        "version": 1,
        "type": "doc",
        "content": [
            {
                "type": "paragraph",
                "content": [{"type": "text", "text": b.strip()}]
            }
            for b in blocks if b.strip()
        ]
    }
```

---

## Prompt Templates (optional)

### Write

- Convert to ADF
- Preserve meaning
- Use paragraph blocks
- Validate after write

### Fix

- Detect broken field
- Normalize
- Rewrite in ADF
- Validate