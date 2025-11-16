# Splunk Formatting Examples - Visual Guide

## How Per-Field Formatting Works

Each column (field) in your results table can have its own independent formatting rules. Here's what a table with multiple format types looks like:

```
┌────────────┬─────────────┬──────────────┬─────────────────┐
│   Field:   │   error     │    count     │      info       │
│  Format:   │ Threshold   │ Gradient +   │   Categorical   │
│            │   Colors    │   Currency   │     Colors      │
├────────────┼─────────────┼──────────────┼─────────────────┤
│   Row 1    │     15      │   £ 1,234    │    SUCCESS      │
│            │  [GREEN BG] │ [LIGHT GREEN]│   [PURPLE BG]   │
├────────────┼─────────────┼──────────────┼─────────────────┤
│   Row 2    │     45      │   £ 2,567    │    WARNING      │
│            │ [YELLOW BG] │ [MED GREEN]  │   [ORANGE BG]   │
├────────────┼─────────────┼──────────────┼─────────────────┤
│   Row 3    │     85      │   £ 3,890    │     ERROR       │
│            │   [RED BG]  │ [DARK GREEN] │    [RED BG]     │
├────────────┼─────────────┼──────────────┼─────────────────┤
│   Row 4    │     25      │   £ 1,567    │    SUCCESS      │
│            │  [GREEN BG] │ [LIGHT GREEN]│   [PURPLE BG]   │
└────────────┴─────────────┴──────────────┴─────────────────┘
```

## Format Configuration Examples

### Example 1: Error Column (Threshold-Based Colors)

```json
{
  "field": "error",
  "type": "color",
  "palette": {
    "type": "list",
    "colors": ["#118832", "#CBA700", "#D41F1F"]
  },
  "scale": {
    "type": "threshold",
    "values": [0, 50, 80]
  }
}
```

**Result:**
- Values 0-49: Green background (#118832)
- Values 50-79: Yellow background (#CBA700)
- Values 80+: Red background (#D41F1F)

### Example 2: Count Column (Currency + Gradient)

**Number Formatting:**
```json
{
  "field": "count",
  "type": "number",
  "unit": "£",
  "unitPosition": "before",
  "precision": "0"
}
```

**Color Formatting:**
```json
{
  "field": "count",
  "type": "color",
  "palette": {
    "type": "minMidMax",
    "minColor": "#FFFFFF",
    "maxColor": "#118832"
  }
}
```

**Result:**
- Text displays as: "£ 1,234" (with space after £)
- Background: White → Light Green → Dark Green (gradient based on value)

### Example 3: Info Column (Categorical Colors)

```json
{
  "field": "info",
  "type": "color",
  "palette": {
    "type": "sharedList"
  },
  "scale": {
    "type": "sharedCategory"
  }
}
```

**Result:**
- "SUCCESS" → Always purple background
- "WARNING" → Always orange background
- "ERROR" → Always red background
- Each unique value gets a consistent color

## Real-World Dashboard Example

```json
{
  "visualizations": [
    {
      "type": "table",
      "options": {
        "rowNumbers": "true",
        "wrap": "false"
      },
      "formats": [
        {
          "field": "status_code",
          "type": "color",
          "palette": {
            "type": "list",
            "colors": ["#118832", "#CBA700", "#D94E17", "#D41F1F"]
          },
          "scale": {
            "type": "threshold",
            "values": [200, 300, 400, 500]
          }
        },
        {
          "field": "response_time",
          "type": "number",
          "unit": "ms",
          "unitPosition": "after",
          "precision": "0"
        },
        {
          "field": "response_time",
          "type": "color",
          "palette": {
            "type": "minMidMax",
            "minColor": "#FFFFFF",
            "maxColor": "#D41F1F"
          }
        },
        {
          "field": "amount",
          "type": "number",
          "unit": "£",
          "unitPosition": "before",
          "precision": "2"
        },
        {
          "field": "severity",
          "type": "color",
          "palette": {
            "type": "sharedCategory"
          }
        }
      ]
    }
  ]
}
```

**Renders as:**

```
┌─────────────┬──────────────┬────────────┬────────────┐
│ status_code │ response_time│   amount   │  severity  │
├─────────────┼──────────────┼────────────┼────────────┤
│     200     │    123 ms    │  £ 99.99   │    LOW     │
│  [GREEN]    │  [WHITE BG]  │            │ [BLUE BG]  │
├─────────────┼──────────────┼────────────┼────────────┤
│     404     │    456 ms    │ £ 199.50   │    HIGH    │
│ [ORANGE]    │ [PINK BG]    │            │  [RED BG]  │
├─────────────┼──────────────┼────────────┼────────────┤
│     500     │    789 ms    │ £ 299.99   │  CRITICAL  │
│   [RED]     │  [RED BG]    │            │ [DARK RED] │
└─────────────┴──────────────┴────────────┴────────────┘
```

## Important Notes

1. **Multiple formats per field**: A field can have both color AND number formatting
   - Color formatting → cell background
   - Number formatting → cell text

2. **Independent columns**: Each field's formatting is completely independent of other fields

3. **Format precedence**: User's custom settings can override Splunk formatting:
   - Custom cell background > Change highlight > Splunk color > Zebra striping

4. **Categorical consistency**: With `sharedList`/`sharedCategory`, the same value will always get the same color across all rows and all refreshes

5. **Text readability**: All background colors are applied with opacity (0.7) to ensure text remains readable

## Debug Output Example

When viewing formatted results, you'll see console output like:

```
📊 Loaded table options: wrap=false, rowNumbers=true, displayCount=10
🎨 Color formatting applied to field 'status_code': 200 → color (type: list)
💰 Number formatting applied to field 'response_time': 123 → '123 ms' (unit: 'ms', position: after, precision: 0)
💰 Number formatting applied to field 'amount': 99.99 → '£ 99.99' (unit: '£', position: before, precision: 2)
🎨 Color formatting applied to field 'severity': "LOW" → color (type: sharedCategory)
```

This confirms that each field is getting its appropriate formatting applied independently!
