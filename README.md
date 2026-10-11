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

**Příjmy** – struktura (daně ~64–70 %, nedaňové ~9–14 %, kapitálové ~1–4 %, transfery ~16–20 %) je napříč velikostmi obcí stabilní, ale výše daňových příjmů na obyvatele ne: nejmenší obce mají mírně nadprůměrné daňové příjmy na hlavu, největší obce (20 000+) výrazně nejvyšší – potvrzuje to efekt rozpočtového určení daní (RUD), který přerozděluje víc peněz na hlavu směrem k větším obcím (Praha je extrémní, ale efekt platí obecně).

**Výdaje** – u malých obcí dominuje "Státní moc, státní správa" (provoz úřadu + odměny zastupitelstva), protože zastupitelstvo musí mít každá obec bez ohledu na velikost – náklad se s rostoucí obcí ředí pomaleji než jiné položky. U středních obcí dominuje "Bydlení, komunální služby".

**Plánování** – příjmy se plní téměř přesně podle upraveného rozpočtu (medián 0,99–1,02), výdaje systematicky jen z 78–84 % (typicky investice přesunuté do dalšího roku). Menší obce upravují svůj rozpočet v průběhu roku výrazněji než velké.

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
