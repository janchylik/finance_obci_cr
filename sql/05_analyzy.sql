-- ============================================
-- BLOK A: Výdaje na obyvatele
-- ============================================

-- A.1 Podle velikostní kategorie
WITH obec_vydaje AS (
    SELECT
        zc_ico,
        obec,
        kraj,
        kategorie,
        pocet_obyvatel,
        vydaje_bezne + vydaje_kapitalove                         AS vydaje_celkem,
        (vydaje_bezne + vydaje_kapitalove) / NULLIF(pocet_obyvatel, 0) AS vydaje_na_obyvatele,
        vydaje_bezne / NULLIF(pocet_obyvatel, 0)                 AS bezne_na_obyvatele
    FROM mart.obec_rok
    WHERE rok = 2025
)
SELECT
    kategorie,
    COUNT(*)                                                         AS pocet_obci,
    SUM(vydaje_celkem) / NULLIF(SUM(pocet_obyvatel), 0)              AS vazeny_prumer_celkem,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY vydaje_na_obyvatele) AS median_celkem,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY bezne_na_obyvatele)  AS median_bezne
FROM obec_vydaje
GROUP BY kategorie
ORDER BY kategorie;

-- A.2 Podle kraje
WITH obec_vydaje AS (
    SELECT
        zc_ico,
        obec,
        kraj,
        pocet_obyvatel,
        vydaje_bezne + vydaje_kapitalove AS vydaje_celkem
    FROM mart.obec_rok
    WHERE rok = 2025
)
SELECT
    kraj,
    COUNT(*) AS pocet_obci,
    SUM(vydaje_celkem) / SUM(pocet_obyvatel) AS vazeny_prumer,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY vydaje_celkem / NULLIF(pocet_obyvatel,0)) AS median,
    RANK() OVER (ORDER BY SUM(vydaje_celkem) / SUM(pocet_obyvatel) DESC) AS poradi
FROM obec_vydaje
GROUP BY kraj
ORDER BY poradi;

-- ============================================
-- BLOK B: Odkud obce berou peníze
-- ============================================

WITH obec_prijmy AS (
    SELECT
        zc_ico,
        kategorie,
        pocet_obyvatel,
        prijmy_danove,
        prijmy_nedanove,
        prijmy_kapitalove,
        prijmy_transfery,
        prijmy_danove + prijmy_nedanove + prijmy_kapitalove + prijmy_transfery AS prijmy_celkem
    FROM mart.obec_rok
    WHERE rok = 2025
)
SELECT
    kategorie,
    -- podíl každé třídy na celkových příjmech kategorie (vážený)
    SUM(prijmy_danove) / SUM(prijmy_celkem) AS podil_danove,
    SUM(prijmy_nedanove) / SUM(prijmy_celkem) AS podil_nedanove,
    SUM(prijmy_kapitalove) / SUM(prijmy_celkem) AS podil_kapitalove,
    SUM(prijmy_transfery) / SUM(prijmy_celkem) AS podil_transfery,
    -- daňové příjmy na obyvatele -- vážený průměr i medián
    SUM(prijmy_danove) / SUM(pocet_obyvatel) AS vazeny_prumer_danove_na_obyvatele,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY prijmy_danove / NULLIF(pocet_obyvatel, 0)) AS median_danove_na_obyvatele
FROM obec_prijmy
GROUP BY kategorie
ORDER BY kategorie;

-- Rozdíl mezi Prahou a ostatními obcemi s více než 20 000 obyvateli
WITH obec_vydaje AS (
    SELECT zc_ico, pocet_obyvatel,
           prijmy_danove
    FROM mart.obec_rok
    WHERE rok = 2025 AND kategorie = '7: 20 000 a více'
)
SELECT
    SUM(prijmy_danove) / SUM(pocet_obyvatel) AS s_prahou,
    SUM(prijmy_danove) FILTER (WHERE zc_ico <> '00064581')
        / SUM(pocet_obyvatel) FILTER (WHERE zc_ico <> '00064581') AS bez_prahy
FROM obec_vydaje;

/*
Podíl jednotlivých tříd příjmů (daně ~64–70 %, nedaňové ~9–14 %, kapitálové ~1–4 %, transfery ~16–20 %) 
je napříč velikostními kategoriemi obcí poměrně stabilní – malé a velké obce nemají výrazně odlišnou strukturu příjmů. 
Výrazně odlišná je ale výše daňových příjmů na obyvatele: nejmenší obce mají mírně nadprůměrné daňové příjmy na hlavu (27 037 Kč), 
střední kategorie nejnižší (~25 400 Kč), a největší obce (20 000+) výrazně nejvyšší (43 645 Kč, resp. 31 015 Kč po vyřazení Prahy). 
To potvrzuje hypotézu, že rozpočtové určení daní (RUD) přerozděluje víc peněz na hlavu směrem k větším obcím – efekt není jen Praha, 
ale platí obecně pro velká města, jen Praha ho ukazuje v extrémní podobě.
*/


-- ============================================
-- BLOK C: Na co obce utrácejí peníze (podle paragrafů)
-- ============================================

-- A) Vydaje podle oddílů paragrafů a velikostní kategorie obce
SELECT *
FROM (
WITH soucet_kategorie AS (
    SELECT kategorie, oddil, nazev_oddilu,
           SUM(vydaje_oddil) AS vydaje_celkem_oddil
    FROM mart.obec_rok_oddil
    WHERE rok = 2025
    GROUP BY kategorie, oddil, nazev_oddilu
)
SELECT
    kategorie,
    nazev_oddilu,
    vydaje_celkem_oddil,
    vydaje_celkem_oddil / SUM(vydaje_celkem_oddil) OVER (PARTITION BY kategorie) AS podil_na_kategorii,
    RANK() OVER (PARTITION BY kategorie ORDER BY vydaje_celkem_oddil DESC) AS poradi_v_kategorii
FROM soucet_kategorie
ORDER BY kategorie, poradi_v_kategorii
) t
WHERE poradi_v_kategorii <= 5
ORDER BY kategorie, poradi_v_kategorii;




-- B) Detailní rozklad top oddílů na paragrafy
WITH data_bez_konsolidace AS (
    SELECT * FROM fact.rozpocet
    WHERE NOT konsolidacni AND typ = 'vydaj'
),
detail AS (
    SELECT
        CASE
            WHEN obyv.pocet_obyvatel < 200   THEN '1: do 199'
            WHEN obyv.pocet_obyvatel < 500   THEN '2: 200-499'
            WHEN obyv.pocet_obyvatel < 1000  THEN '3: 500-999'
            WHEN obyv.pocet_obyvatel < 2000  THEN '4: 1 000-1 999'
            WHEN obyv.pocet_obyvatel < 5000  THEN '5: 2 000-4 999'
            WHEN obyv.pocet_obyvatel < 20000 THEN '6: 5 000-19 999'
            ELSE                                  '7: 20 000 a více'
        END AS kategorie,
        LEFT(r.paragraf, 2) AS oddil,
        od.nazev            AS nazev_oddilu,
        r.paragraf,
        par.nazev            AS nazev_paragrafu,
        r.skutecnost_rozpocet
    FROM data_bez_konsolidace r
    JOIN dim.obce o         ON r.zc_ico = o.zc_ico
    JOIN dim.obyvatele obyv ON r.zc_ico = obyv.zc_ico AND r.rok = obyv.rok
    LEFT JOIN dim.oddily od
        ON LEFT(r.paragraf, 2) = od.oddil
       AND make_date(r.rok,1,1) BETWEEN od.datefrom AND od.dateto
    LEFT JOIN dim.paragrafy par
        ON r.paragraf = par.paragraf
       AND make_date(r.rok,1,1) BETWEEN par.datefrom AND par.dateto
    WHERE r.rok = 2025
),
paragraf_soucet AS (
    SELECT kategorie, oddil, nazev_oddilu, paragraf, nazev_paragrafu,
           SUM(skutecnost_rozpocet) AS vydaje_paragraf
    FROM detail
    GROUP BY kategorie, oddil, nazev_oddilu, paragraf, nazev_paragrafu
),
s_oddilovym_souctem AS (
    SELECT *,
           SUM(vydaje_paragraf) OVER (PARTITION BY kategorie, oddil) AS vydaje_oddil
    FROM paragraf_soucet
),
s_poradim AS (
    SELECT *,
           RANK() OVER (PARTITION BY kategorie ORDER BY vydaje_oddil DESC)        AS poradi_oddilu,
           RANK() OVER (PARTITION BY kategorie, oddil ORDER BY vydaje_paragraf DESC) AS poradi_paragrafu
    FROM s_oddilovym_souctem
)
SELECT
    kategorie, poradi_oddilu, nazev_oddilu, vydaje_oddil,
    poradi_paragrafu, nazev_paragrafu, vydaje_paragraf,
    ROUND(100.0 * vydaje_paragraf / vydaje_oddil, 1) AS podil_v_oddilu_procent
FROM s_poradim
WHERE poradi_oddilu <= 3 AND poradi_paragrafu <= 5
ORDER BY kategorie, poradi_oddilu, poradi_paragrafu;

/*
Dominance oddílu “Státní moc, státní správa” u malých obcí (blok C) má jasnou příčinu: 
skládá se téměř výhradně ze dvou položek – provoz úřadu (“Činnost místní správy”, ~60–67 %) 
a odměny zastupitelstvu (~32–38 %). Podíl výdajů na zastupitelstvo je u nejmenších obcí 
o něco vyšší než u středních, protože každá obec musí mít zastupitelstvo bez ohledu na velikost 
– tento náklad se tedy s rostoucí obcí “ředí” pomaleji než jiné položky. 
Naopak oddíl “Bydlení, komunální služby” (dominantní u středních obcí) je rozprostřený 
do čtyř srovnatelně velkých kategorií (komunální služby, bytové a nebytové hospodářství, 
veřejné osvětlení) bez jedné jasně převažující položky.
*/


-- ============================================
-- BLOK D: Planovani
-- ============================================

WITH obec_plneni AS (
    SELECT
        zc_ico, kategorie,
        vydaje_skutecnost / NULLIF(vydaje_po_zmenach, 0) AS mira_plneni_vydaje,
        prijmy_skutecnost / NULLIF(prijmy_po_zmenach, 0) AS mira_plneni_prijmy,
        vydaje_po_zmenach / NULLIF(vydaje_schvalene, 0)  AS mira_upravy_vydaje,
        prijmy_po_zmenach / NULLIF(prijmy_schvalene, 0)  AS mira_upravy_prijmy
    FROM mart.obec_rok
    WHERE rok = 2025
)
SELECT
    kategorie,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY mira_plneni_vydaje) AS median_plneni_vydaje,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY mira_plneni_prijmy) AS median_plneni_prijmy,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY mira_upravy_vydaje) AS median_upravy_vydaje,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY mira_upravy_prijmy) AS median_upravy_prijmy
FROM obec_plneni
GROUP BY kategorie
ORDER BY kategorie;


/*
Příjmy se plní téměř přesně podle upraveného rozpočtu (medián 0,99–1,02 napříč velikostmi)
 – daně a dotace se dají odhadnout spolehlivě. Výdaje se naopak systematicky plní jen z 78–84 %,
 bez ohledu na velikost obce – typické je, že se část plánovaných výdajů (hlavně investic) 
 do konce roku nestihne a přesune se do dalšího roku; není to nutně známka špatného plánování. 
 Menší obce zároveň v průběhu roku upravují svůj rozpočet výrazněji než velké 
 (medián úpravy 1,20 u nejmenší kategorie vs. 1,10 u středních a velkých) – malý absolutní rozpočet 
 je citlivější na jednorázové nečekané příjmy či výdaje.
*/