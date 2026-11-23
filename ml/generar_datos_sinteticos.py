import argparse
import numpy as np, pandas as pd

CATEGORIAS = {"plomeria": .22, "electricidad": .18, "aire_acondicionado": .25, "electrodomesticos": .12,
              "pintura": .08, "cerrajeria": .07, "carpinteria": .04, "albanileria": .04}
# Barrios con su nivel de demanda y de técnicos disponibles
BARRIOS = {"Bocagrande": (.08, .9), "Manga": (.07, .8), "Pie de la Popa": (.07, .75), "El Bosque": (.06, .6),
           "Crespo": (.05, .7), "Torices": (.05, .5), "La Castellana": (.06, .7), "Los Alpes": (.05, .55),
           "Olaya Herrera": (.08, .35), "El Pozón": (.07, .25), "Nelson Mandela": (.05, .2), "San Fernando": (.06, .45),
           "Blas de Lezo": (.06, .65), "Ternera": (.05, .5), "Zaragocilla": (.05, .55), "La Boquilla": (.04, .3), "Otros": (.05, .4)}
PRESUPUESTO_MEDIO = {"plomeria": 80000, "electricidad": 90000, "aire_acondicionado": 120000, "electrodomesticos": 100000,
                     "pintura": 250000, "cerrajeria": 60000, "carpinteria": 150000, "albanileria": 200000}

def generar(n, semilla=42):
    rng = np.random.default_rng(semilla)
    cat = rng.choice(list(CATEGORIAS), n, p=list(CATEGORIAS.values()))
    bnames = list(BARRIOS); bw = np.array([v[0] for v in BARRIOS.values()]); bw /= bw.sum()
    barrio = rng.choice(bnames, n, p=bw)
    cobertura = np.array([BARRIOS[b][1] for b in barrio])
    presupuesto = np.array([rng.lognormal(np.log(PRESUPUESTO_MEDIO[c]), .45) for c in cat]).round(-3)
    presupuesto = np.where(rng.random(n) < .15, np.nan, presupuesto)
    dia = rng.integers(0, 7, n)
    franja = rng.choice(["madrugada", "manana", "tarde", "noche"], n, p=[.05, .4, .35, .2])
    anticipacion = np.where(rng.random(n) < .7, 0, rng.integers(1, 8, n))

    lam = 2.8 * cobertura * np.where(franja == "madrugada", .3, 1) * np.where(dia >= 5, .8, 1)
    postulaciones = rng.poisson(lam)
    t_primera = np.where(postulaciones > 0, rng.exponential(60 / np.maximum(cobertura, .1), n).clip(2, 1440).round(), 1440)
    precio_rel = np.where((postulaciones > 0) & ~np.isnan(presupuesto), rng.normal(1.05, .25, n).clip(.5, 2.5).round(2), np.nan)

    logit = (-1.2 + 1.1 * np.minimum(postulaciones, 4) - 0.0015 * np.minimum(t_primera, 600)
             - 1.3 * np.nan_to_num(np.abs(precio_rel - 1), nan=0.4) + 0.4 * (anticipacion == 0)
             - 0.5 * (franja == "madrugada") + 0.3 * (cat == "aire_acondicionado"))
    contratada = rng.random(n) < 1 / (1 + np.exp(-logit))
    return pd.DataFrame({"categoria": cat, "barrio": barrio, "presupuesto": presupuesto, "dia_semana": dia, "franja_horaria": franja,
                         "dias_anticipacion": anticipacion, "num_postulaciones_24h": postulaciones,
                         "tiempo_primera_postulacion": t_primera, "precio_relativo": precio_rel, "contratada": contratada.astype(int)})

if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--n", type=int, default=4000); ap.add_argument("--salida", default="solicitudes_sinteticas.csv")
    a = ap.parse_args(); df = generar(a.n); df.to_csv(a.salida, index=False)
    print(df.shape, "tasa de contratación:", round(df.contratada.mean(), 3))
