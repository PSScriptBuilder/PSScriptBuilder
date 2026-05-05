# Regex Replacement Architecture

## Übersicht

Die `PSScriptBuilderRegexHelper` Klasse implementiert zwei verschiedene Modi für Token-Ersetzungen in Bump-Dateien:

- **MODUS 1**: Placeholder-basierte Ersetzungen (`{{TOKEN}}`)
- **MODUS 2**: Regex-basierte Ersetzungen mit Capture Groups (`{REGEX_TOKEN}`)

## Router-Logik

```mermaid
flowchart TD
    Start[ApplyPatternReplacements] --> CheckPattern{Pattern analysieren}
    CheckPattern -->|Enthaelt Doppelklammer| CheckCaptures{Enthaelt Klammer?}
    CheckCaptures -->|Nein| Mode1[MODUS 1: Placeholder]
    CheckCaptures -->|Ja| Error[Fehler: Gemischte Modi]
    CheckPattern -->|Enthaelt Capture Group| Mode2[MODUS 2: Regex mit Capture Groups]
    CheckPattern -->|Nichts gefunden| Error2[Fehler: Ungueltiges Pattern]
    
    Mode1 --> Placeholder[ApplyPlaceholderReplacements]
    Mode2 --> Regex[ApplyRegexReplacements]
```

## MODUS 1: Placeholder-basierte Ersetzungen

### Ablauf

```mermaid
sequenceDiagram
    participant Caller
    participant Helper as PSScriptBuilderRegexHelper
    participant TokenMap
    
    Caller->>Helper: ApplyPlaceholderReplacements(content, pattern, tokens)
    Helper->>Helper: ValidateTokenValues(tokens)
    
    loop Für jeden Token
        Helper->>Helper: Prüfe Placeholder {{TOKEN}} in Pattern
        Helper->>TokenMap: Hole Wert für Token
        Helper->>Helper: Ersetze {{TOKEN}} mit Wert
    end
    
    Helper->>Helper: Ersetze Pattern im Content
    Helper-->>Caller: Return { Content, Changes }
```

### Beispiel

```
Pattern:  "Version = '{{VERSION}}'"
Token:    ["VERSION"]
TokenMap: { VERSION = "1.2.3" }

Ergebnis: "Version = '1.2.3'"
```

## MODUS 2: Regex-basierte Ersetzungen mit Capture Groups

### Gesamt-Ablauf

```mermaid
flowchart TD
    Start[ApplyRegexReplacements] --> Validate[Validate Token Values & Patterns]
    Validate --> Replace[ReplaceRegexPatterns: REGEX_TOKEN → Regex]
    Replace --> Find[FindRegexMatches: Finde alle Matches]
    Find --> CheckMatches{Matches gefunden?}
    CheckMatches -->|Nein| ReturnEmpty[Return Original Content]
    CheckMatches -->|Ja| Apply[ApplyMatchesWithCaptureGroups]
    Apply --> ReturnResult[Return Modified Content + Changes]
```

### Position-basierte Capture Group Ersetzung (Kern-Algorithmus)

```mermaid
flowchart TD
    Start[ApplyMatchesWithCaptureGroups] --> Init[Initialisiere]
    Init --> OuterLoop{Fuer jedes Match RUECKWAERTS}
    
    OuterLoop -->|Match i| GetMatch[oldValue und newMatch setzen]
    GetMatch --> InnerLoop{Fuer jeden Token RUECKWAERTS}
    
    InnerLoop -->|Token j| ValidateGroup{Capture Group vorhanden?}
    ValidateGroup -->|Nein| ThrowError[InvalidOperationException]
    ValidateGroup -->|Ja| GetGroup[Hole Capture Group]
    
    GetGroup --> CalcPos[Berechne relativeIndex]
    CalcPos --> Slice[Substring Slicing]
    Slice --> ReplaceToken[Ersetze Token Value]
    
    ReplaceToken --> InnerLoop
    InnerLoop -->|Fertig| CheckChange{Aenderung vorhanden?}
    
    CheckChange -->|Ja| ReplaceContent[Position-basierte Ersetzung]
    ReplaceContent --> RecordChange[Change aufzeichnen]
    RecordChange --> WriteVerbose[Verbose Output]
    WriteVerbose --> OuterLoop
    
    CheckChange -->|Nein| OuterLoop
    OuterLoop -->|Fertig| Return[Return Result]
```

### Warum Back-to-Front Processing?

```mermaid
flowchart TD
    subgraph P["Problem: Forward Processing"]
        A1["Match 1 an Position 10"] --> A2["Ersetzung aendert Laenge"]
        A2 --> A3["Match 2 Position verschoben"]
    end
    
    subgraph L["Loesung: Back-to-Front"]
        B1["Match 2 an Position 50"] --> B2["Ersetzung aendert Laenge"]
        B2 --> B3["Match 1 Position unveraendert"]
    end
```

### Position-basierte Ersetzung im Detail

```mermaid
sequenceDiagram
    participant Content
    participant Match
    participant CaptureGroups
    participant TokenMap
    
    Note over Content: Original Content mit mehreren Matches
    
    Content->>Match: Finde alle Regex Matches
    
    loop Jedes Match (RÜCKWÄRTS)
        Match->>Match: oldValue = match.Value
        Match->>Match: newMatch = oldValue
        
        loop Jede Capture Group (RÜCKWÄRTS)
            Match->>CaptureGroups: Hole Group[i+1]
            CaptureGroups->>Match: captureGroup.Index, .Length, .Value
            Match->>TokenMap: Hole neuen Wert für Token
            TokenMap->>Match: newTokenValue
            
            Note over Match: Berechne relative Position
            
            Match->>Match: Substring-Slicing
            Match->>Match: newMatch aktualisiert
        end
        
        alt Wert geaendert
            Match->>Content: Ersetze an exakter Position
            Match->>Match: Speichere Change
        end
    end
    
    Content-->>Match: Finaler Content mit allen Ersetzungen
```

## Beispiel: Multiline-Ersetzung mit 3 Tokens

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

### Verarbeitung

```mermaid
flowchart TD
    M0["Match Groups[0]"] --> M1["Groups[1]: BUILD_DATE"]
    M0 --> M2["Groups[2]: BUILD_HOUR"]
    M0 --> M3["Groups[3]: BUILD_MINUTE"]
    
    M1 --> S1["Step 1: Ersetze BUILD_DATE"]
    M2 --> S2["Step 2: Ersetze BUILD_HOUR"]
    M3 --> S3["Step 3: Ersetze BUILD_MINUTE"]
    
    S3 --> S2
    S2 --> S1
    S1 --> C["Content Update"]
```

### Output

```
Content:
.DATEMODIFIED
    2026-02-11 14:35

Verbose Output (formatiert):
Regex match replaced: .DATEMODIFIED[CRLF][space:4]2026-02-05 16:27 -> .DATEMODIFIED[CRLF][space:4]2026-02-11 14:35
```

## Verbose Output Formatierung

```mermaid
flowchart LR
    Input[Raw String] --> Format[FormatStringForVerboseOutput]
    
    Format --> CRLF[CRLF Ersetzung]
    Format --> LF[LF Ersetzung]
    Format --> CR[CR Ersetzung]
    Format --> TAB[TAB Ersetzung]
    Format --> Spaces[Space Ersetzung]
    
    CRLF --> Output[Formatierter String]
    LF --> Output
    CR --> Output
    TAB --> Output
    Spaces --> Output
```

### Beispiel

```
Vorher:  ".DATEMODIFIED\r\n    2026-02-05 16:27"
Nachher: ".DATEMODIFIED[CRLF][space:4]2026-02-05 16:27"
```

## Kritische Designentscheidungen

### 1. Warum Position-basiert statt String.Replace?

```mermaid
flowchart TD
    subgraph P["Problem: String.Replace"]
        P1["Content mit Duplikaten"]
        P2["String.Replace"]
        P3["BEIDE Vorkommen ersetzt"]
        P1 --> P2 --> P3
    end
    
    subgraph L["Loesung: Position-basiert"]
        S1["Content mit Duplikaten"]
        S2["Match an Position 10"]
        S3["Substring-Slicing"]
        S4["NUR ein Match ersetzt"]
        S1 --> S2 --> S3 --> S4
    end
```

### 2. Warum Capture Groups statt Denormalization?

```mermaid
flowchart TD
    subgraph O["Alte Methode: Denormalization"]
        O1["Pattern mit Regex"]
        O2["Denormalize Whitespace"]
        O3["Formatierung verloren"]
        O1 --> O2 --> O3
    end
    
    subgraph N["Neue Methode: Capture Groups"]
        N1["Pattern mit Capture Group"]
        N2["Match mit Whitespace"]
        N3["Ersetze nur Capture Group"]
        N4["Formatierung erhalten"]
        N1 --> N2 --> N3 --> N4
    end
```

### 3. Relative vs. Absolute Indexierung

```mermaid
flowchart LR
    subgraph "Match"
        M["Match Position 100"]
        C["CaptureGroup Position 110"]
    end
    
    subgraph "Berechnung"
        R["relativeIndex = 10"]
    end
    
    subgraph "Ersetzung"
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
    CheckNull -->|Ja| Error1[ArgumentException]
    CheckNull -->|Nein| CheckDup{Duplikate?}
    
    CheckDup -->|Ja| Error2[ArgumentException]
    CheckDup -->|Nein| LoopTokens[Für jeden Token]
    
    LoopTokens --> CheckWhitespace{Token null?}
    CheckWhitespace -->|Ja| Error3[ArgumentException]
    CheckWhitespace -->|Nein| CheckExists{In TokenMap?}
    
    CheckExists -->|Nein| Error4[KeyNotFoundException]
    CheckExists -->|Ja| CheckValue{Value null?}
    
    CheckValue -->|Ja| Error5[InvalidOperationException]
    CheckValue -->|Nein| LoopTokens
    
    LoopTokens -->|Fertig| Success[Validation OK]
```

## Regex Pattern Ersetzung

```mermaid
sequenceDiagram
    participant Method as ReplaceRegexPatterns
    participant Pattern
    participant RegexPatterns
    
    Note over Method: Input Pattern mit REGEX_TOKEN
    
    Method->>Method: result = pattern
    
    loop Für jeden Token
        Method->>Pattern: Suche REGEX_TOKEN
        
        alt Placeholder gefunden
            Method->>RegexPatterns: Hole Regex
            RegexPatterns-->>Method: Regex Pattern
            Method->>Method: Replace Placeholder
        end
    end
    
    Method-->>Method: Return fertiges Pattern
    
    Note over Method: Output Pattern mit Regex
```

### Beispiel

```
Input:
  Pattern: "Version\s*=\s*'({REGEX_VERSION})'"
  Token:   ["VERSION"]
  RegexPatterns: { VERSION = "\d+\.\d+\.\d+" }

Output:
  Pattern: "Version\s*=\s*'(\d+\.\d+\.\d+)'"
```

## Performance-Überlegungen

```mermaid
graph TD
    subgraph "Komplexität"
        C1["Anzahl Matches: n"]
        C2["Anzahl Tokens pro Match: m"]
        C3["Gesamt-Komplexität: O(n × m)"]
        C1 --> C3
        C2 --> C3
    end
    
    subgraph "Optimierungen"
        O1["Back-to-Front verhindert Index-Shifting"]
        O2["Position-basiert verhindert globale Suche"]
        O3["Capture Groups fuer praezise Ersetzung"]
        O4["Keine String-Konkatenation in Schleife"]
    end
```

### Typische Szenarien

| Szenario | Matches | Tokens | Operationen | Zeit |
|----------|---------|--------|-------------|------|
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
    
    D --> D1[Gleicher Wert mehrfach]
    D --> D2[Position-basiert loest Problem]
    
    V --> V1[Token laenger/kuerzer]
    V --> V2[Substring passt automatisch an]
    
    M --> M1[Newlines in Matches]
    M --> M2[Index ueber Zeilen hinweg]
    
    E --> E1[Token Value leer]
    E --> E2[Validation verhindert dies]
    
    N --> N1[Pattern findet nichts]
    N --> N2[Return Original Content]
    
    G --> G1[Zu wenige Groups]
    G --> G2[InvalidOperationException]
```

## Zusammenfassung

```mermaid
flowchart TD
    A[PSScriptBuilderRegexHelper] --> B{Pattern Analyse}
    B -->|Placeholder| C[MODUS 1: Simple String Replace]
    B -->|Capture Groups| D[MODUS 2: Position-based Replacement]
    
    D --> E[Token Validation]
    E --> F[Pattern zu Regex]
    F --> G[Find Matches]
    G --> H[Back-to-Front Processing]
    H --> I[Capture Group Replacement]
    I --> J[Position-based Content Update]
    J --> K[Formatted Verbose Output]
    
    C --> L[Direct String Replace]
    L --> M[No Formatting Preservation]
```

### Vorteile des aktuellen Designs

1. **Formatierung bleibt erhalten**: Spaces, Tabs, Newlines werden nicht verändert
2. **Multiline-Support**: Patterns über mehrere Zeilen funktionieren
3. **Multi-Token-Support**: Mehrere Tokens in einem Pattern möglich
4. **Keine Duplikat-Probleme**: Position-basierte Ersetzung verhindert globale Änderungen
5. **Robuste Validation**: Frühzeitige Fehler bei ungültigen Tokens/Patterns
6. **Lesbare Ausgabe**: Formatierte Verbose-Messages für Debugging

### PowerShell 5.1 Kompatibilitaet

- Keine Ternary Operators
- Keine Interfaces
- for Loops statt foreach fuer Index-Kontrolle
- Constructor Overloading wird unterstuetzt
- .NET Regex mit MatchCollection funktioniert
