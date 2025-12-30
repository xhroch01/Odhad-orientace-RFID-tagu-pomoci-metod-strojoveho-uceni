# python grid_sweep.py

# Pouzite verze SW = Python 3.8 + pyaedt 0.17.5  |  HFSS 2021.2

from ansys.aedt.core import Desktop, Hfss
from hfss_config import AEDT_VER, PROJECT, DESIGN, SETUP_NAME, EXPORT_BASE
import os
import time
import datetime

#
# Promenne v mm a stupnich
X_MIN_MM = 0
X_MAX_MM = 0
X_STEP_MM = 0       # 0 = pouze jedna hodnota

Y_MIN_MM = 0
Y_MAX_MM = 0
Y_STEP_MM = 0       # 0 = pouze jedna hodnota

ROT_XY_MIN_DEG = 0
ROT_XY_MAX_DEG = 0
ROT_XY_STEP_DEG = 0

ROT_XZ_MIN_DEG = 0
ROT_XZ_MAX_DEG = 0
ROT_XZ_STEP_DEG = 0

ROT_YZ_MIN_DEG = 0
ROT_YZ_MAX_DEG = 0
ROT_YZ_STEP_DEG = 0

# HFSS nastaveni
CORES = 10
FIELD_EXPR = "E_Re_Im"
FREQ = "915MHz"
PHASE = "0deg"
SUBDIR = "AoA_Grid_Dataset"

# Nazvy promennych v HFSS
VAR_X = "X_CS_Tag"
VAR_Y = "Y_CS_Tag"
VAR_ROT_XY = "Tag_Rot_XY"
VAR_ROT_XZ = "Tag_Rot_XZ"
VAR_ROT_YZ = "Tag_Rot_YZ"

# Definice pts souboru
PTS_DIR = r"SEM VLOZIT CESTU K .PTS SOUBORUM!"
PTS_FILES = [
    ("lambda4", os.path.join(PTS_DIR, "AoA_4_ctecky_lambda4.pts")),
    ("lambda2", os.path.join(PTS_DIR, "AoA_4_ctecky_lambda2.pts")),
    ("lambda3", os.path.join(PTS_DIR, "AoA_4_ctecky_lambda3.pts")),
]

# Pomocne funkce

def generate_values(min_val, max_val, step):
    if step == 0 or min_val == max_val:                 # Vrati seznam hodnot podle nastaveni
        return [min_val]
    return list(range(min_val, max_val + step, step))

def token(v):
    return str(v).replace("-", "m")                     # Nahrazeni znamenka minus pro nazev

# Priprava hodnot
X_VALUES = generate_values(X_MIN_MM, X_MAX_MM, X_STEP_MM)
Y_VALUES = generate_values(Y_MIN_MM, Y_MAX_MM, Y_STEP_MM)

ROT_XY_VALUES = generate_values(ROT_XY_MIN_DEG, ROT_XY_MAX_DEG, ROT_XY_STEP_DEG)
ROT_XZ_VALUES = generate_values(ROT_XZ_MIN_DEG, ROT_XZ_MAX_DEG, ROT_XZ_STEP_DEG)
ROT_YZ_VALUES = generate_values(ROT_YZ_MIN_DEG, ROT_YZ_MAX_DEG, ROT_YZ_STEP_DEG)

# Priprava adresare
timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
RUN_DIR = os.path.join(EXPORT_BASE, SUBDIR, timestamp)
os.makedirs(RUN_DIR, exist_ok=True)

print(f"--- Grid Sweep Start: {timestamp} ---")
print(f"Output: {RUN_DIR}")

# Pripojeni k HFSS
Desktop(version=AEDT_VER, new_desktop=False, non_graphical=False, close_on_exit=False)
hfss = Hfss(project=PROJECT, design=DESIGN, new_desktop=False, non_graphical=False, close_on_exit=False)
fields = hfss.odesign.GetModule("FieldsReporter")

start_time = time.time()
counter = 0
total_sims = (len(X_VALUES) * len(Y_VALUES) * len(ROT_XY_VALUES) * len(ROT_XZ_VALUES) * len(ROT_YZ_VALUES))

# Hlavni loop
for x in X_VALUES:
    for y in Y_VALUES:
        for rot_xy in ROT_XY_VALUES:
            for rot_xz in ROT_XZ_VALUES:
                for rot_yz in ROT_YZ_VALUES:
                    counter += 1
                    print(f"--- SIMULATION [{counter}/{total_sims}] X={x}, Y={y}, RotXY={rot_xy} ---")

                    # Nastaveni promennych
                    hfss[VAR_X] = f"{x}mm"
                    hfss[VAR_Y] = f"{y}mm"
                    hfss[VAR_ROT_XY] = f"{rot_xy}deg"
                    hfss[VAR_ROT_XZ] = f"{rot_xz}deg"
                    hfss[VAR_ROT_YZ] = f"{rot_yz}deg"

                    # Spusteni simulace
                    hfss.analyze_setup(SETUP_NAME, cores=CORES)

                    # Nastaveni stacku kalkulatoru
                    fields.CopyNamedExprToStack(FIELD_EXPR)

                    for label, pts_path in PTS_FILES:
                        # Vytvoreni podadresare dle rozestupu lambda
                        out_subdir = os.path.join(RUN_DIR, label)
                        os.makedirs(out_subdir, exist_ok=True)

                        # Nazev souboru
                        fname = (
                            f"AoA_{label}"
                            f"_X_cs_{token(x)}_Y_cs_{token(y)}"
                            f"_RotXY_{token(rot_xy)}"
                            f"_RotXZ_{token(rot_xz)}_RotYZ_{token(rot_yz)}.fld"
                        )
                        
                        # Ulozeni
                        fields.ExportToFile(
                            os.path.join(out_subdir, fname),
                            pts_path,
                            f"{SETUP_NAME} : LastAdaptive",
                            ["Freq:=", FREQ, "Phase:=", PHASE],
                            True
                        )

print(f"\n --- Dataset hotovy. Celkovy cas simulace: {(time.time() - start_time)/60:.1f} min --- ")