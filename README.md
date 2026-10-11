# Finance obcí ČR – analýza hospodaření obcí (2025)

Datově-analytický projekt zkoumající, jak se liší finanční hospodaření českých obcí podle velikosti a kraje: odkud berou peníze, na co je utrácejí a jak přesně plánují rozpočet oproti skutečnosti.

Vznikl jako portfolio projekt pro pozici datového analytika – cílem bylo jít dál než standardní agregace a ukázat práci s CTE, window funkcemi, časově platnými joiny a datovou konsolidací na reálných, neupravených vládních datech.

## Zdroj dat

- [data.mf.gov.cz](https://data.mf.gov.cz) – výkaz FIN 2-12 M (FinM201) za rok 2025, všechny obce ČR
- Číselníky Ministerstva financí: obce, paragrafy (odvětví), položky (druh příjmu/výdaje), NUTS kódy
- cca 6 254 obcí, 1,3+ milionu řádků transakcí po konsolidaci

## Architektura

PostgreSQL, ELT přístup (ne ETL) – data se nahrávají syrová (`COPY ... TEXT`) a veškerá transformační logika žije v SQL:

```
stg/   – staging, syrová data 1:1 z CSV (vše TEXT)
dim/   – dimenze (obce, paragrafy, položky, oddíly, obyvatelstvo) s časovou platností
fact/  – fact.rozpocet, 1 řádek = obec × rok × typ × paragraf × položka
mart/  – předpočítané analytické pohledy (obec_rok, obec_rok_oddil)
```

## Použité SQL techniky

- CTE (vícero-úrovňové)
- Window funkce: `RANK() OVER (PARTITION BY ...)`, `SUM() OVER (PARTITION BY ...)`
- `percentile_cont()` pro mediány
- `FILTER (WHERE ...)` pro podmíněnou agregaci
- Časové joiny podle platnosti (`make_date(rok,1,1) BETWEEN datefrom AND dateto`) – obdoba slowly changing dimension
- Datová konsolidace podle vyhlášky 344/2019 Sb. (odstranění vnitřních převodů mezi vlastními účty obce)
- Ošetření netriviálních datových problémů: SAP formát čísel se znaménkem na konci řetězce, NULL propagace přes `COALESCE`, dělení nulou přes `NULLIF`

## Klíčová zjištění

### Blok A – Výdaje na obyvatele podle kraje

Nejvyšší výdaje na obyvatele má jednoznačně Praha, následovaná Plzeňským a Jihomoravským krajem. Rozdíl mezi nejvyšším a nejnižším krajem je zhruba 2,3×.

| kraj | počet obcí | vážený průměr (Kč/obyv.) | pořadí |
| :--- | ---: | ---: | ---: |
| Hlavní město Praha | 1 | 88 684 | 1 |
| Plzeňský kraj | 501 | 46 072 | 2 |
| Jihomoravský kraj | 672 | 44 745 | 3 |
| Jihočeský kraj | 623 | 44 274 | 4 |
| Moravskoslezský kraj | 300 | 43 945 | 5 |
| Kraj Vysočina | 704 | 43 464 | 6 |
| Olomoucký kraj | 401 | 41 156 | 7 |
| Karlovarský kraj | 133 | 40 839 | 8 |
| Liberecký kraj | 215 | 40 121 | 9 |
| Zlínský kraj | 307 | 39 782 | 10 |
| Královéhradecký kraj | 448 | 39 571 | 11 |
| Pardubický kraj | 451 | 38 854 | 12 |
| Ústecký kraj | 354 | 38 278 | 13 |
| Středočeský kraj | 1 144 | 38 180 | 14 |

### Blok B – Odkud obce berou peníze

Struktura příjmů (podíl daní, transferů) je napříč velikostmi obcí poměrně stabilní, ale výše daňových příjmů na obyvatele ne – nejmenší obce mají mírně nadprůměrné daňové příjmy na hlavu, největší obce (20 000+) výrazně nejvyšší. Potvrzuje to efekt rozpočtového určení daní (RUD), které přerozděluje víc peněz na hlavu směrem k větším obcím.

| kategorie (počet obyvatel) | podíl daňových příjmů | podíl transferů | daňové příjmy / obyvatele |
| :--- | ---: | ---: | ---: |
| 1: do 199 | 64,2 % | 18,9 % | 27 037 Kč |
| 2: 200–499 | 64,7 % | 19,9 % | 25 553 Kč |
| 3: 500–999 | 67,1 % | 17,3 % | 25 407 Kč |
| 4: 1 000–1 999 | 68,0 % | 16,0 % | 25 410 Kč |
| 5: 2 000–4 999 | 68,1 % | 16,0 % | 25 339 Kč |
| 6: 5 000–19 999 | 64,0 % | 19,9 % | 26 223 Kč |
| 7: 20 000 a více | 70,0 % | 19,6 % | 43 645 Kč |

### Blok C – Na co obce utrácejí nejvíc (top 5 oddílů, celá ČR)

| oddíl | výdaje celkem | pořadí |
| :--- | ---: | ---: |
| Doprava | 91,1 mld. Kč | 1 |
| Vzdělávání a školské služby | 84,5 mld. Kč | 2 |
| Státní moc, státní správa, územní samospráva a politické strany | 82,3 mld. Kč | 3 |
| Bydlení, komunální služby a územní rozvoj | 66,5 mld. Kč | 4 |
| Ochrana životního prostředí | 38,6 mld. Kč | 5 |

U malých obcí v detailnějším rozkladu (viz `05_analyzy.sql`, blok C) dominuje místo dopravy "Státní moc, státní správa" – provoz úřadu a odměny zastupitelstva, které musí mít každá obec bez ohledu na velikost.

### Blok D – Jak přesně obce plánují rozpočet

Příjmy se plní téměř přesně podle upraveného rozpočtu (medián 0,99–1,02), výdaje systematicky jen z 78–84 % (typicky investice přesunuté do dalšího roku). Menší obce zároveň upravují svůj rozpočet v průběhu roku výrazněji (medián úpravy ~1,20 u nejmenší kategorie vs. ~1,10 u středních a velkých obcí).

| kategorie (počet obyvatel) | medián plnění výdajů | medián plnění příjmů | medián úpravy výdajů | medián úpravy příjmů |
| :--- | ---: | ---: | ---: | ---: |
| 1: do 199 | 0,78 | 0,99 | 1,20 | 1,19 |
| 2: 200–499 | 0,81 | 0,99 | 1,18 | 1,17 |
| 3: 500–999 | 0,79 | 1,00 | 1,16 | 1,15 |
| 4: 1 000–1 999 | 0,78 | 1,00 | 1,13 | 1,14 |
| 5: 2 000–4 999 | 0,81 | 1,00 | 1,10 | 1,11 |
| 6: 5 000–19 999 | 0,84 | 1,02 | 1,11 | 1,10 |
| 7: 20 000 a více | 0,82 | 1,02 | 1,16 | 1,09 |

## Vizualizace

Power BI dashboard s mapou obcí je plánovaný – zatím není součástí repozitáře, přidá se sem po dokončení.

## Jak to spustit

1. Stáhnout data z data.mf.gov.cz (viz `docs/mapping_sloupcu.md` pro popis sloupců) a uložit do `data/raw/`.
2. V `sql/01_staging.sql` upravit absolutní cesty u příkazů `COPY ... FROM` na vlastní umístění.
3. Spustit skripty v pořadí `01_staging.sql → 02_dim_fact.sql → 03_mart.sql → 04_checks.sql → 05_analyzy.sql`.
4. `04_checks.sql` ověří integritu pipeline (prázdný výsledek = vše v pořádku).

## Struktura projektu

```
sql/              – pipeline + analýzy
sql/exploration/  – zdokumentovaný průzkum dat (proč jsou filtry a rozhodnutí taková, jaká jsou)
docs/             – datový slovník
notebooks/        – příprava/konsolidace vstupních CSV
```

## Známá omezení

- `dim.obce` odráží aktuální stav obcí (kraj, okres), ne stav platný zpětně v daném roce – pro rok 2025 to nevadí, ale při rozšíření na historická data (fáze 2) bude potřeba revize.
- Data zatím pokrývají jen rok 2025; roky 2020–2024 jsou stažené a čekají na fázi 2.
- Plánovaný Power BI dashboard (mapa obcí) zatím není součástí repozitáře.
