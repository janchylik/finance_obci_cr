--Vytazeni pouze obci, ktere jsou v ciselniku obci oznaceny jako obec zc_forma = '801'
SELECT *
FROM stg.ciselnik_obce
WHERE zc_forma = '801' 
LIMIT 150;


-- Zjisteni profilu konkretni obce podle IČO
SELECT zc_ico, datefrom, dateto, zc_pocob, txtxl
FROM stg.ciselnik_obce
WHERE zc_forma = '801' AND zc_ico = '00473413' -- libovolné konkrétní IČO
ORDER BY datefrom;


--Vytazeni pouze nejnovejsich zaznamu obci, ktere jsou v ciselniku obci oznaceny jako obec zc_forma = '801'
SELECT zc_ico, datefrom, dateto, zc_pocob, txtxl
FROM stg.ciselnik_obce
WHERE zc_forma = '801' AND txtxl NOT LIKE '%Městsk%' AND dateto = '99991231' -- Ponechá pouze aktuálně platné záznamy
ORDER BY txtxl;


-- Prirazeni roku k zaznamum obci
WITH roky AS (
    SELECT generate_series(2020, 2026) AS rok
)
SELECT 
    o.zc_ico,
    r.rok,
    o.zc_pocob,
    o.datefrom,
    o.dateto
FROM roky r
JOIN stg.ciselnik_obce o
    ON o.zc_forma = '801'
    AND o.txtxl NOT LIKE '%Městsk%'
    AND make_date(r.rok, 1, 1) BETWEEN TO_DATE(o.datefrom, 'YYYYMMDD') AND TO_DATE(o.dateto, 'YYYYMMDD')
ORDER BY o.zc_ico, r.rok;


-- Zjisteni, zda nejake ico ma duplicitni zaznamy v jednotlivych rocich
WITH roky AS (
    SELECT generate_series(2020, 2026) AS rok
),
obce_rok AS (
    SELECT 
        o.zc_ico,
        r.rok,
        o.zc_pocob
    FROM roky r
    JOIN stg.ciselnik_obce o
        ON o.zc_forma = '801'
        AND o.zc_duif = '04'
        AND make_date(r.rok, 1, 1) BETWEEN TO_DATE(o.datefrom, 'YYYYMMDD') AND TO_DATE(o.dateto, 'YYYYMMDD')
)
SELECT *
FROM obce_rok
GROUP BY zc_ico, rok
HAVING COUNT(*) > 1;

-- Zjisteni dulicitnich zaznamu pro konkretni ico
SELECT DISTINCT zc_ico, txtxl
FROM stg.ciselnik_obce
WHERE zc_ico = '00064581'


-- Overeni, kolik takovych pripadu s magistratem je v tabulce
SELECT DISTINCT zc_ico, txtxl 
FROM stg.ciselnik_obce 
WHERE zc_forma = '801' AND txtxl LIKE '%magistrát%';


-- Zjisteni, co se lisi mezi hlavnim mestem prahou a magistratem
SELECT DISTINCT txtxl, zc_duif, zc_uradf, zc_isekt
FROM stg.ciselnik_obce
WHERE zc_ico = '00064581'
ORDER BY txtxl;


-- Overeni, zda muzeme filtrovat nase obce podle zc_duif
SELECT zc_duif, COUNT(DISTINCT zc_ico) AS pocet_ico
FROM stg.ciselnik_obce
WHERE zc_forma = '801'
GROUP BY zc_duif
ORDER BY pocet_ico DESC;

SELECT *
FROM stg.ciselnik_obce
WHERE zc_forma = '801' AND zc_duif = '04'
ORDER BY txtxl;