# Anki Reader

Tmavá čtečka zdrojů karet z Anki, napsaná v Godotu 4 (GDScript).

## Spuštění
Otevři složku v Godotu 4.x (projekt je zapsaný pro 4.4+) a spusť (F5).

## Data
Karty se načítají z adresáře `anki/` v kořeni projektu. V Anki použij
*Soubor → Export → Notes in Plain Text* a výsledný `.txt` / `.tsv` / `.csv` ulož sem.

- Název souboru = balíček, podadresáře tvoří hierarchii (`anki/Japonstina/Slovicka.txt` → `Japonstina::Slovicka`).
- Hlavičky `#separator`, `#html`, `#tags column`, `#deck column` se respektují.
- První pole je přední strana, ostatní zadní. Podporované je HTML (`<b>`, `<i>`, `<br>`…), `{{c1::cloze}}` a pole v uvozovkách.
- Přibalené soubory v `anki/` jsou jen ukázky.

## Ovládání
Mezerník otočí kartu, šipky nahoru/dolů listují, F5 znovu načte adresář.

## Zatím nepodporováno
Balíčky `.apkg` (SQLite + zstd), plánování a statistiky opakování, média (obrázky, zvuk).
