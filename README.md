# Anki Reader

Tmavá čtečka zdrojů karet z Anki, napsaná v Godotu 4 (GDScript).

## Spuštění
Otevři složku v Godotu 4.x (projekt je zapsaný pro 4.4+) a spusť (F5).

## Data
Karty se načítají z adresáře `anki/` v kořeni projektu. Podporované jsou:

- **Balíčky `.apkg`** (export z Anki s volbou „Podpora starších verzí Anki“). Čtou se poznámky, názvy polí, balíčky, tagy, obrázky a zvuk (mp3/ogg).
- **Textové exporty** (*Soubor → Export → Notes in Plain Text*): `.txt` / `.tsv` / `.csv`.

- Název souboru = balíček, podadresáře tvoří hierarchii (`anki/Japonstina/Slovicka.txt` → `Japonstina::Slovicka`).
- Hlavičky `#separator`, `#html`, `#tags column`, `#deck column` se respektují.
- První pole je přední strana, ostatní zadní. Podporované je HTML (`<b>`, `<i>`, `<br>`…), `{{c1::cloze}}` a pole v uvozovkách.

## Ovládání
Mezerník otočí kartu, šipky nahoru/dolů listují, P přehraje zvuk, F5 znovu načte adresář.

## Zatím nepodporováno
Nový formát `.apkg` (`collection.anki21b`, zstd + protobuf), plánování a statistiky opakování, animované GIF.
