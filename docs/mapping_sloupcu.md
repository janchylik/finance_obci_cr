# Datový slovník a mapování sloupců (FINM201 a číselníky)

Tento dokument slouží jako vysvětlivka k datovým exportům hospodaření obcí (výkaz FIN 2-12 M).

---

## 1. Hlavní tabulka: `FINM201_2025.csv`
Toto je hlavní faktová tabulka (transakce). Obsahuje samotná finanční data.

| Sloupec v datech | Typ/Klíč | Co to znamená lidsky |
| :--- | :--- | :--- |
| `"Fiskální období"0FISCPER:0FISCPER` | Čas | Období ve formátu `RRRRMM` (např. `202512` znamená kumulovaná data ke konci prosince 2025). |
| `"Účetní jednotka"ZC_UCJED:ZC_UCJED` | **Klíč (FK)** | Unikátní ID organizace ve Státní pokladně. **Spojit s `ciselnik_obce.csv`.** |
| `"IČO"ZC_ICO:ZC_ICO` | ID | IČO dané obce nebo organizace. |
| `"Kraj"/BIC/ZC_KRAJ:ZC_KRAJ` | ID | Kód kraje (např. `CZ010`). |
| `"Paragraf"FUNC_AREA:0FUNC_AREA` | **Klíč (FK)** | Účel výdaje/příjmu (např. školství, doprava). **Spojit s `ciselnik_paragrafy.csv`.** *(Pozn.: Paragraf 0 jsou často daně a obecné příjmy).* |
| `"Položka"/BIC/ZCMMT_ITM:ZCMMT_ITM` | **Klíč (FK)** | Druh výdaje/příjmu (např. platy, nákup služeb). **Spojit s `ciselnik_polozky.csv`.** |
| `"Schválený rozpočet"KYF_0001:ZU_ROZSCH` | Hodnota | Původní rozpočet schválený zastupitelstvem na začátku roku (v Kč). |
| `"Sjednaná výše U/Z/NFV"KYF_0002:ZU_ROZPZM` | Hodnota | Rozpočet po změnách (upravený rozpočet) v průběhu roku (v Kč). |
| `"Výsledek od počátku roku"KYF_0003:ZU_ROZKZ` | Hodnota | **Skutečnost.** Reálné příjmy nebo výdaje od 1. 1. do konce daného měsíce (v Kč). |

---

## 2. Číselník: `ciselnik_obce.csv`
Obsahuje detailní informace o samotných obcích a dalších účetních jednotkách.

| Sloupec v datech | Typ/Klíč | Co to znamená lidsky a analyticky |
| :--- | :--- | :--- |
| `/BIC/ZC_UCJED Účetní jednotka` | **Klíč (PK)** | Hlavní identifikátor. Propojovací klíč na hlavní tabulku `FINM201`. |
| `DATEFROM Platí od` / `DATETO Platí do` | Čas | Časová platnost záznamu. (Pokud existuje více záznamů pro jedno IČO, bere se ten s aktuálním datem). |
| `/BIC/ZC_ICO IČO` | ID | IČO organizace (užitečné pro propojování s externími daty, např. z ČSÚ nebo ARES). |
| `/BIC/ZC_DIC DIČ` | ID | Daňové identifikační číslo. |
| `STREET60 CSA: Ulice`, `HOUSE_NUM1 CSA: Číslo domu`, `CITY_1 CSA: Obec`, `POSTALCODE CSA: PSČ` | Geografie | Adresa sídla organizace. `CITY_1` je super pro zobrazení názvu města/obce v grafech. |
| `TXTXL Dlouhý text` | Popis | **Oficiální plný název organizace** (např. "Statutární město Brno" nebo "Základní škola XY"). |
| `/BIC/ZC_UJZRI Zřizovatel účetní jednotky` | Vazba | Pokud je organizace např. škola, zde je kód (ZC_UCJED) obce/kraje, která ji zřizuje. |
| `/BIC/ZC_NACE Klasifikace ... NACE` | Klasifikace | Kód ekonomické činnosti (např. vzdělávání, veřejná správa). |
| `/BIC/ZC_NUTS NUTS - Číslo územní...` | Geografie | NUTS/LAU kód území (výborné pro mapování na mapy ČR). |
| `/BIC/ZC_COFOG COFOG ...` | Klasifikace | Mezinárodní klasifikace funkcí vládních institucí. |
| `/BIC/ZC_UJKAT Kategorie počtu obyvatel` | Analytika | Zařazení obce do velikostní kategorie (skvělé pro srovnávání podobně velkých obcí). |
| `/BIC/ZC_ISEKT ... sektorů` | Klasifikace | Institucionální sektor (dle metodiky ESA 2010). |
| `FM_AREA Kapitola` | Správa | Kapitola státního rozpočtu (pro obce většinou nevyužito/prázdné). |
| `/BIC/ZC_DUIF Druh účetní jednotky` | **Filtrování** | Určuje, o co jde: např. Obec, Kraj, Dobrovolný svazek obcí (DSO), Příspěvková organizace (PO). **Velmi důležité pro filtrování, pokud chceš jen data obcí!** |
| `/BIC/ZC_URADF Poddruh účetní jednotky` | Klasifikace | Detailnější dělení k Druhu účetní jednotky. |
| `/BIC/ZC_FORMA Forma organizace` | Právní info | Právní forma (např. 801 = Obec, 331 = Příspěvková organizace). |
| `/BIC/ZC_POCOB Počet obyvatel` | **Analytika** | Oficiální počet obyvatel obce. (Klíčové pro výpočty typu "Výdaje na obyvatele"). |
| `/BIC/ZC_CREDAT...` / `/BIC/ZC_EXPDAT...` | Čas | Datum vzniku a zániku organizace. |
| `/BIC/ZC_PUBLST`, `VEDUC`, `UJZM4`, `ZPODM`, `DRI`, `STATNI`, `TOSS`, `UJZFO` | Technické | Různé technické a správní příznaky (vedení účetnictví, způsob odměňování, příznak státní správy atd.). Pro základní finanční analýzu většinou nepotřebné. |
| `/BIC/ZC_ZUJ Základní územní jednotka` | Geografie | Kód ZÚJ (často odpovídá ICZUJ z ČSÚ). Důležité pro mapové vizualizace. |
| `/BIC/ZC_CISPOU Obce s pověřeným ... (POÚ)` | Geografie/Správa | Příslušnost obce pod Pověřený obecní úřad. |
| `/BIC/ZC_CISORP Obce s rozšířenou ... (ORP)` | Geografie/Správa | Příslušnost obce pod Obec s rozšířenou působností (tzv. "malé okresy" - super pro agregaci regionů). |
| `/BIC/ZC_AKTDAT Datum aktualizace` | Technické | Datum poslední změny záznamu. |
---

## 3. Číselník: `ciselnik_polozky.csv`
Vysvětluje, za co přesně se utrácelo, nebo z čeho plynuly příjmy.

| Sloupec v datech | Typ/Klíč | Co to znamená lidsky |
| :--- | :--- | :--- |
| `/BIC/ZCMMT_ITM Položka` | **Klíč (PK)** | Číslo položky. Propojuje se s `FINM201`. |
| `/BIC/ZC_TRIDA Třída` | Agregace | Nejvyšší úroveň (např. Třída 1 = Daňové příjmy, Třída 5 = Běžné výdaje, Třída 6 = Kapitálové výdaje). |
| `/BIC/ZC_SES Seskupení` / `PODSES` | Agregace | Střední úroveň dělení rozpočtové skladby. |
| `TXTXL Dlouhý text` | Popis | **Slovní název položky** (např. "Daně z příjmů", "Nákup materiálu"). |

---

## 4. Číselník: `ciselnik_paragrafy.csv`
Vysvětluje, na jaký účel/oblast šly peníze (např. kultura, bezpečnost, doprava).

| Sloupec v datech | Typ/Klíč | Co to znamená lidsky |
| :--- | :--- | :--- |
| `FUNC_AREA Paragraf` | **Klíč (PK)** | Číslo paragrafu. Propojuje se s `FINM201`. |
| `/BIC/ZC_SKUP Skupina` / `ODD` / `PODODD` | Agregace | Vyšší celky (např. Skupina 3 = Služby pro obyvatelstvo, Oddíl 31 a 32 = Vzdělávání a školství). |
| `TXTXL Dlouhý text` | Popis | **Slovní název paragrafu** (např. "Předškolní zařízení", "Silnice"). |

---

## 5. Číselník: `ciselnik_prostorova_jednotka.csv`
Určuje původ peněz, nejčastěji pro identifikaci evropských a národních dotací.

| Sloupec v datech | Typ/Klíč | Co to znamená lidsky |
| :--- | :--- | :--- |
| `/BIC/ZC_ZDROJ Prostorová jednotka` | **Klíč (PK)** | Kód prostorové jednotky. *(Pokud ho máš ve FINM201, propoj přes něj).* |
| `TXTLG` / `TXTXL` | Popis | **Slovní popis zdroje** (např. "Prostředky z rozpočtu EU", "Příjmy a výdaje ze zahraničních zdrojů"). |