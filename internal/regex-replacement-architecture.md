# Regex Replacement Architecture

## Overview

The `PSScriptBuilderRegexHelper` class implements two distinct modes for token replacements in bump files:

- **MODE 1**: Placeholder-based replacements (`{{TOKEN}}`)
- **MODE 2**: Regex-based replacements with capture groups (`{REGEX_TOKEN}`)

## Router Logic

```mermaid
flowchart TD
    Start[ApplyPatternReplacements] --> CheckPattern{Analyze pattern}
    CheckPattern -->|Contains double braces| CheckCaptures{Contains parentheses?}
    CheckCaptures -->|No| Mode1[MODE 1: Placeholder]
    CheckCaptures -->|Yes| Error[Error: Mixed modes]
    CheckPattern -->|Contains capture group| Mode2[MODE 2: Regex with capture groups]
    CheckPattern -->|Nothing found| Error2[Error: Invalid pattern]
    
    Mode1 --> Placeholder[ApplyPlaceholderReplacements]
    Mode2 --> Regex[ApplyRegexReplacements]
```

## MODE 1: Placeholder-Based Replacements

### Flow

```mermaid
sequenceDiagram
    participant Caller
    participant Helper as PSScriptBuilderRegexHelper
    participant TokenMap
    
    Caller->>Helper: ApplyPlaceholderReplacements(content, pattern, tokens)
    Helper->>Helper: ValidateTokenValues(tokens)
    
    loop For each token
        Helper->>Helper: Check placeholder {{TOKEN}} in pattern
        Helper->>TokenMap: Get value for token
        Helper->>Helper: Replace {{TOKEN}} with value
    end
    
    Helper->>Helper: Replace pattern in content
    Helper-->>Caller: Return { Content, Changes }
```

### Example

```
Pattern:  "Version = '{{VERSION}}'"
Token:    ["VERSION"]
TokenMap: { VERSION = "1.2.3" }

Result: "Version = '1.2.3'"
```

## MODE 2: Regex-Based Replacements with Capture Groups

### Overall Flow

```mermaid
flowchart TD
    Start[ApplyRegexReplacements] --> Validate[Validate Token Values & Patterns]
    Validate --> Replace[ReplaceRegexPatterns: REGEX_TOKEN → Regex]
    Replace --> Find[FindRegexMatches: Find all matches]
    Find --> CheckMatches{Matches found?}
    CheckMatches -->|No| ReturnEmpty[Return Original Content]
    CheckMatches -->|Yes| Apply[ApplyMatchesWithCaptureGroups]
    Apply --> ReturnResult[Return Modified Content + Changes]
```

### Position-Based Capture Group Replacement (Core Algorithm)

```mermaid
flowchart TD
    Start[ApplyMatchesWithCaptureGroups] --> Init[Initialize]
    Init --> OuterLoop{For each match BACKWARDS}
    
    OuterLoop -->|Match i| GetMatch[Set oldValue and newMatch]
    GetMatch --> InnerLoop{For each token BACKWARDS}
    
    InnerLoop -->|Token j| ValidateGroup{Capture group present?}
    ValidateGroup -->|No| ThrowError[InvalidOperationException]
    ValidateGroup -->|Yes| GetGroup[Get capture group]
    
    GetGroup --> CalcPos[Calculate relativeIndex]
    CalcPos --> Slice[Substring slicing]
    Slice --> ReplaceToken[Replace token value]
    
    ReplaceToken --> InnerLoop
    InnerLoop -->|Done| CheckChange{Change detected?}
    
    CheckChange -->|Yes| ReplaceContent[Position-based replacement]
    ReplaceContent --> RecordChange[Record change]
    RecordChange --> WriteVerbose[Verbose output]
    WriteVerbose --> OuterLoop
    
    CheckChange -->|No| OuterLoop
    OuterLoop -->|Done| Return[Return Result]
```

### Why Back-to-Front Processing?

```mermaid
flowchart TD
    subgraph P["Problem: Forward Processing"]
        A1["Match 1 at position 10"] --> A2["Replacement changes length"]
        A2 --> A3["Match 2 position shifted"]
    end
    
    subgraph L["Solution: Back-to-Front"]
        B1["Match 2 at position 50"] --> B2["Replacement changes length"]
        B2 --> B3["Match 1 position unchanged"]
    end
```

### Position-Based Replacement in Detail

```mermaid
sequenceDiagram
    participant Content
    participant Match
    participant CaptureGroups
    participant TokenMap
    
    Note over Content: Original content with multiple matches
    
    Content->>Match: Find all regex matches
    
    loop Each match (BACKWARDS)
        Match->>Match: oldValue = match.Value
        Match->>Match: newMatch = oldValue
        
        loop Each capture group (BACKWARDS)
            Match->>CaptureGroups: Get Group[i+1]
            CaptureGroups->>Match: captureGroup.Index, .Length, .Value
            Match->>TokenMap: Get new value for token
            TokenMap->>Match: newTokenValue
            
            Note over Match: Calculate relative position
            
            Match->>Match: Substring slicing
            Match->>Match: newMatch updated
        end
        
        alt Value changed
            Match->>Content: Replace at exact position
            Match->>Match: Record change
        end
    end
    
    Content-->>Match: Final content with all replacements
```

## Example: Multiline Replacement with 3 Tokens

### Input

```
Pattern: \.DATEMODIFIED\r?\n\s+({REGEX_BUILD_DATE}) ({REGEX_BUILD_HOUR}):({REGEX_BUILD_MINUTE})
Tokens:  ["BUILD_DATE", "BUILD_HOUR", "BUILD_MINUTE"]

Content:
.DATEMODIFIED
    2026-02-05 16:27

TokenMap:
  BUILD_DATE   = "2026-02-11"
  BUILD_HOUR   = "14"
  BUILD_MINUTE = "35"
```

### Processing

```mermaid
flowchart TD
    M0["Match Groups[0]"] --> M1["Groups[1]: BUILD_DATE"]
    M0 --> M2["Groups[2]: BUILD_HOUR"]
    M0 --> M3["Groups[3]: BUILD_MINUTE"]
    
    M1 --> S1["Step 1: Replace BUILD_DATE"]
    M2 --> S2["Step 2: Replace BUILD_HOUR"]
    M3 --> S3["Step 3: Replace BUILD_MINUTE"]
    
    S3 --> S2
    S2 --> S1
    S1 --> C["Content Update"]
```

### Output

```
Content:
.DATEMODIFIED
    2026-02-11 14:35

Verbose Output (formatted):
Regex match replaced: .DATEMODIFIED[CRLF][space:4]2026-02-05 16:27 -> .DATEMODIFIED[CRLF][space:4]2026-02-11 14:35
```

## Verbose Output Formatting

```mermaid
flowchart LR
    Input[Raw String] --> Format[FormatStringForVerboseOutput]
    
    Format --> CRLF[CRLF replacement]
    Format --> LF[LF replacement]
    Format --> CR[CR replacement]
    Format --> TAB[TAB replacement]
    Format --> Spaces[Space replacement]
    
    CRLF --> Output[Formatted string]
    LF --> Output
    CR --> Output
    TAB --> Output
    Spaces --> Output
```

### Example

```
Before: ".DATEMODIFIED\r\n    2026-02-05 16:27"
After:  ".DATEMODIFIED[CRLF][space:4]2026-02-05 16:27"
```

## Critical Design Decisions

### 1. Why Position-Based Instead of String.Replace?

```mermaid
flowchart TD
    subgraph P["Problem: String.Replace"]
        P1["Content with duplicates"]
        P2["String.Replace"]
        P3["BOTH occurrences replaced"]
        P1 --> P2 --> P3
    end
    
    subgraph L["Solution: Position-based"]
        S1["Content with duplicates"]
        S2["Match at position 10"]
        S3["Substring slicing"]
        S4["ONLY one match replaced"]
        S1 --> S2 --> S3 --> S4
    end
```

### 2. Why Capture Groups Instead of Denormalization?

```mermaid
flowchart TD
    subgraph O["Old approach: Denormalization"]
        O1["Pattern with regex"]
        O2["Denormalize whitespace"]
        O3["Formatting lost"]
        O1 --> O2 --> O3
    end
    
    subgraph N["New approach: Capture Groups"]
        N1["Pattern with capture group"]
        N2["Match with whitespace"]
        N3["Replace only capture group"]
        N4["Formatting preserved"]
        N1 --> N2 --> N3 --> N4
    end
```

### 3. Relative vs. Absolute Indexing

```mermaid
flowchart LR
    subgraph "Match"
        M["Match position 100"]
        C["CaptureGroup position 110"]
    end
    
    subgraph "Calculation"
        R["relativeIndex = 10"]
    end
    
    subgraph "Replacement"
        B["before"]
        A["after"]
        N["newMatch"]
    end
    
    M --> R
    C --> R
    R --> B
    R --> A
    B --> N
    A --> N
```

## Token Validation

```mermaid
flowchart TD
    Start[ValidateTokenValues] --> CheckNull{Tokens null/empty?}
    CheckNull -->|Yes| Error1[ArgumentException]
    CheckNull -->|No| CheckDup{Duplicates?}
    
    CheckDup -->|Yes| Error2[ArgumentException]
    CheckDup -->|No| LoopTokens[For each token]
    
    LoopTokens --> CheckWhitespace{Token null?}
    CheckWhitespace -->|Yes| Error3[ArgumentException]
    CheckWhitespace -->|No| CheckExists{In TokenMap?}
    
    CheckExists -->|No| Error4[KeyNotFoundException]
    CheckExists -->|Yes| CheckValue{Value null?}
    
    CheckValue -->|Yes| Error5[InvalidOperationException]
    CheckValue -->|No| LoopTokens
    
    LoopTokens -->|Done| Success[Validation OK]
```

## Regex Pattern Replacement

```mermaid
sequenceDiagram
    participant Method as ReplaceRegexPatterns
    participant Pattern
    participant RegexPatterns
    
    Note over Method: Input pattern with REGEX_TOKEN
    
    Method->>Method: result = pattern
    
    loop For each token
        Method->>Pattern: Search for REGEX_TOKEN
        
        alt Placeholder found
            Method->>RegexPatterns: Get regex
            RegexPatterns-->>Method: Regex pattern
            Method->>Method: Replace placeholder
        end
    end
    
    Method-->>Method: Return completed pattern
    
    Note over Method: Output pattern with regex
```

### Example

```
Input:
  Pattern: "Version\s*=\s*'({REGEX_VERSION})'"
  Token:   ["VERSION"]
  RegexPatterns: { VERSION = "\d+\.\d+\.\d+" }

Output:
  Pattern: "Version\s*=\s*'(\d+\.\d+\.\d+)'"
```

## Performance Considerations

```mermaid
graph TD
    subgraph "Complexity"
        C1["Number of matches: n"]
        C2["Number of tokens per match: m"]
        C3["Total complexity: O(n × m)"]
        C1 --> C3
        C2 --> C3
    end
    
    subgraph "Optimizations"
        O1["Back-to-front prevents index shifting"]
        O2["Position-based prevents global search"]
        O3["Capture groups for precise replacement"]
        O4["No string concatenation in loop"]
    end
```

### Typical Scenarios

| Scenario | Matches | Tokens | Operations | Time |
|----------|---------|--------|------------|------|
| Single Pattern | 1 | 1 | O(1) | ~1ms |
| Multiple Patterns | 5 | 1 | O(5) | ~5ms |
| Multiline Pattern | 1 | 3 | O(3) | ~3ms |
| Complex File | 10 | 2 | O(20) | ~20ms |

## Edge Cases

```mermaid
flowchart TD
    Root[Edge Cases] --> D[Duplicates]
    Root --> V[Variable Lengths]
    Root --> M[Multiline]
    Root --> E[Empty Values]
    Root --> N[No Matches]
    Root --> G[Missing Capture Groups]
    
    D --> D1[Same value multiple times]
    D --> D2[Position-based solves the problem]
    
    V --> V1[Token longer/shorter]
    V --> V2[Substring adjusts automatically]
    
    M --> M1[Newlines in matches]
    M --> M2[Index spans across lines]
    
    E --> E1[Token value empty]
    E --> E2[Validation prevents this]
    
    N --> N1[Pattern finds nothing]
    N --> N2[Return Original Content]
    
    G --> G1[Too few groups]
    G --> G2[InvalidOperationException]
```

## Summary

```mermaid
flowchart TD
    A[PSScriptBuilderRegexHelper] --> B{Pattern analysis}
    B -->|Placeholder| C[MODE 1: Simple String Replace]
    B -->|Capture Groups| D[MODE 2: Position-based Replacement]
    
    D --> E[Token Validation]
    E --> F[Pattern to Regex]
    F --> G[Find Matches]
    G --> H[Back-to-Front Processing]
    H --> I[Capture Group Replacement]
    I --> J[Position-based Content Update]
    J --> K[Formatted Verbose Output]
    
    C --> L[Direct String Replace]
    L --> M[No Formatting Preservation]
```

### Advantages of the Current Design

1. **Formatting preserved**: Spaces, tabs, and newlines are not modified
2. **Multiline support**: Patterns spanning multiple lines work correctly
3. **Multi-token support**: Multiple tokens in a single pattern are supported
4. **No duplicate issues**: Position-based replacement prevents global changes
5. **Robust validation**: Early errors for invalid tokens/patterns
6. **Readable output**: Formatted verbose messages for debugging

### PowerShell 5.1 Compatibility

- No ternary operators
- No interfaces
- `for` loops instead of `foreach` for index control
- Constructor overloading is supported
- .NET Regex with MatchCollection works correctly
