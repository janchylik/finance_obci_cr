-- =====================================================================
-- PRŮZKUM: číselníky (NUTS, paragrafy, položky)
-- Účel: záznam zjištění, na kterých stojí dim.obce (kraj/okres),
--       dim.paragrafy a dim.polozky.
-- Formát: Otázka / Zjištění / Řešení + dotaz k opětovnému ověření.
-- Bloky 5–9 čtou i stg.finm201, spouštět po 01_staging.sql.
-- =====================================================================


-- =====================================================================
-- NUTS (stg.ciselnik_nuts)
-- Pozor: sloupce se jmenují jinak než u ostatních číselníků:
--        zc_platod / zc_platdo (ne datefrom / dateto), txtlg (ne txtxl).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Staré a nové kódy krajů
-- Otázka:   Proč jsou Vysočina a Jihomoravský kraj v číselníku dvakrát?
-- Zjištění: Kódy se v roce 2011 změnily: CZ061/CZ062 (platné do
--           20110731) → CZ063/CZ064 (platné dodnes).
-- Řešení:   Při joinu vždy filtr zc_platdo = '99991231', jinak vznikají
--           duplicitní nebo zastaralé překlady.
-- ---------------------------------------------------------------------
SELECT zc_nuts, zc_platod, zc_platdo, txtlg
FROM stg.ciselnik_nuts
WHERE zc_nuts IN ('CZ061', 'CZ062', 'CZ063', 'CZ064')
ORDER BY zc_nuts;

-- ---------------------------------------------------------------------
-- 2) Kraje (5 znaků) – očekávám 14 platných řádků
-- ---------------------------------------------------------------------
SELECT zc_nuts, txtlg
FROM stg.ciselnik_nuts
WHERE zc_platdo = '99991231'
  AND LENGTH(zc_nuts) = 5
  AND zc_nuts LIKE 'CZ0%'
ORDER BY zc_nuts;

-- ---------------------------------------------------------------------
-- 3) Praha nemá samostatné okresy
-- Zjištění: CZ010 (kraj) i CZ0100 (okres) mají stejný název, proto
--           v dim.obce vychází u Prahy kraj = okres = "Hlavní město
--           Praha". Není to chyba.
-- ---------------------------------------------------------------------
SELECT zc_nuts, zc_platdo, txtlg
FROM stg.ciselnik_nuts
WHERE zc_nuts IN ('CZ010', 'CZ0100');


-- =====================================================================
-- PARAGRAFY (stg.ciselnik_paragrafy)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4) Číselník obsahuje všechny úrovně hierarchie
-- Otázka:   Které kódy z číselníku se ve výkazu skutečně používají?
-- Zjištění: Číselník mísí úrovně různé délky (skupina, oddíl, pododdíl,
--           paragraf, plus delší varianty). Výkaz (finm201) používá
--           výhradně 4místné kódy (1 353 622 řádků), 1 řádek je NULL
--           (sentinel, viz finm201_exploration.sql).
-- Řešení:   dim.paragrafy: WHERE LENGTH(func_area) = 4.
-- ---------------------------------------------------------------------
SELECT LENGTH(func_area) AS delka, COUNT(*) AS pocet_v_ciselniku
FROM stg.ciselnik_paragrafy
GROUP BY 1
ORDER BY 1;

SELECT LENGTH(func_area) AS delka, COUNT(*) AS pocet_ve_vykazu
FROM stg.finm201
GROUP BY 1
ORDER BY 1;

-- ---------------------------------------------------------------------
-- 5) Časová platnost paragrafů a paragraf 0000
-- Zjištění: Některé paragrafy mají víc verzí v čase (1070: "Rybářství"
--           do 2021, "Rybářství a myslivost" od 2022). Proto je primární
--           klíč (paragraf, datefrom) a join na číselník musí jít přes
--           platnost k roku transakce.
--           Kód 0000 = "Pro příjmy (technický záznam)" – použit u
--           daňových příjmů, kde se paragraf nevyplňuje.
-- ---------------------------------------------------------------------
SELECT paragraf, nazev, datefrom, dateto
FROM dim.paragrafy
WHERE paragraf IN ('1070', '0000')
ORDER BY paragraf, datefrom;


-- =====================================================================
-- POLOŽKY (stg.ciselnik_polozky)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 6) Délky kódů
-- Zjištění: Stejně jako u paragrafů: výkaz používá 4místné kódy
--           (1 353 622 řádků + 1 NULL sentinel) → dim.polozky:
--           WHERE LENGTH(zcmmt_itm) = 4.
-- ---------------------------------------------------------------------
SELECT LENGTH(zcmmt_itm) AS delka, COUNT(*) AS pocet_v_ciselniku
FROM stg.ciselnik_polozky
GROUP BY 1
ORDER BY 1;

SELECT LENGTH(zcmmt_itm) AS delka, COUNT(*) AS pocet_ve_vykazu
FROM stg.finm201
GROUP BY 1
ORDER BY 1;

-- ---------------------------------------------------------------------
-- 7) Reforma rozpočtové skladby 2025
-- Zjištění: Položka 11 má dvě verze: platná do 20241231 a od 20250101
--           s jiným názvem. Join bez platnosti by řádky zdvojil.
-- ---------------------------------------------------------------------
SELECT zcmmt_itm, datefrom, dateto, txtxl
FROM stg.ciselnik_polozky
WHERE zcmmt_itm = '11'
ORDER BY datefrom;

-- ---------------------------------------------------------------------
-- 8) Paragraf vs. položka (jak spolu souvisí)
-- Paragraf = odvětví ("kam to jde": školství, doprava, odpady).
-- Položka  = druh peněz ("co to je": daň, dotace, platy, energie).
-- První číslice položky = třída: 1–4 příjmy, 5–6 výdaje.
-- Jeden řádek factu má obojí; k dimenzím se joinuje zvlášť, pokaždé
-- přes platnost k roku.
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 9) Rozložení tříd položek ve výkazu (ověření)
-- Očekávání: 1–4 pod ci_type 2, 5–6 pod ci_type 3, třída 8 nikde.
-- ---------------------------------------------------------------------
SELECT ci_type, LEFT(zcmmt_itm, 1) AS trida, COUNT(*) AS pocet_radku
FROM stg.finm201
GROUP BY 1, 2
ORDER BY 1, 2;