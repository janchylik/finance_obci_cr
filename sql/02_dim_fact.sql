-- Vytvoreni dim_obyvatele s pocty obyvatel danych obci v jendotlivych letech
-- Vychazi z explorace v ciselnik_obce_exploration.sql, kde byly ziskany pocty obyvatel pro kazdou obec v jednotlivych letech a overeno, podle ceho filtrovat jednotlive obce
DROP TABLE IF EXISTS dim.obyvatele;

CREATE TABLE IF NOT EXISTS dim.obyvatele (
    zc_ico TEXT NOT NULL,
    rok INT NOT NULL,
    pocet_obyvatel INT NOT NULL,
    PRIMARY KEY (zc_ico, rok)
);

INSERT INTO dim.obyvatele (zc_ico, rok, pocet_obyvatel)
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
SELECT 
    zc_ico,
    rok,
    CAST(zc_pocob AS INT) AS pocet_obyvatel
FROM obce_rok;


-- Vytvoreni dim_nuts s jednotkami NUTS

DROP TABLE IF EXISTS dim.nuts;

CREATE TABLE IF NOT EXISTS dim.nuts (
    zc_nuts TEXT NOT NULL,
    uzemni_jednotka TEXT NOT NULL,
    PRIMARY KEY (zc_nuts)
);


INSERT INTO dim.nuts (zc_nuts, uzemni_jednotka)
SELECT zc_nuts, txtlg as uzemni_jednotka
FROM stg.ciselnik_nuts
WHERE zc_platdo = '99991231';


-- Vytvoreni dim_obce s obcemi a jejich prislusnosti k okresum a krajum

DROP TABLE IF EXISTS dim.obce;

CREATE TABLE IF NOT EXISTS dim.obce (
    zc_ico TEXT PRIMARY KEY,
    obec TEXT NOT NULL,
    kraj TEXT,
    okres TEXT
);


INSERT INTO dim.obce (zc_ico, obec, kraj, okres)
SELECT 
    o.zc_ico,
    o.txtxl AS obec,
    kraj.txtlg AS kraj,
    okres.txtlg AS okres
FROM stg.ciselnik_obce o
LEFT JOIN stg.ciselnik_nuts kraj
    ON LEFT(o.zc_nuts, 5) = kraj.zc_nuts AND kraj.zc_platdo = '99991231'
LEFT JOIN stg.ciselnik_nuts okres 
    ON o.zc_nuts = okres.zc_nuts AND okres.zc_platdo = '99991231'
WHERE 
    zc_forma = '801' AND 
    zc_duif = '04' AND 
    o.dateto = '99991231';



-- Vytvoreni dim_paragrafy s paragrafy a jejich nazvy

DROP TABLE IF EXISTS dim.paragrafy;

CREATE TABLE IF NOT EXISTS dim.paragrafy (
    paragraf TEXT NOT NULL,
    nazev TEXT NOT NULL,
    datefrom DATE NOT NULL,
    dateto DATE,
    PRIMARY KEY (paragraf, datefrom) 
);


INSERT INTO dim.paragrafy (paragraf, nazev, datefrom, dateto)
SELECT
    func_area,
    txtxl,
    TO_DATE(datefrom, 'YYYYMMDD') AS datefrom,
    TO_DATE(dateto, 'YYYYMMDD') AS dateto
FROM stg.ciselnik_paragrafy
WHERE LENGTH(func_area) = 4;


-- Vytvoreni dim_polozky s polozkami a jejich nazvy

DROP TABLE IF EXISTS dim.polozky;

CREATE TABLE IF NOT EXISTS dim.polozky (
    polozka TEXT NOT NULL,
    nazev TEXT NOT NULL,
    datefrom DATE NOT NULL,
    dateto DATE,
    PRIMARY KEY (polozka, datefrom)
);


INSERT INTO dim.polozky (polozka, nazev, datefrom, dateto)
SELECT
    zcmmt_itm,
    txtxl,
    TO_DATE(datefrom, 'YYYYMMDD') AS datefrom,
    TO_DATE(dateto, 'YYYYMMDD') AS dateto
FROM stg.ciselnik_polozky
WHERE LENGTH(zcmmt_itm) = 4;

-- Vytvoreni dim_konsolidacni_polozky s polozkami, ktere se pouzivaji pro konsolidaci prevodu mezi obcemi
DROP TABLE IF EXISTS dim.konsolidacni_polozky;
CREATE TABLE dim.konsolidacni_polozky (
    polozka TEXT PRIMARY KEY,
    typ     TEXT NOT NULL CHECK (typ IN ('prijem', 'vydaj')),
    zdroj   TEXT NOT NULL
);

INSERT INTO dim.konsolidacni_polozky (polozka, typ, zdroj) VALUES
    ('4133','prijem','vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('4134','prijem','vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('4137','prijem','vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('4138','prijem','vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('4139','prijem','vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('4251','prijem','vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('5342','vydaj', 'vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('5344','vydaj', 'vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('5345','vydaj', 'vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('5347','vydaj', 'vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('5348','vydaj', 'vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('5349','vydaj', 'vyhl. 344/2019 Sb., př. 6, bod 8.3'),
    ('6363','vydaj', 'vyhl. 344/2019 Sb., př. 6, bod 8.3');


-- Vytvoreni fact_rozpocet s rozpocty obci
DROP TABLE IF EXISTS fact.rozpocet;

CREATE TABLE IF NOT EXISTS fact.rozpocet (
    zc_ico TEXT NOT NULL,
    rok INTEGER NOT NULL,
    typ TEXT NOT NULL,
    paragraf TEXT NOT NULL,
    polozka TEXT NOT NULL,
    schvaleny_rozpocet NUMERIC(18,2),
    rozpocet_po_zmenach NUMERIC(18,2),
    skutecnost_rozpocet NUMERIC(18,2),
    zkopirovano BOOLEAN NOT NULL,
    konsolidacni BOOLEAN NOT NULL,
    PRIMARY KEY (zc_ico, rok, typ, paragraf, polozka)
);


INSERT INTO fact.rozpocet (zc_ico, rok, typ, paragraf, polozka, schvaleny_rozpocet, rozpocet_po_zmenach, skutecnost_rozpocet, zkopirovano, konsolidacni)
SELECT
    f.zc_ico, 
    LEFT(f.fiscper, 4)::INTEGER AS rok,
    CASE
        WHEN f.ci_type = '2' THEN 'prijem'
        WHEN f.ci_type = '3' THEN 'vydaj'
    END AS typ,
    f.func_area AS paragraf,
    f.zcmmt_itm AS polozka,
    CASE 
        WHEN TRIM(f.zu_rozsch) LIKE '%-' 
            THEN -1 * REPLACE(TRIM(f.zu_rozsch), '-', '')::NUMERIC(18,2)
        ELSE TRIM(f.zu_rozsch)::NUMERIC(18,2)
    END AS schvaleny_rozpocet,
    CASE
        WHEN TRIM(f.zu_rozpzm) LIKE '%-'
            THEN -1 * REPLACE(TRIM(f.zu_rozpzm), '-', '')::NUMERIC(18,2) 
        ELSE TRIM(f.zu_rozpzm)::NUMERIC(18,2)
    END AS rozpocet_po_zmenach,
    CASE
        WHEN TRIM(f.zu_rozkz) LIKE '%-' 
            THEN -1 * REPLACE(TRIM(f.zu_rozkz), '-', '')::NUMERIC(18,2)
        ELSE TRIM(f.zu_rozkz)::NUMERIC(18,2)
    END AS skutecnost_rozpocet,
    CASE
        WHEN f.zc_fcopy = 'X' THEN TRUE
        ELSE FALSE
    END AS zkopirovano,
    k.polozka IS NOT NULL AS konsolidacni
FROM stg.finm201 f
JOIN dim.obce o 
    ON f.zc_ico = o.zc_ico
LEFT JOIN dim.konsolidacni_polozky k 
    ON f.zcmmt_itm = k.polozka;


-- =============================================
-- DIM Oddily
-- =============================================

DROP TABLE IF EXISTS dim.oddily;

CREATE TABLE IF NOT EXISTS dim.oddily (
    oddil TEXT NOT NULL,
    nazev TEXT NOT NULL,
    datefrom DATE NOT NULL,
    dateto DATE,
    PRIMARY KEY (oddil, datefrom)
);

INSERT INTO dim.oddily (oddil, nazev, datefrom, dateto)
SELECT
    func_area,
    txtxl,
    TO_DATE(datefrom, 'YYYYMMDD') AS datefrom,
    TO_DATE(dateto, 'YYYYMMDD') AS dateto
FROM stg.ciselnik_paragrafy
WHERE LENGTH(func_area) = 2;

SELECT oddil, COUNT(*) FROM dim.oddily GROUP BY oddil HAVING COUNT(*) > 1 ORDER BY oddil;

SELECT * FROM dim.oddily

SELECT * FROM dim.oddily WHERE oddil IN ('34', '39') ORDER BY oddil, datefrom;