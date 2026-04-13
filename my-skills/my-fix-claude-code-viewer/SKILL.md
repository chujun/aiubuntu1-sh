---
name: my-fix-claude-code-viewer
description: Diagnostica e ripara il servizio claude-code-viewer che non si avvia — JSONL corrotto, errori di permessi, dipendenze mancanti, problemi di binding di rete.
origin: open-spec-first
---

# Fix Claude Code Viewer Service

Diagnostica e ripara il servizio `claude-code-viewer` systemd quando non si avvia o si blocca in loop.

## Quando Attivare

- `systemctl --user start claude-code-viewer.service` fallisce
- Il servizio è in stato `activating (auto-restart)` con exit-code
- L'errore è `SyntaxError: Expected ',' or '}' after property value in JSON`
- HTTP `http://localhost:3400/` non risponde

---

## Step 1: Verifica Stato del Servizio

```bash
systemctl --user status claude-code-viewer.service
journalctl --user -u claude-code-viewer.service -n 50
```

Cerca questi pattern nell'output:

| Pattern | Causa | Soluzione |
|---------|-------|-----------|
| `SyntaxError` in `parseJsonl` | File JSONL corrotto | Step 2 |
| `aggregateTokenUsageAndCost` | Session cache corrotta | Step 2 |
| `Permission denied` | Problema permessi file | Step 3 |
| `EADDRINUSE` | Porta 3400 occupata | Step 4 |
| `ENOENT` / `MODULE_NOT_FOUND` | Dipendenze mancanti | Step 5 |

---

## Step 2: Trova e Ripara File JSONL Corrotti

### 2a: Trova tutti i file JSON/JSONL in `~/.claude`

```bash
find ~/.claude -name "*.jsonl" -o -name "*.json" 2>/dev/null | head -50
```

### 2b: Valida ogni file JSONL

```bash
node -e "
const fs = require('fs');
const path = require('path');

function findJsonFiles(dir, files = []) {
    if (!fs.existsSync(dir)) return files;
    const items = fs.readdirSync(dir, { withFileTypes: true });
    for (const item of items) {
        const fullPath = path.join(dir, item.name);
        if (item.isDirectory() && !item.name.startsWith('.')) {
            findJsonFiles(fullPath, files);
        } else if (item.isFile() && (item.name.endsWith('.json') || item.name.endsWith('.jsonl'))) {
            files.push(fullPath);
        }
    }
    return files;
}

const jsonFiles = findJsonFiles(process.env.HOME + '/.claude');
console.log('Found', jsonFiles.length, 'JSON/JSONL files');

for (const f of jsonFiles) {
    try {
        const content = fs.readFileSync(f, 'utf8');
        if (f.endsWith('.jsonl')) {
            content.split('\n').forEach((line, i) => {
                if (line.trim()) {
                    try { JSON.parse(line); }
                    catch(e) {
                        console.log('ERROR in', f, 'line', i+1, ':', e.message);
                        console.log('Context:', JSON.stringify(line.slice(0, 200)));
                    }
                }
            });
        } else {
            JSON.parse(content);
        }
    } catch(e) {
        console.log('FILE ERROR:', f, '-', e.message);
    }
}
"
```

### 2c: Ripara il File Corrotto

Se viene trovato un errore in un file `.jsonl`:

1. **Backup del file**
   ```bash
   cp "/path/to/corrupted/file.jsonl" "/path/to/corrupted/file.jsonl.bak"
   ```

2. **Analizza la natura dell'errore**
   ```bash
   node -e "
   const fs = require('fs');
   const file = '/path/to/corrupted/file.jsonl';
   const content = fs.readFileSync(file, 'utf8');
   const lines = content.split('\n');
   // Stampa la linea corrotta (sostituire N con il numero di linea dal report)
   console.log('Line N:', JSON.stringify(lines[N-1]?.slice(0, 300)));
   console.log('Line N+1:', JSON.stringify(lines[N]?.slice(0, 300)));
   "
   ```

3. **Tipici pattern di danno e relative riparazioni**

   **Pattern A: Linee fuse insieme (molto comune)**
   ```
   Line 727: "...\"isSidechain\":false,\"message\":{\"id\":\"061b...<termina improvvisamente>
   Line 728: "\",\"version\":\"2.1.87\",\"gitBranch\":\"claude/...<inizia con frammento>"
   ```
   → Due linee JSONL adiacenti sono state unite. Soluzione: rimuovere entrambe le linee corrotte.
   ```bash
   node -e "
   const fs = require('fs');
   const file = '/path/to/corrupted/file.jsonl';
   const lines = fs.readFileSync(file, 'utf8').split('\n');
   const cleanLines = lines.filter((_, i) => i !== N-1 && i !== N); // N = linea corrotta
   fs.writeFileSync(file, cleanLines.join('\n') + '\n');
   console.log('Original:', lines.length, 'lines');
   console.log('Cleaned:', cleanLines.length, 'lines');
   "
   ```

   **Pattern B: JSON troncato**
   ```
   Line 727: {"id":"abc","content":"
   (EOF improvviso)
   ```
   → L'ultima linea è troncata. Soluzione: rimuovere la linea incompleta.
   ```bash
   node -e "
   const fs = require('fs');
   const file = '/path/to/corrupted/file.jsonl';
   const lines = fs.readFileSync(file, 'utf8').split('\n');
   // Verifica che l'ultima linea sia incompleta
   const lastLine = lines[lines.length - 1];
   try { JSON.parse(lastLine); console.log('Last line is valid'); }
   catch(e) {
     console.log('Last line is corrupt, removing it');
     lines.pop();
     fs.writeFileSync(file, lines.join('\n') + '\n');
   }
   "
   ```

   **Pattern C: Caratteri non-UTF8 nel file**
   → Il file contiene byte sequences non validi per UTF-8.
   ```bash
   # Verifica con hexdump
   xxd /path/to/file.jsonl | grep -A2 " Position of corruption"
   # Soluzione: ricreare il file filtrando caratteri non validi
   node -e "
   const fs = require('fs');
   const file = '/path/to/file.jsonl';
   let content = fs.readFileSync(file);
   // Rimuovi byte non-UTF8
   content = content.toString('utf8').replace(/\ufffd/g, '');
   fs.writeFileSync(file, content);
   "
   ```

### 2d: Verifica la Riparazione

```bash
node -e "
const fs = require('fs');
const file = '/path/to/repaired/file.jsonl';
const content = fs.readFileSync(file, 'utf8');
const lines = content.split('\n');
let error = null;
lines.forEach((line, i) => {
    if (line.trim()) {
        try { JSON.parse(line); }
        catch(e) { error = 'Line ' + (i+1) + ': ' + e.message; }
    }
});
if (error) console.log('Still has error:', error);
else console.log('File is valid! Lines:', lines.length);
"
```

---

## Step 3: Verifica Permessi

```bash
ls -la ~/.config/systemd/user/claude-code-viewer.service
ls -la ~/.nvm/versions/node/*/bin/claude-code-viewer 2>/dev/null
```

Se il servizio o il binario non sono leggibili:

```bash
chmod 644 ~/.config/systemd/user/claude-code-viewer.service
chmod 755 ~/.nvm/versions/node/*/bin/claude-code-viewer
```

---

## Step 4: Verifica Porta 3400

```bash
ss -tlnp | grep 3400
lsof -i :3400 2>/dev/null
```

Se la porta è occupata:

```bash
# Trova e ferma il processo
fuser -k 3400/tcp
# Oppure se il servizio è già in esecuzione come servizio
systemctl --user stop claude-code-viewer.service
sleep 2
```

---

## Step 5: Verifica Dipendenze Node.js

```bash
node --version
npm list -g @kimuson/claude-code-viewer 2>/dev/null
/root/.nvm/versions/node/*/bin/claude-code-viewer --version 2>/dev/null
```

Se la versione di Node.js è troppo vecchia o il pacchetto non è installato:

```bash
# Reinstalla il viewer
npm install -g @kimuson/claude-code-viewer
```

---

## Step 6: Riavvia il Servizio

```bash
systemctl --user daemon-reload
systemctl --user enable claude-code-viewer.service
systemctl --user start claude-code-viewer.service
sleep 3
systemctl --user status claude-code-viewer.service
```

---

## Step 7: Verifica HTTP

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3400/
```

Deve restituire `200`.

---

## Riparazione Completa Automatica

Per eseguire tutti i passaggi automaticamente:

```bash
#!/bin/bash
set -e

echo "=== Claude Code Viewer Fix Script ==="

# Stop servizio
systemctl --user stop claude-code-viewer.service 2>/dev/null || true

# Trova file JSONL corrotti
echo "Searching for corrupted JSONL files..."
CORRUPTED=$(find ~/.claude -name "*.jsonl" 2>/dev/null | while read f; do
  node -e "
    const fs = require('fs');
    const content = fs.readFileSync('$f', 'utf8');
    const lines = content.split('\n');
    lines.forEach((line, i) => {
      if (line.trim()) {
        try { JSON.parse(line); }
        catch(e) { console.log('$f:' + (i+1)); process.exit(1); }
      }
    });
  " 2>/dev/null || echo "$f"
done)

if [ -n "$CORRUPTED" ]; then
  echo "Found corrupted files: $CORRUPTED"
  echo "Manual intervention required. Run with --verbose for details."
else
  echo "No corrupted JSONL files found."
fi

# Riavvia servizio
echo "Starting service..."
systemctl --user start claude-code-viewer.service
sleep 3

# Verifica
STATUS=$(systemctl --user is-active claude-code-viewer.service)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3400/ 2>/dev/null || echo "000")

echo "Service status: $STATUS"
echo "HTTP status: $HTTP_CODE"

if [ "$STATUS" = "active" ] && [ "$HTTP_CODE" = "200" ]; then
  echo "=== SUCCESS ==="
else
  echo "=== FAILED ==="
  systemctl --user status claude-code-viewer.service --no-pager
fi
```

---

## Casi Noti

| Errore | Causa | Fix |
|--------|-------|-----|
| `SyntaxError: Expected ',' or '}' after property value in JSON at position 899` | Session JSONL file con linee fuse insieme | Rimuovere le 2 linee corrotte dal file `51c1d5e9-*.jsonl` |
| Servizio in loop di restart con `Result: exit-code` | JSONL corrotto in projects cache | Riparare il file come in Step 2 |
| `11 projects cache initialized` ma poi crash su `Initializing sessions cache` | Session cache corrotta, non projects cache | Verificare i file `.jsonl` nelle directories dei projects |
