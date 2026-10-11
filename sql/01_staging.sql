
-- Vytvoreni raw tabulky finm201 a nahrani dat z CSV souboru
CREATE TABLE IF NOT EXISTS stg.finm201(
    ZC_VYKAZ TEXT,
    ZC_VTAB TEXT,
    FISCPER TEXT,
    ZC_UCJED TEXT,
    ZC_ICO TEXT,
    ZC_KRAJ TEXT,
    ZC_NUTS TEXT,
    CI_TYPE TEXT,
    FUNC_AREA TEXT,
    ZCMMT_ITM TEXT,
    ZU_ROZSCH TEXT,
    ZU_ROZPZM TEXT,
    ZU_ROZKZ TEXT,
    ZC_FCOPY TEXT
)
;

TRUNCATE TABLE stg.finm201;

COPY stg.finm201 (
    ZC_VYKAZ,
    ZC_VTAB,
    FISCPER,
    ZC_UCJED,
    ZC_ICO,
    ZC_KRAJ,
    ZC_NUTS,
    CI_TYPE,
    FUNC_AREA,
    ZCMMT_ITM,
    ZU_ROZSCH,
    ZU_ROZPZM,
    ZU_ROZKZ,
    ZC_FCOPY
)
FROM '/Users/hchyl/Library/Mobile Documents/com~apple~CloudDocs/02_Práce/Datova_analytika/03_Portfolio/finance_obci_cr/data/raw/FINM201_2025.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8')
;

-- Vytvoreni raw tabulky ciselnik_polozky a nahrani dat z CSV souboru
CREATE TABLE IF NOT EXISTS stg.ciselnik_polozky(
    ZCMMT_ITM TEXT,
    DATEFROM TEXT,
    DATETO TEXT,
    ZC_TRIDA TEXT,
    ZC_SES TEXT,
    ZC_PODSES TEXT,
    TXTXL TEXT
)
;

TRUNCATE TABLE stg.ciselnik_polozky;

COPY stg.ciselnik_polozky (
    ZCMMT_ITM,
    DATEFROM,
    DATETO,
    ZC_TRIDA,
    ZC_SES,
    ZC_PODSES,
    TXTXL
)
FROM '/Users/hchyl/Library/Mobile Documents/com~apple~CloudDocs/02_Práce/Datova_analytika/03_Portfolio/finance_obci_cr/data/raw/ciselnik_polozky.CSV' 
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8')
;


-- Vytvoreni raw tabulky ciselnik_obce a nahrani dat z CSV souboru
CREATE TABLE IF NOT EXISTS stg.ciselnik_obce(
    ZC_UCJED TEXT,
    DATETO TEXT,
    DATEFROM TEXT,
    ZC_ICO TEXT,
    ZC_DIC TEXT,
    STREET60 TEXT,
    HOUSE_NUM1 TEXT,
    CITY_1 TEXT,
    POSTALCODE TEXT,
    ZC_UJZRI TEXT,
    ZC_NACE TEXT,
    ZC_NUTS TEXT,
    ZC_COFOG TEXT,
    ZC_UJKAT TEXT,
    ZC_ISEKT TEXT,
    FM_AREA TEXT,
    ZC_DUIF TEXT,
    ZC_URADF TEXT,
    ZC_FORMA TEXT,
    ZC_POCOB TEXT,
    ZC_EXPDAT TEXT,
    ZC_CREDAT TEXT,
    ZC_PUBLST TEXT,
    ZC_VEDUC TEXT,
    ZC_UJZM4 TEXT,
    ZC_ZPODM TEXT,
    ZC_DRI TEXT,
    ZC_STATNI TEXT,
    ZC_TOSS TEXT,
    ZC_UJZFO TEXT,
    ZC_ZUJ TEXT,
    ZC_CISPOU TEXT,
    ZC_CISORP TEXT,
    ZC_AKTDAT TEXT,
    TXTXL TEXT
)
;

TRUNCATE TABLE stg.ciselnik_obce;

COPY stg.ciselnik_obce (
    ZC_UCJED,
    DATETO,
    DATEFROM,
    ZC_ICO,
    ZC_DIC,
    STREET60,
    HOUSE_NUM1,
    CITY_1,
    POSTALCODE,
    ZC_UJZRI,
    ZC_NACE,
    ZC_NUTS,
    ZC_COFOG,
    ZC_UJKAT,
    ZC_ISEKT,
    FM_AREA,
    ZC_DUIF,
    ZC_URADF,
    ZC_FORMA,
    ZC_POCOB,
    ZC_EXPDAT,
    ZC_CREDAT,
    ZC_PUBLST,
    ZC_VEDUC,
    ZC_UJZM4,
    ZC_ZPODM,
    ZC_DRI,
    ZC_STATNI,
    ZC_TOSS,
    ZC_UJZFO,
    ZC_ZUJ,
    ZC_CISPOU,
    ZC_CISORP,
    ZC_AKTDAT,
    TXTXL
)
FROM '/Users/hchyl/Library/Mobile Documents/com~apple~CloudDocs/02_Práce/Datova_analytika/03_Portfolio/finance_obci_cr/data/raw/ciselnik_obce.CSV'
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8')
;


-- Vytvoreni raw tabulky ciselnik_paragrafy a nahrani dat z CSV souboru
CREATE TABLE IF NOT EXISTS stg.ciselnik_paragrafy(
    FUNC_AREA TEXT,
    ZC_SKUP TEXT,
    ZC_ODD TEXT,
    ZC_PODODD TEXT,
    DATEFROM TEXT,
    DATETO TEXT,
    TXTXL TEXT
)
;

TRUNCATE TABLE stg.ciselnik_paragrafy;

COPY stg.ciselnik_paragrafy (
    FUNC_AREA,
    ZC_SKUP,
    ZC_ODD,
    ZC_PODODD,
    DATEFROM,
    DATETO,
    TXTXL
)
FROM '/Users/hchyl/Library/Mobile Documents/com~apple~CloudDocs/02_Práce/Datova_analytika/03_Portfolio/finance_obci_cr/data/raw/ciselnik_paragrafy.CSV' 
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8')
;


-- Vytvoreni raw tabulky ciselnik_prostorova_jednotka a nahrani dat z CSV souboru
CREATE TABLE IF NOT EXISTS stg.ciselnik_prostorova_jednotka(
    ZC_ZDROJ TEXT,
    DATETO TEXT,
    DATEFROM TEXT,
    TXTLG TEXT,
    TXTXL TEXT
);

TRUNCATE TABLE stg.ciselnik_prostorova_jednotka;

COPY stg.ciselnik_prostorova_jednotka (
    ZC_ZDROJ,
    DATETO,
    DATEFROM,
    TXTLG,
    TXTXL
)
FROM '/Users/hchyl/Library/Mobile Documents/com~apple~CloudDocs/02_Práce/Datova_analytika/03_Portfolio/finance_obci_cr/data/raw/ciselnik_prostorova_jednotka.CSV'
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8')
;


-- Vytvoreni raw tabulky ciselnik_nuts a nahrani dat z CSV souboru
CREATE TABLE IF NOT EXISTS stg.ciselnik_nuts (
    ZC_NUTS TEXT,
    ZC_PLATOD TEXT,
    ZC_PLATDO TEXT,
    TXTLG TEXT
)
;

TRUNCATE TABLE stg.ciselnik_nuts;

COPY stg.ciselnik_nuts (
    ZC_NUTS,
    ZC_PLATOD,
    ZC_PLATDO,
    TXTLG
)
FROM '/Users/hchyl/Library/Mobile Documents/com~apple~CloudDocs/02_Práce/Datova_analytika/03_Portfolio/finance_obci_cr/data/raw/ciselnik_nuts.CSV'
WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8')
;


