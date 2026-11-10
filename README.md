# sorter-barcode per Windows

Legge i barcode dalle immagini BMP del sorter e dai PDF: **Code 128, Code 39, ITF, DataMatrix, QR, Aztec**.
C'è un comando da usare nel terminale e una libreria per chi scrive programmi. È lo stesso lettore di
SorterNext e SorterBarcode di [teo.place](https://sorterbarcode.teo.place/).

La versione per Linux è in [lib_sorter_barcode_linux](https://github.com/TeoPlace/lib_sorter_barcode_linux).

## Installare

In PowerShell:

```powershell
irm https://raw.githubusercontent.com/TeoPlace/lib_sorter_barcode_windows/main/install.ps1 | iex
```

Non servono diritti di amministratore. Il comando `sorter-barcode` si può usare subito, e anche nei terminali
che apri dopo.

## Leggere un file

```powershell
sorter-barcode C:\immagini\lettera.bmp
sorter-barcode C:\immagini\lettera.pdf
```

Risponde con i codici trovati:

```
[
{"type":"code128","value":"RB0002627784"},
{"type":"data-matrix","value":"RB0002627784-BACK"}
]
```

Se non trova niente scrive `no 1d or 2d barcodes found`.

Di un PDF legge le immagini di tutte le pagine e dà i codici tutti insieme, ognuno una volta. Legge i PDF
fatti di immagini (scanner, sorter, stampe in PDF di foto); non legge i codici disegnati come testo o
grafica vettoriale, né i PDF protetti da password o con immagini JBIG2, JPEG 2000 o JPEG progressivo.
Nei PDF del sorter le immagini sono in bianco e nero puro (1 bit), come i TIFF: se ne legge solo una parte.

| per | scrivi |
|---|---|
| più file insieme (un blocco per file, nello stesso ordine) | `sorter-barcode a.bmp b.bmp` |
| tutti i BMP e i PDF di una cartella | `Get-ChildItem C:\immagini\* -Include *.bmp,*.pdf \| % { $_.Name; sorter-barcode $_.FullName }` |
| solo i codici a barre lineari, o solo DataMatrix/QR/Aztec | `sorter-barcode 1D lettera.bmp`, `sorter-barcode 2D lettera.bmp` |
| andare più veloce (può perdere i codici più difficili) | `sorter-barcode --fast lettera.bmp` |
| sapere la versione | `sorter-barcode --version` |

## Aggiornare

Si rilancia lo stesso comando di installazione: scarica la versione nuova solo se c'è.
Per sapere soltanto se c'è un aggiornamento:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/TeoPlace/lib_sorter_barcode_windows/main/install.ps1))) -Check
```

Al posto di `-Check`: `-Uninstall` per disinstallare, `-Version 1.2.0` per una versione precisa.

## Scaricare senza installare

[lib_sorter_barcode_windows.zip](https://github.com/TeoPlace/lib_sorter_barcode_windows/releases/latest/download/lib_sorter_barcode_windows.zip)
è sempre l'ultima versione. Si estrae dove si vuole e si usa `bin\x64\sorter-barcode.exe`.
Le versioni precedenti sono nelle [release](https://github.com/TeoPlace/lib_sorter_barcode_windows/releases).

## Per chi scrive programmi

La libreria è `bin\x64\sorter_barcode.dll` (`bin\x86` per i programmi a 32 bit) e non ha dipendenze.
La funzione da chiamare è una (per BMP e PDF):

```c
int sb_read_file(const char *path, const char *settings, int fast, char *out, int out_cap, int *needed);
```

Legge il file e scrive in `out` lo stesso testo del comando; restituisce quanti codici ha trovato, o un numero
negativo se qualcosa non va. `settings` è `"ALL"`, `"1D"` o `"2D"`, `fast` è 0 o 1. Il resto è spiegato in
[include/sorter_barcode.h](include/sorter_barcode.h); in [examples](examples) c'è un esempio in C e uno in Python.
Per collegarla: `sorter_barcode.lib` con MSVC, `libsorter_barcode.dll.a` con gcc.

Con git ogni versione è un tag (`v1.2.0`, …): `git clone` di questo repository e poi `git pull` per aggiornare.

## Licenza

MIT, vedi [LICENSE](LICENSE).
