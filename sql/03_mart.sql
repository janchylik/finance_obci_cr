
-- Vytvoreni schématu mart a pohledu obec_rok, který obsahuje agregovaná data o příjmech a výdajích obcí podle roku a kategorie počtu obyvatel.

CREATE SCHEMA IF NOT EXISTS mart;

CREATE OR REPLACE VIEW mart.obec_rok AS
WITH data_bez_konsolidace AS(
SELECT *
FROM fact.rozpocet
WHERE NOT konsolidacni
)
SELECT
	o.zc_ico,
	o.obec,
	o.kraj,
	o.okres,
	r.rok,
	obyv.pocet_obyvatel,
	CASE
        WHEN obyv.pocet_obyvatel < 200   THEN '1: do 199'
        WHEN obyv.pocet_obyvatel < 500   THEN '2: 200-499'
        WHEN obyv.pocet_obyvatel < 1000  THEN '3: 500-999'
        WHEN obyv.pocet_obyvatel < 2000  THEN '4: 1 000-1 999'
        WHEN obyv.pocet_obyvatel < 5000  THEN '5: 2 000-4 999'
        WHEN obyv.pocet_obyvatel < 20000 THEN '6: 5 000-19 999'
        ELSE                               '7: 20 000 a více'
    END AS kategorie,
	COALESCE(SUM(r.skutecnost_rozpocet) FILTER (WHERE r.typ = 'prijem' AND LEFT(r.polozka, 1) = '1'), 0) AS prijmy_danove,
	COALESCE(SUM(r.skutecnost_rozpocet) FILTER (WHERE r.typ = 'prijem' AND LEFT(r.polozka, 1) = '2'), 0) AS prijmy_nedanove,
	COALESCE(SUM(r.skutecnost_rozpocet) FILTER (WHERE r.typ = 'prijem' AND LEFT(r.polozka, 1) = '3'), 0) AS prijmy_kapitalove,
	COALESCE(SUM(r.skutecnost_rozpocet) FILTER (WHERE r.typ = 'prijem' AND LEFT(r.polozka, 1) = '4'), 0) AS prijmy_transfery,
	COALESCE(SUM(r.skutecnost_rozpocet) FILTER (WHERE r.typ = 'vydaj' AND LEFT(r.polozka, 1) = '5'), 0) AS vydaje_bezne,
	COALESCE(SUM(r.skutecnost_rozpocet) FILTER (WHERE r.typ = 'vydaj' AND LEFT(r.polozka, 1) = '6'), 0) AS vydaje_kapitalove,
	COALESCE(SUM(r.schvaleny_rozpocet) FILTER(WHERE r.typ = 'prijem'), 0) AS prijmy_schvalene,
	COALESCE(SUM(r.schvaleny_rozpocet) FILTER(WHERE r.typ = 'vydaj'), 0) AS vydaje_schvalene,
	COALESCE(SUM(r.rozpocet_po_zmenach) FILTER(WHERE r.typ = 'prijem'), 0) AS prijmy_po_zmenach,
	COALESCE(SUM(r.rozpocet_po_zmenach) FILTER(WHERE r.typ = 'vydaj'), 0) AS vydaje_po_zmenach,
	COALESCE(SUM(r.skutecnost_rozpocet) FILTER(WHERE r.typ = 'prijem'), 0) AS prijmy_skutecnost,
	COALESCE(SUM(r.skutecnost_rozpocet) FILTER(WHERE r.typ = 'vydaj'), 0) AS vydaje_skutecnost
FROM data_bez_konsolidace r
JOIN dim.obce o
	ON r.zc_ico = o.zc_ico
JOIN dim.obyvatele obyv
	ON r.zc_ico = obyv.zc_ico AND r.rok = obyv.rok
GROUP BY 
	o.zc_ico,
	o.obec,
	o.kraj,
	o.okres,
	r.rok,
	obyv.pocet_obyvatel
;

-- ============================================
-- Vytvoření pohledu obec_rok_oddil, který obsahuje agregovaná data o výdajích obcí podle oddílů paragrafů a roku.
--- ============================================

CREATE OR REPLACE VIEW mart.obec_rok_oddil AS
WITH data_bez_konsolidace AS (
    SELECT *
    FROM fact.rozpocet
    WHERE NOT konsolidacni AND typ = 'vydaj'
)
SELECT
    o.zc_ico,
    o.obec,
    o.kraj,
    r.rok,
    obyv.pocet_obyvatel,
    CASE
        WHEN obyv.pocet_obyvatel < 200   THEN '1: do 199'
        WHEN obyv.pocet_obyvatel < 500   THEN '2: 200-499'
        WHEN obyv.pocet_obyvatel < 1000  THEN '3: 500-999'
        WHEN obyv.pocet_obyvatel < 2000  THEN '4: 1 000-1 999'
        WHEN obyv.pocet_obyvatel < 5000  THEN '5: 2 000-4 999'
        WHEN obyv.pocet_obyvatel < 20000 THEN '6: 5 000-19 999'
        ELSE                                  '7: 20 000 a více'
    END AS kategorie,
    LEFT(r.paragraf, 2)      AS oddil,
    od.nazev                 AS nazev_oddilu,
    SUM(r.skutecnost_rozpocet) AS vydaje_oddil
FROM data_bez_konsolidace r
JOIN dim.obce o       ON r.zc_ico = o.zc_ico
JOIN dim.obyvatele obyv ON r.zc_ico = obyv.zc_ico AND r.rok = obyv.rok
LEFT JOIN dim.oddily od
    ON LEFT(r.paragraf, 2) = od.oddil
   AND make_date(r.rok, 1, 1) BETWEEN od.datefrom AND od.dateto
GROUP BY o.zc_ico, o.obec, o.kraj, r.rok, obyv.pocet_obyvatel, LEFT(r.paragraf, 2), od.nazev;


WITH soucet_oddily AS (
    SELECT zc_ico, rok, SUM(vydaje_oddil) AS vydaje_z_oddilu
    FROM mart.obec_rok_oddil
    GROUP BY zc_ico, rok
)
SELECT m.zc_ico, m.obec,
       m.vydaje_bezne + m.vydaje_kapitalove AS vydaje_mart,
       s.vydaje_z_oddilu,
       (m.vydaje_bezne + m.vydaje_kapitalove) - s.vydaje_z_oddilu AS rozdil
FROM mart.obec_rok m
JOIN soucet_oddily s ON m.zc_ico = s.zc_ico AND m.rok = s.rok
WHERE m.rok = 2025
ORDER BY ABS((m.vydaje_bezne + m.vydaje_kapitalove) - s.vydaje_z_oddilu) DESC
LIMIT 10;



-- Vydaje obce po paragrafech a polozkach (nejhlubsi uroven FinM201), bez konsolidacnich polozek
-- Zrnitost: obec x rok x paragraf x polozka
DROP VIEW IF EXISTS mart.obec_rok_paragraf;

CREATE VIEW mart.obec_rok_paragraf AS
SELECT
    r.zc_ico,
    r.rok,
    LEFT(r.paragraf, 2) AS oddil,
    od.nazev            AS nazev_oddilu,
    r.paragraf,
    par.nazev           AS nazev_paragrafu,
    CASE LEFT(r.polozka, 1)
        WHEN '5' THEN 'Běžné výdaje'
        WHEN '6' THEN 'Kapitálové výdaje'
    END                 AS druh_vydaje,
    LEFT(r.polozka, 2)  AS seskupeni,
    ses.nazev           AS nazev_seskupeni,
    LEFT(r.polozka, 3)  AS podseskupeni,
    pod.nazev           AS nazev_podseskupeni,
    r.polozka,
    pol.nazev           AS nazev_polozky,
    SUM(r.skutecnost_rozpocet) AS vydaje_paragraf
FROM fact.rozpocet r
LEFT JOIN dim.oddily od
       ON LEFT(r.paragraf, 2) = od.oddil
      AND make_date(r.rok,1,1) BETWEEN od.datefrom AND od.dateto
LEFT JOIN dim.paragrafy par
       ON r.paragraf = par.paragraf
      AND make_date(r.rok,1,1) BETWEEN par.datefrom AND par.dateto
LEFT JOIN dim.polozky_skupiny ses
       ON LEFT(r.polozka, 2) = ses.kod
      AND make_date(r.rok,1,1) BETWEEN ses.datefrom AND ses.dateto
LEFT JOIN dim.polozky_skupiny pod
       ON LEFT(r.polozka, 3) = pod.kod
      AND make_date(r.rok,1,1) BETWEEN pod.datefrom AND pod.dateto
LEFT JOIN dim.polozky pol
       ON r.polozka = pol.polozka
      AND make_date(r.rok,1,1) BETWEEN pol.datefrom AND pol.dateto
WHERE NOT r.konsolidacni
  AND r.typ = 'vydaj'
GROUP BY r.zc_ico, r.rok, LEFT(r.paragraf, 2), od.nazev, r.paragraf, par.nazev,
         LEFT(r.polozka, 1), LEFT(r.polozka, 2), ses.nazev,
         LEFT(r.polozka, 3), pod.nazev,
         r.polozka, pol.nazev;

-- Příjmy obce po položkách (s třídou), bez konsolidačních položek
CREATE OR REPLACE VIEW mart.obec_rok_polozka AS
SELECT
    r.zc_ico,
    r.rok,
    LEFT(r.polozka, 1) AS trida,
    CASE LEFT(r.polozka, 1)
        WHEN '1' THEN 'Daňové příjmy'
        WHEN '2' THEN 'Nedaňové příjmy'
        WHEN '3' THEN 'Kapitálové příjmy'
        WHEN '4' THEN 'Přijaté transfery'
    END                AS nazev_tridy,
    r.polozka,
    pol.nazev          AS nazev_polozky,
    SUM(r.skutecnost_rozpocet) AS prijmy_polozka
FROM fact.rozpocet r
LEFT JOIN dim.polozky pol
    ON r.polozka = pol.polozka
   AND make_date(r.rok, 1, 1) BETWEEN pol.datefrom AND pol.dateto
WHERE NOT r.konsolidacni AND r.typ = 'prijem'
GROUP BY r.zc_ico, r.rok, LEFT(r.polozka, 1), r.polozka, pol.nazev;


