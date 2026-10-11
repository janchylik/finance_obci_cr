"""
Sestaví data/processed/obce_geo.csv: IČO, kód obce a souřadnice pro mapu v Power BI.

Vstupy (nejsou v repu, viz .gitignore):
  data/raw/ciselnik_obce.CSV  – číselník obcí z data.mf.gov.cz (kód obce = sloupec ZC_ZUJ)
  data/raw/obce.json          – https://data.cesko.digital/obce/1/obce.json
                                (cesko-digital/obce; souřadnice úřadu z RÚIAN, stav k 26. 3. 2023)
  data/raw/obce_hranice.json  – https://raw.githubusercontent.com/siwekm/czech-geojson/master/obce.json
                                (hranice obcí, INSPIRE / ČÚZK, CC BY 4.0; kód obce = nationalCode)

Zdroj souřadnic (priorita):
  1. ruian_adresa   – souřadnice úřadu z obce.json, pokud leží v bounding boxu ČR
  2. stred_polygonu – těžiště hranice obce (pro obce bez souřadnic a pro Prahu)

Obce se párují přes IČO, kód obce se bere z ciselnik_obce (ZC_ZUJ).
Kontrola: vzdálenost bodu z RÚIAN od těžiště polygonu (medián ~0,6 km, max ~6 km; výsledek
se vypisuje). Tři obce měly v obce.json chybný výchozí bod 59.756, 24.829 – ten se zahazuje.
"""
import csv
import json
import math
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BBOX = (48.5, 51.1, 12.0, 18.9)  # lat_min, lat_max, lon_min, lon_max


def nacti_obce_csu():
    """IČO -> kód obce (ZC_ZUJ) pro aktuální obce (forma 801, druh 04, platné do 99991231)."""
    with open(ROOT / "data/raw/ciselnik_obce.CSV", encoding="utf-8", newline="") as f:
        rd = csv.reader(f, delimiter=";")
        hlavicka = next(rd)
        k = {c.split(" ")[0]: i for i, c in enumerate(hlavicka)}
        return {
            x[k["/BIC/ZC_ICO"]]: x[k["/BIC/ZC_ZUJ"]]
            for x in rd
            if x[k["/BIC/ZC_FORMA"]] == "801"
            and x[k["/BIC/ZC_DUIF"]] == "04"
            and x[k["DATETO"]] == "99991231"
        }


def v_cesku(lat, lon):
    return BBOX[0] <= lat <= BBOX[1] and BBOX[2] <= lon <= BBOX[3]


def teziste_prstence(ring):
    """Plošné těžiště prstence [lon, lat] (shoelace); v měřítku obce stačí rovinná aproximace."""
    a = cx = cy = 0.0
    for (x0, y0), (x1, y1) in zip(ring, ring[1:] + ring[:1]):
        c = x0 * y1 - x1 * y0
        a += c
        cx += (x0 + x1) * c
        cy += (y0 + y1) * c
    if a == 0:
        return sum(p[0] for p in ring) / len(ring), sum(p[1] for p in ring) / len(ring), 0.0
    return cx / (3 * a), cy / (3 * a), abs(a) / 2


def teziste_obce(geometry):
    """Těžiště obce (vážené plochou vnějších prstenců) -> (lat, lon)."""
    polygony = [geometry["coordinates"]] if geometry["type"] == "Polygon" else geometry["coordinates"]
    suma = sx = sy = 0.0
    for p in polygony:
        x, y, plocha = teziste_prstence([tuple(b[:2]) for b in p[0]])
        sx += x * plocha
        sy += y * plocha
        suma += plocha
    return (sy / suma, sx / suma)


def km(lat1, lon1, lat2, lon2):
    return math.hypot((lat1 - lat2) * 111.2, (lon1 - lon2) * 111.2 * math.cos(math.radians(lat1)))


def main():
    kody = nacti_obce_csu()
    obce = json.load(open(ROOT / "data/raw/obce.json", encoding="utf-8"))["municipalities"]
    ruian = {r["ICO"]: r["souradnice"] for r in obce if r.get("souradnice")}
    hranice = json.load(open(ROOT / "data/raw/obce_hranice.json", encoding="utf-8"))["features"]
    stredy = {str(f["nationalCode"]): teziste_obce(f["geometry"]) for f in hranice}

    radky, vzdalenosti, zdroje = [], [], {"ruian_adresa": 0, "stred_polygonu": 0}
    for ico in sorted(kody):
        kod = kody[ico]
        centroid = stredy[kod]  # chybí-li kód, má skript spadnout (KeyError), ne mlčet
        if ico in ruian and v_cesku(*ruian[ico]):
            lat, lon = ruian[ico]
            zdroj = "ruian_adresa"
            vzdalenosti.append(km(lat, lon, *centroid))
        else:
            lat, lon = centroid
            zdroj = "stred_polygonu"
        zdroje[zdroj] += 1
        radky.append((ico, kod, f"{lat:.6f}", f"{lon:.6f}", zdroj))

    cil = ROOT / "data/processed/obce_geo.csv"
    with open(cil, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["zc_ico", "kod_obce", "lat", "lon", "zdroj_souradnic"])
        w.writerows(radky)
    print(f"{cil.name}: {len(radky)} obcí | zdroje: {zdroje}")
    print(f"kontrola RÚIAN vs. střed polygonu: medián {statistics.median(vzdalenosti):.2f} km, "
          f"max {max(vzdalenosti):.1f} km, nad 10 km: {sum(v > 10 for v in vzdalenosti)}")


if __name__ == "__main__":
    main()
