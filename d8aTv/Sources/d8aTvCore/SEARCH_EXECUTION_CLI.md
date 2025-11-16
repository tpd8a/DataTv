# Search Execution CLI Guide

## Overview

The `splunk-dashboard splunk run` command allows you to execute searches found in Splunk dashboards with real-time monitoring, auto-refresh capabilities, and flexible configuration options.

## Basic Usage

### Run All Searches in a Dashboard

```bash
splunk-dashboard splunk run my_dashboard
```

### Run with Real-Time Monitoring

```bash
splunk-dashboard splunk run my_dashboard --listen
```

This enables live progress updates with a visual progress bar:

```
🔄 [████████████████████████░░░░░░] 85% - base: Executing search... 85% complete
```

### Run a Specific Search

```bash
splunk-dashboard splunk run my_dashboard --search-id base --listen
```

### Run with Custom Time Range

```bash
splunk-dashboard splunk run my_dashboard -e "-24h@h" -l "now" --listen
```

### Run with Token Values

```bash
splunk-dashboard splunk run my_dashboard \
  --token "host=web01" \
  --token "index=main" \
  --listen
```

### Dry Run (See What Would Execute)

```bash
splunk-dashboard splunk run my_dashboard --dry-run --verbose
```

## Advanced Features

### Auto-Refresh Mode

Enable automatic re-execution based on the search's `refresh` attribute:

```bash
splunk-dashboard splunk run my_dashboard --listen --refresh
```

**How Refresh Works:**
- Searches with a `refresh` attribute (format: "number+unit") will automatically re-execute
- Example refresh values:
  - `"30s"` - Every 30 seconds
  - `"5m"` - Every 5 minutes
  - `"1h"` - Every 1 hour
  - `"1d"` - Every 1 day
- Requires `--listen` flag to be active

### Show Results

Display search results directly in the terminal:

```bash
splunk-dashboard splunk run my_dashboard --listen --show-results
```

Output:
```
📊 Results for 'base':
──────────────────────────────────────────────────
Row 1:
  count: 1234
  sourcetype: access_combined

Row 2:
  count: 567
  sourcetype: splunkd
──────────────────────────────────────────────────
```

### Concurrent Execution

Run multiple searches in parallel:

```bash
splunk-dashboard splunk run my_dashboard --concurrent --listen
```

### Validation

Validate searches before execution:

```bash
splunk-dashboard splunk run my_dashboard --validate --listen
```

## Complete Example Workflow

```bash
# 1. Run base search first (it has no dependencies)
splunk-dashboard splunk run my_dashboard \
  --search-id base \
  --listen \
  --show-results

# 2. Run dependent searches with monitoring and auto-refresh
splunk-dashboard splunk run my_dashboard \
  --listen \
  --refresh \
  --show-results \
  --token "filter=*" \
  -e "-1h@h" \
  -l "now"
```

## Command Reference

### Required Arguments
- `<dashboard-id>` - The dashboard ID to run searches from

### Options

| Flag | Short | Description |
|------|-------|-------------|
| `--search-id` | `-s` | Run only a specific search by ID |
| `--type` | `-t` | Filter by search type (panel, visualization, global, all) |
| `--max-count` | `-m` | Maximum number of results per search |
| `--timeout` | | Search timeout in seconds |
| `--earliest` | `-e` | Earliest time for search (e.g., `-1h@h`, `-24h@h`) |
| `--latest` | `-l` | Latest time for search (e.g., `now`, `@d`) |
| `--token` | | Token values in `name=value` format (repeatable) |
| `--username` | `-u` | Override stored username |
| `--password` | `-p` | Override stored password |
| `--api-token` | | Override with API token |

### Flags

| Flag | Description |
|------|-------------|
| `--listen` | Enable real-time progress monitoring |
| `--refresh` | Enable auto-refresh (requires `--listen`) |
| `--show-results` | Display result data when searches complete |
| `--concurrent` | `-c` | Run searches in parallel |
| `--validate` | Validate searches before running |
| `--verbose` | `-v` | Show detailed output including queries |
| `--dry-run` | `-d` | Show what would execute without running |

## Monitoring Output

### Progress Bar Format

```
🔄 [████████████████████████░░░░░░] 85% - search_id: Status message
   ✅ 20 results in 3.45s
   🔑 SID: 1762506892.712
```

### Status Icons
- `⏳` - Pending
- `🔄` - Running
- `✅` - Completed
- `❌` - Failed
- `🚫` - Cancelled

### Stopping Execution

Press `Ctrl+C` to gracefully stop:

```
^C
🛑 Interrupt received - stopping execution...
🚫 Execution stopped by user
```

## Base Search Handling

The CLI automatically handles base search dependencies:

1. **Detects base references**: If a search has `base="base_search_id"`
2. **Resolves SID**: Finds the most recent completed execution's SID
3. **Modifies query**: Prepends `| loadjob {SID}` to the query
4. **Removes time params**: Base searches don't need time range
5. **Executes**: Runs the modified search

**Example:**
```bash
# First run the base search
splunk-dashboard splunk run my_dashboard --search-id base --listen

# Then run dependent searches (automatically uses base SID)
splunk-dashboard splunk run my_dashboard --search-id dependent --listen
```

## Troubleshooting

### "Base search not found or not yet executed"

**Solution**: Run the base search first:
```bash
splunk-dashboard splunk run my_dashboard --search-id base --listen
```

### "Token resolution failed"

**Solution**: Provide missing token values:
```bash
splunk-dashboard splunk run my_dashboard --token "missing_token=value" --listen
```

### "No stored credentials found"

**Solution**: Set up credentials:
```bash
splunk-dashboard splunk config set-creds
```

## Best Practices

1. **Use `--listen` for interactive monitoring**: Always enables progress visibility
2. **Run base searches first**: Ensures dependent searches can find SIDs
3. **Use `--dry-run` for testing**: Verify tokens and queries before execution
4. **Enable `--refresh` cautiously**: Can create many Splunk jobs
5. **Use `--show-results` sparingly**: Large result sets can overwhelm terminal
6. **Store credentials**: Use `splunk-dashboard splunk config set-creds` instead of passing passwords on command line

## Advanced Patterns

### Monitor Multiple Dashboards

```bash
#!/bin/bash
for dashboard in dashboard1 dashboard2 dashboard3; do
  splunk-dashboard splunk run $dashboard --listen --refresh &
done
wait
```

### Conditional Execution

```bash
# Only run if validation passes
if splunk-dashboard splunk run my_dashboard --dry-run --validate; then
  splunk-dashboard splunk run my_dashboard --listen
fi
```

### Capture Results

```bash
splunk-dashboard splunk run my_dashboard --listen --show-results > results.txt
```

## Notes on Core Data Storage

All search executions are stored in Core Data:

- **Execution metadata**: Status, progress, timestamps, SID
- **Complete results**: Full JSON of search results
- **Individual rows**: Separate entities for efficient paging

Query execution history:
```bash
# This will show stored executions (feature to be added)
splunk-dashboard query executions --dashboard my_dashboard
```

Clean up old executions:
```bash
# Cleanup executions older than 7 days (built into CoreDataManager)
# Note: This is automatic, or can be triggered manually via API
```

## Future Enhancements

- [ ] `--follow` flag for tailing search results
- [ ] `--export` flag to save results to file
- [ ] `--format` option for output formatting (json, csv, table)
- [ ] Query command to list execution history
- [ ] Resume interrupted auto-refresh sessions
- [ ] Notification support when searches complete
