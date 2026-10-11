-- =====================================================================
-- PRŮZKUM: stg.finm201 (výkaz FinM 2-01, rok 2025)
-- Účel: záznam zjištění, na kterých stojí fact.rozpocet.
-- Formát: Otázka / Zjištění / Řešení + dotaz k opětovnému ověření.
-- Bloky 6 a 7 čtou dim.obce, spouštět po 02_dim_fact.sql.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Sentinel řádek
-- Otázka:   Co je řádek s prázdným paragrafem?
-- Zjištění: Jeden technický řádek: zc_vykaz = 'ZZZ', fiscper = '0000000',
--           zc_ico = '00000000', ci_type = '0'. Typický "konec dat"
--           záznam z exportu, není to reálná transakce.
-- Řešení:   Do factu nejde – vyřadí ho JOIN na dim.obce.
-- ---------------------------------------------------------------------
SELECT *
FROM stg.finm201
WHERE zc_vykaz = 'ZZZ';


-- ---------------------------------------------------------------------
-- 2) Které hodnoty jsou konstantní
-- Zjištění: fiscper = 2025012 u všech skutečných řádků (soubor je roční,
--           kumulativní k prosinci → žádný filtr období není potřeba).
--           zc_vykaz = 051, zc_vtab = 000100 / 000200 (viz bod 3).
-- ---------------------------------------------------------------------
SELECT DISTINCT zc_vykaz, zc_vtab, fiscper
FROM stg.finm201;


-- ---------------------------------------------------------------------
-- 3) Význam ci_type a zc_vtab
-- Otázka:   Co znamenají hodnoty ci_type a kde je jejich číselník?
-- Zjištění: Číselník není (ci_type je sloupec samotného výkazu).
--           Z dat: ci_type 2 = příjmy (třídy položek 1–4),
--                  ci_type 3 = výdaje (třídy 5–6), 0 = sentinel.
--           zc_vtab je s ci_type 1:1 (000100 = příjmy, 000200 = výdaje),
--           proto ho fact nenese.
--           Třída 8 (financování) ve výkazu NENÍ → součet výdajů není
--           zkreslený splátkami úvěrů. Rozdíl příjmy – výdaje z tohoto
--           výkazu ale není saldo po financování.
--           POZOR: význam kódů je odvozen z dat, ne z dokumentace.
-- Řešení:   fact.typ = CASE ci_type '2' → 'prijem', '3' → 'vydaj'
--           (bez ELSE – neznámá hodnota má selhat, ne se schovat).
-- ---------------------------------------------------------------------
SELECT zc_vtab, ci_type, COUNT(*) AS pocet_radku
FROM stg.finm201
GROUP BY 1, 2
ORDER BY 1, 2;

-- Určuje položka ci_type jednoznačně? Očekávání: prázdný výsledek.
SELECT zcmmt_itm
FROM stg.finm201
WHERE ci_type <> '0'
GROUP BY zcmmt_itm
HAVING COUNT(DISTINCT ci_type) > 1;


-- ---------------------------------------------------------------------
-- 4) Paragraf u příjmů
-- Otázka:   Mají příjmy paragraf?
-- Zjištění: Daňové příjmy (třída 1) mají paragraf 0000. Nedaňové
--           příjmy (třída 2) a další paragraf mají (váží se k činnosti,
--           která je vytváří). Tvrzení "příjmy nemají paragraf" tedy
--           neplatí obecně.
-- Důsledek: "Příjmy podle odvětví" jdou počítat, jen ne u daní.
-- ---------------------------------------------------------------------
SELECT LEFT(zcmmt_itm, 1) AS trida,
       COUNT(*)                                     AS pocet_radku,
       COUNT(*) FILTER (WHERE func_area = '0000')   AS z_toho_paragraf_0000
FROM stg.finm201
WHERE ci_type = '2'
GROUP BY 1
ORDER BY 1;


-- ---------------------------------------------------------------------
-- 5) Unikátnost řádku
-- Zjištění: Kombinace (zc_ico, ci_type, func_area, zcmmt_itm) se
--           neopakuje → z ní (spolu s rokem) je primární klíč factu.
-- Očekávání: prázdný výsledek.
-- ---------------------------------------------------------------------
SELECT zc_ico, ci_type, func_area, zcmmt_itm, COUNT(*) AS pocet
FROM stg.finm201
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------
-- 6) IČO ve výkazu, která nejsou v dim.obce (717)
-- Otázka:   Co jsou ta IČO? (Původní domněnka "školy" se nepotvrdila.)
-- Zjištění: 703 IČO se zc_forma 771 (svazky obcí, mikroregiony),
--           13 IČO se zc_forma 804 (kraje), 1 sentinel (bez formy).
--           Kraje jsou 13, ne 14, protože Praha je vedena jako obec.
-- Rozhodnutí: Do factu jdou jen obce (JOIN dim.obce). Svazky a kraje
--           zůstávají ve stg, lze je přidat ve fázi 2.
-- ---------------------------------------------------------------------
SELECT c.zc_forma, c.zc_duif, COUNT(DISTINCT f.zc_ico) AS pocet_ico
FROM stg.finm201 f
LEFT JOIN dim.obce o ON f.zc_ico = o.zc_ico
LEFT JOIN stg.ciselnik_obce c ON f.zc_ico = c.zc_ico AND c.dateto = '99991231'
WHERE o.zc_ico IS NULL
GROUP BY 1, 2
ORDER BY 3 DESC;


-- ---------------------------------------------------------------------
-- 7) Příznak zc_fcopy ("zkopírováno")
-- Otázka:   Co znamená a ovlivní součty?
-- Zjištění: 'X' má 149 řádků ze 3 IČO, z toho 1 obec (Cekov). Částky
--           jsou reálné (nenulové). Význam příznaku není zdokumentován.
-- Řešení:   Řádky zůstávají ve factu, sloupec zkopirovano (BOOLEAN)
--           umožní je kdykoli odfiltrovat. Vyřadit jde později,
--           ztracená informace se nevrací.
-- ---------------------------------------------------------------------
SELECT COUNT(DISTINCT f.zc_ico) AS pocet_ico,
       COUNT(DISTINCT CASE WHEN o.zc_ico IS NOT NULL THEN f.zc_ico END) AS z_toho_obce,
       COUNT(*) AS radku
FROM stg.finm201 f
LEFT JOIN dim.obce o ON f.zc_ico = o.zc_ico
WHERE f.zc_fcopy = 'X';


-- ---------------------------------------------------------------------
-- 8) Formát částek (zu_rozsch, zu_rozpzm, zu_rozkz)
-- Otázka:   Proč INSERT do fact.rozpocet spadl na
--           'invalid input syntax for type numeric: "294650.00-"'?
-- Zjištění: Export je ze systému, který zapisuje znaménko NA KONEC
--           hodnoty: poslední znak je mezera (kód 32, 1 352 690 hodnot
--           u zu_rozkz) nebo minus (kód 45, 933 hodnot). Minus na
--           konci mají 67 / 275 / 933 hodnot (rozsch / rozpzm / rozkz)
--           před filtrem na obce; po JOINu na dim.obce zbývá
--           59 / 257 / 872.
--           Záporné částky jsou reálná data (storna, vratky) – nemazat.
-- Poznámka: Moje první diagnostická kontrola měla regex bez mezery
--           na konci a označila jako "jiný formát" všech ~1,35 mil.
--           řádků. Chyba návrhu kontroly, ne dat – oprava níže.
-- Řešení:   TRIM + CASE: končí-li hodnota minusem, odstranit ho
--           a vynásobit -1, jinak převést přímo (viz 02_dim_fact.sql).
-- ---------------------------------------------------------------------
SELECT RIGHT(zu_rozkz, 1) AS posledni_znak,
       ASCII(RIGHT(zu_rozkz, 1)) AS kod,
       COUNT(*) AS pocet
FROM stg.finm201
GROUP BY 1, 2
ORDER BY 3 DESC;

SELECT
    COUNT(*) FILTER (WHERE zu_rozsch LIKE '%-') AS rozsch_minus,
    COUNT(*) FILTER (WHERE zu_rozpzm LIKE '%-') AS rozpzm_minus,
    COUNT(*) FILTER (WHERE zu_rozkz  LIKE '%-') AS rozkz_minus
FROM stg.finm201;

-- Správný regex (mezera nebo minus na konci). Očekávání: 0 řádků
-- (sentinel s NULL hodnotami se do porovnání nedostane).
SELECT zu_rozsch, zu_rozpzm, zu_rozkz
FROM stg.finm201
WHERE zu_rozsch !~ '^[0-9]+\.[0-9]+[ -]$'
   OR zu_rozpzm !~ '^[0-9]+\.[0-9]+[ -]$'
   OR zu_rozkz  !~ '^[0-9]+\.[0-9]+[ -]$'
LIMIT 20;