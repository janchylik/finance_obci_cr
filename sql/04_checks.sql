SELECT DISTINCT
    fact.rozpocet.zc_ico,
    o.obec
FROM fact.rozpocet
JOIN dim.obce o ON fact.rozpocet.zc_ico = o.zc_ico
WHERE o.obec LIKE '%Smrk%'

SELECT typ, LEFT(polozka, 1) AS trida,
       SUM(schvaleny_rozpocet)  AS schvaleny,
       SUM(rozpocet_po_zmenach) AS po_zmenach,
       SUM(skutecnost_rozpocet) AS skutecnost
FROM fact.rozpocet
WHERE zc_ico = '00378623' AND rok = 2025
GROUP BY 1, 2
ORDER BY 1, 2;


SELECT f.typ, f.polozka, p.nazev, SUM(f.skutecnost_rozpocet) AS skutecnost
FROM fact.rozpocet f
JOIN dim.polozky p ON f.polozka = p.polozka
                  AND make_date(f.rok, 1, 1) BETWEEN p.datefrom AND p.dateto
WHERE f.zc_ico = '00378623' AND f.rok = 2025
  AND p.nazev ILIKE '%převod%'
GROUP BY 1, 2, 3
ORDER BY 1, 4 DESC;

SELECT f.paragraf, pa.nazev, SUM(f.skutecnost_rozpocet) AS skutecnost
FROM fact.rozpocet f
JOIN dim.paragrafy pa ON f.paragraf = pa.paragraf
                     AND make_date(f.rok, 1, 1) BETWEEN pa.datefrom AND pa.dateto
WHERE f.zc_ico = '00378623' AND f.rok = 2025 AND f.typ = 'vydaj'
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 10;

WITH prevody AS (
    SELECT zc_ico, rok,
           SUM(CASE WHEN typ = 'prijem' AND LEFT(polozka, 3) = '413'
                    THEN skutecnost_rozpocet ELSE 0 END) AS prijmy,
           SUM(CASE WHEN typ = 'vydaj'  AND LEFT(polozka, 3) = '534'
                    THEN skutecnost_rozpocet ELSE 0 END) AS vydaje
    FROM fact.rozpocet
    GROUP BY zc_ico, rok
)
SELECT COUNT(*)                                        AS obci_celkem,
       COUNT(*) FILTER (WHERE prijmy = 0 AND vydaje = 0) AS bez_prevodu,
       COUNT(*) FILTER (WHERE prijmy <> vydaje)         AS nesedi
FROM prevody;


WITH prevody AS (
    SELECT zc_ico,
           SUM(CASE WHEN typ = 'prijem' AND LEFT(polozka, 3) = '413' THEN skutecnost_rozpocet ELSE 0 END) AS prijmy,
           SUM(CASE WHEN typ = 'vydaj'  AND LEFT(polozka, 3) = '534' THEN skutecnost_rozpocet ELSE 0 END) AS vydaje
    FROM fact.rozpocet
    WHERE rok = 2025
    GROUP BY zc_ico
)
SELECT CASE WHEN prijmy > vydaje THEN 'víc příjmových převodů'
            ELSE 'víc výdajových převodů' END AS smer,
       COUNT(*) AS pocet_obci,
       MIN(ABS(prijmy - vydaje)) AS min_rozdil,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY ABS(prijmy - vydaje)) AS median_rozdil,
       MAX(ABS(prijmy - vydaje)) AS max_rozdil
FROM prevody
WHERE prijmy <> vydaje
GROUP BY 1;


WITH prevody AS (
    SELECT zc_ico,
           SUM(CASE WHEN typ = 'prijem' AND LEFT(polozka, 3) = '413' THEN skutecnost_rozpocet ELSE 0 END) AS prijmy,
           SUM(CASE WHEN typ = 'vydaj'  AND LEFT(polozka, 3) = '534' THEN skutecnost_rozpocet ELSE 0 END) AS vydaje
    FROM fact.rozpocet
    WHERE rok = 2025
    GROUP BY zc_ico
),
nesedi AS (SELECT zc_ico FROM prevody WHERE prijmy <> vydaje)
SELECT f.polozka, p.nazev,
       COUNT(DISTINCT f.zc_ico) FILTER (WHERE n.zc_ico IS NOT NULL) AS obci_nesedicich,
       COUNT(DISTINCT f.zc_ico) FILTER (WHERE n.zc_ico IS NULL)     AS obci_sedicich,
       SUM(f.skutecnost_rozpocet) FILTER (WHERE n.zc_ico IS NOT NULL) AS soucet_nesedicich
FROM fact.rozpocet f
LEFT JOIN nesedi n ON n.zc_ico = f.zc_ico
JOIN dim.polozky p ON f.polozka = p.polozka
                  AND make_date(f.rok, 1, 1) BETWEEN p.datefrom AND p.dateto
WHERE f.rok = 2025
  AND LEFT(f.polozka, 3) IN ('413', '534')
  AND f.skutecnost_rozpocet <> 0
GROUP BY 1, 2
ORDER BY obci_nesedicich DESC;


WITH prevody AS (
    SELECT zc_ico,
           SUM(CASE WHEN typ = 'prijem' AND polozka IN ('4134', '4138')
                    THEN skutecnost_rozpocet ELSE 0 END) AS prijmy,
           SUM(CASE WHEN typ = 'vydaj'  AND polozka IN ('5345', '5348')
                    THEN skutecnost_rozpocet ELSE 0 END) AS vydaje
    FROM fact.rozpocet
    WHERE rok = 2025
    GROUP BY zc_ico
)
SELECT COUNT(*)                                                       AS obci_celkem,
       COUNT(*) FILTER (WHERE prijmy = 0 AND vydaje = 0)              AS bez_prevodu,
       COUNT(*) FILTER (WHERE ABS(prijmy - vydaje) >= 1)              AS nesedi,
       COUNT(*) FILTER (WHERE prijmy <> vydaje AND ABS(prijmy - vydaje) < 1) AS jen_halere
FROM prevody;

WITH prevody AS (
    SELECT zc_ico,
           SUM(CASE WHEN typ = 'prijem'
                     AND polozka IN ('4133','4134','4137','4138','4139','4251')
                    THEN skutecnost_rozpocet ELSE 0 END) AS prijmy,
           SUM(CASE WHEN typ = 'vydaj'
                     AND polozka IN ('5342','5344','5345','5347','5348','5349','6363')
                    THEN skutecnost_rozpocet ELSE 0 END) AS vydaje
    FROM fact.rozpocet
    WHERE rok = 2025
    GROUP BY zc_ico
)
SELECT COUNT(*)                                          AS obci_celkem,
       COUNT(*) FILTER (WHERE prijmy = 0 AND vydaje = 0) AS bez_prevodu,
       COUNT(*) FILTER (WHERE ABS(prijmy - vydaje) >= 1) AS nesedi
FROM prevody;



-- Kontrola, zda součet výdajů podle oddílů paragrafů odpovídá celkovým výdajům obcí podle roku a kategorie počtu obyvatel.
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