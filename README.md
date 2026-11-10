# lib_sorter_barcode (Windows)

Libreria per leggere i barcode dalle immagini del sorter: **Code 128, Code 39, ITF, DataMatrix, QR, Aztec**.
È la stessa libreria usata da SorterNext e SorterBarcode di [teo.place](https://teo.place).

- DLL nativa, senza dipendenze (solo `kernel32` e `msvcrt`, presenti in ogni Windows)
- 64 bit (`bin/x64`) e 32 bit (`bin/x86`)
- thread safe: si possono leggere più immagini in parallelo
- versione **1.1.1** (le versioni sono i tag `v…` e le [release](https://github.com/TeoPlace/lib_sorter_barcode_windows/releases))

La versione per Linux è in [lib_sorter_barcode_linux](https://github.com/TeoPlace/lib_sorter_barcode_linux).

## Installazione e aggiornamento

**Dal terminale (PowerShell)**, senza diritti di amministratore:

```powershell
irm https://raw.githubusercontent.com/TeoPlace/lib_sorter_barcode_windows/main/install.ps1 | iex
```

Installa l'ultima versione in `%LOCALAPPDATA%\Programs\sorter_barcode`. **Per aggiornare si rilancia lo stesso comando**:
scarica la versione nuova solo se c'è, e ne controlla lo SHA-256. Con le opzioni:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/TeoPlace/lib_sorter_barcode_windows/main/install.ps1))) -AddToPath
```

| opzione | cosa fa |
|---|---|
| `-Dir <cartella>` | installa altrove |
| `-Version 1.1.1` | installa quella versione invece dell'ultima |
| `-AddToPath` | aggiunge `bin\x64` al PATH dell'utente |
| `-Check` | dice solo se c'è un aggiornamento |
| `-Uninstall` | toglie la cartella (e la voce del PATH) |

**Con git**, una versione per tag (`v1.1.1`, …):

```
git clone https://github.com/TeoPlace/lib_sorter_barcode_windows.git
git -C lib_sorter_barcode_windows pull            # aggiorna all'ultima
git -C lib_sorter_barcode_windows checkout v1.1.1 # oppure fissa una versione
```

**Download diretto** dell'ultima versione (zip con DLL, header ed esempi):
[lib_sorter_barcode_windows.zip](https://github.com/TeoPlace/lib_sorter_barcode_windows/releases/latest/download/lib_sorter_barcode_windows.zip)
· tutte le versioni nelle [release](https://github.com/TeoPlace/lib_sorter_barcode_windows/releases).

La DLL va accanto al proprio programma, o in una cartella del `PATH`.

| file | a cosa serve |
|---|---|
| `bin/x64/sorter_barcode.dll` | la libreria, processi a 64 bit |
| `bin/x86/sorter_barcode.dll` | la libreria, processi a 32 bit |
| `bin/*/sorter_barcode.lib` | import library per MSVC |
| `bin/*/libsorter_barcode.dll.a` | import library per MinGW / gcc |
| `bin/*/sorter_barcode.def` | elenco delle funzioni esportate |
| `include/sorter_barcode.h` | l'header C |
| `examples/` | esempi in C e Python |
| `VERSION` | la versione |

## Le funzioni

```c
const char *sb_version(void);
int sb_read_bmp_file(const char *path, const char *settings, int fast, char *out, int out_cap, int *needed);
int sb_read_gray(const uint8_t *px, int width, int height, int stride, const char *settings, int fast,
                 char *out, int out_cap, int *needed);
```

- `settings`: `"ALL"`, `"1D"` o `"2D"`.
- `fast`: `0` fa tutti i tentativi (consigliato), `1` salta i più lenti e può perdere qualche codice difficile.
- Il risultato è il numero di codici trovati, oppure un errore: `-1` argomenti sbagliati, `-2` immagine illeggibile,
  `-3` `out` troppo piccolo (in `needed` c'è la dimensione giusta: richiamare), `-4` memoria esaurita.
- In `out` c'è un JSON, un oggetto per codice:

```
[
{"type":"code128","value":"RB0002627784"}
]
```

  Se non ci sono codici, prima del JSON c'è la riga `no 1d or 2d barcodes found`.
- `sb_read_bmp_file` legge BMP non compressi a 1, 4, 8, 16, 24 e 32 bit; le immagini a colori sono lette in grigio.
  Il percorso è nella code page ANSI di Windows. Per altri formati, o per percorsi con caratteri fuori dalla
  code page, si decodifica l'immagine in proprio e la si passa in grigio a 8 bit con `sb_read_gray`.

## Esempi

**C con gcc (MinGW):**

```
gcc -Iinclude -o leggi.exe examples/leggi.c -Lbin/x64 -lsorter_barcode
copy bin\x64\sorter_barcode.dll .
leggi.exe C:\immagini\lettera.bmp
```

**C con MSVC:**

```
cl /Iinclude examples\leggi.c bin\x64\sorter_barcode.lib
```

**C#:**

```csharp
[DllImport("sorter_barcode.dll", CallingConvention = CallingConvention.Cdecl)]
static extern int sb_read_bmp_file([MarshalAs(UnmanagedType.LPStr)] string path, [MarshalAs(UnmanagedType.LPStr)] string settings,
                                   int fast, byte[] output, int outputCapacity, out int needed);

var buffer = new byte[8192];
int n = sb_read_bmp_file(@"C:\immagini\lettera.bmp", "ALL", 0, buffer, buffer.Length, out int needed);
if (n == -3) { buffer = new byte[needed]; n = sb_read_bmp_file(@"C:\immagini\lettera.bmp", "ALL", 0, buffer, buffer.Length, out needed); }
string json = Encoding.UTF8.GetString(buffer, 0, Array.IndexOf(buffer, (byte)0));
```

**Python** (ctypes, nessun pacchetto da installare):

```
python examples\leggi.py C:\immagini\lettera.bmp
```

## Pubblicare una versione nuova

1. Ricostruire la libreria dal sorgente, sostituire i file in `bin/` (o `lib/`) e scrivere la versione in `VERSION`.
2. `git commit`, `git tag v<versione>`, `git push --follow-tags`.
3. Creare la release `v<versione>` con il pacchetto e il suo `.sha256` (stesso nome di file a ogni versione, così
   il link «latest» e lo script di installazione trovano sempre l'ultima).

## Licenza

MIT, vedi [LICENSE](LICENSE).
