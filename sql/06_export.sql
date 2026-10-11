COPY (
    SELECT *
    FROM mart.obec_rok
    ORDER BY zc_ico, rok
) TO '/Users/hchyl/Library/Mobile Documents/com~apple~CloudDocs/02_Práce/Datova_analytika/03_Portfolio/finance_obci_cr/data/processed/obec_rok.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');


COPY (
    SELECT *
    FROM mart.obec_rok_oddil
    ORDER BY zc_ico, rok, oddil

) TO '/Users/hchyl/Library/Mobile Documents/com~apple~CloudDocs/02_Práce/Datova_analytika/03_Portfolio/finance_obci_cr/data/processed/obec_rok_oddil.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');


COPY (
    SELECT * 
    FROM mart.obec_rok_paragraf 
    ORDER BY zc_ico, rok, paragraf
) TO '/Users/hchyl/Library/Mobile Documents/com~apple~CloudDocs/02_Práce/Datova_analytika/03_Portfolio/finance_obci_cr/data/processed/obec_rok_paragraf.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');

COPY (
    SELECT * 
    FROM mart.obec_rok_polozka 
    ORDER BY zc_ico, rok, polozka
)
TO '/Users/hchyl/Library/Mobile Documents/com~apple~CloudDocs/02_Práce/Datova_analytika/03_Portfolio/finance_obci_cr/data/processed/obec_rok_polozka.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');