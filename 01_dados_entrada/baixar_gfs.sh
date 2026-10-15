#!/usr/bin/env bash
set -Eeuo pipefail

# by: Vinicius Jose Dias

# ==================== CONFIGURACOES ====================
ANO="${ANO:-2025}"
MES="${MES:-12}"
DIA="${DIA:-08}"
CICLO="${CICLO:-00}"          # 00, 06, 12, 18

# Janela de horas a partir de base_dt (CICLO) para montar a grade temporal
HORA_INICIAL_FCST="${HORA_INICIAL_FCST:-0}"     # em horas
HORA_FINAL_FCST="${HORA_FINAL_FCST:-96}"        # em horas
PASSO_FCST="${PASSO_FCST:-6}"                   # em horas (6 h p/ LBC do WRF)

# Base padrao de saida: $HOME/arquivos/Build_WRF/DATA[/NAME]
DIR_BASE="${DIR_BASE:-${HOME}/arquivos/Build_WRF/DATA${NAME:+/${NAME}}}"

# ORIGEM: auto | nomads | ncei_gfs05 | rda_fnl   (alias: fnl == rda_fnl)
ORIGEM="${ORIGEM:-auto}"

# Checagem de cabecalho (HEAD) antes de baixar:
#   0 = checa HEAD (seguro), 1 = pula HEAD (mais rapido)
SKIP_HEAD="${SKIP_HEAD:-0}"

# Paralelismo (HEAD e download)
HEAD_THREADS="${HEAD_THREADS:-8}"
THREADS="${THREADS:-4}"

# NCEI: alem do 000 (analise), tambem tentar 003 e 006? (NCEI_PLUS="003,006")
NCEI_PLUS="${NCEI_PLUS:-}"

# URL base para FNL no GDEX (ds083.2)
FNL_GDEX_BASE="${FNL_GDEX_BASE:-https://osdf-director.osg-htc.org/ncar/gdex/d083002/grib2}"
# =======================================================

DATA_URL="${ANO}${MES}${DIA}"
base_dt="${ANO}-${MES}-${DIA} ${CICLO}:00:00"

# ---- helpers ----
tem_cmd(){ command -v "$1" >/dev/null 2>&1; }
url_ok(){ curl -fsI --retry 2 --retry-delay 2 "$1" >/dev/null; }

# Datas em epoch
dt_target=$(date -u -d "$base_dt" +%s || echo 0)
now_utc=$(date -u +%s)
age_sec=$(( now_utc - dt_target ))
nine_days=$((9*24*3600))

# normaliza alias
[[ "$ORIGEM" == "fnl" ]] && ORIGEM="rda_fnl"

# Se auto: recente -> NOMADS; mais antigo -> NCEI GFS 0.5 (e, se falhar, cai pro FNL/GDEX)
if [[ "$ORIGEM" == "auto" ]]; then
  if (( dt_target>0 && age_sec >= 0 && age_sec < nine_days )); then
    ORIGEM="nomads"
  else
    ORIGEM="ncei_gfs05"
  fi
fi

# Resolve RESOL (apenas para nome da pasta)
case "$ORIGEM" in
  nomads)     RESOL="0p25" ;;
  ncei_gfs05) RESOL="0p50" ;;
  rda_fnl)    RESOL="1p00" ;;
  *) echo "Origem invalida: $ORIGEM"; exit 2 ;;
esac

DIR_SAIDA="${DIR_BASE}/${DATA_URL}_${CICLO}Z_${RESOL}"
mkdir -p "$DIR_SAIDA"

echo "================================================="
echo "Downloader GFS/FNL"
echo "Data: ${DIA}/${MES}/${ANO}  Ciclo: ${CICLO}Z"
echo "Origem: ${ORIGEM^^}"
echo "Destino: ${DIR_SAIDA}"
echo "================================================="

tmp_urls="$(mktemp)"
tmp_ok="$(mktemp)"
trap 'rm -f "$tmp_urls" "$tmp_ok"' EXIT
: > "$tmp_urls"

# ================ NOMADS: GFS 0.25° =================
if [[ "$ORIGEM" == "nomads" ]]; then
  BASE="https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.${DATA_URL}/${CICLO}/atmos"

  for H in $(seq "$HORA_INICIAL_FCST" "$PASSO_FCST" "$HORA_FINAL_FCST"); do
    printf "%s/gfs.t%sz.pgrb2.0p25.f%03d\n" "$BASE" "$CICLO" "$H" >> "$tmp_urls"
  done

  echo "Verificando disponibilidade no NOMADS (${HORA_INICIAL_FCST}-${HORA_FINAL_FCST}h passo ${PASSO_FCST}h)..."
  : > "$tmp_ok"
  if [[ "$SKIP_HEAD" == "1" ]]; then
    cp "$tmp_urls" "$tmp_ok"
  else
    if tem_cmd xargs; then
      set +e
      < "$tmp_urls" xargs -P "$HEAD_THREADS" -r -n1 sh -c '
        u="$1"
        curl -fsI --retry 2 --retry-delay 1 "$u" >/dev/null && echo "$u"
      ' _ > "$tmp_ok"
      set -e
    else
      while IFS= read -r u; do url_ok "$u" && echo "$u" >> "$tmp_ok"; done < "$tmp_urls"
    fi
  fi

  total=$(wc -l < "$tmp_urls" || echo 0)
  ok=$(wc -l < "$tmp_ok" || echo 0)
  echo "URLs previstas: $total | Disponiveis: $ok"
  [[ -s "$tmp_ok" ]] || { echo "Nada disponivel no NOMADS para essa data/ciclo."; exit 1; }

  echo ""
  echo "Baixando arquivos (NOMADS GFS 0.25°)..."
  if tem_cmd aria2c; then
    aria2c -x8 -s8 -j"$THREADS" -c -d "$DIR_SAIDA" -i "$tmp_ok"
  else
    if tem_cmd xargs; then
      < "$tmp_ok" xargs -n1 -P"$THREADS" -I{} wget -c --show-progress -P "$DIR_SAIDA" {}
    else
      while IFS= read -r u; do wget -c --show-progress -P "$DIR_SAIDA" "$u"; done < "$tmp_ok"
    fi
  fi

# ================ NCEI: GFS 0.5° (analysis) =================
elif [[ "$ORIGEM" == "ncei_gfs05" ]]; then
  steps=$(( HORA_FINAL_FCST / 6 ))
  t0=$(date -u -d "$base_dt" +%s) || { echo "Data base invalida: $base_dt"; exit 2; }

  IFS=',' read -r -a plus_arr <<< "${NCEI_PLUS}"

  for ((k=0; k<=steps; k++)); do
    tk=$(( t0 + k*6*3600 ))
    YMD=$(date -u -d "@$tk" +%Y%m%d)
    YM=${YMD:0:6}
    HH=$(date -u -d "@$tk" +%H)
    echo "https://www.ncei.noaa.gov/data/global-forecast-system/access/grid-004-0.5-degree/analysis/${YM}/${YMD}/gfs_4_${YMD}_${HH}00_000.grb2" >> "$tmp_urls"
    for off in "${plus_arr[@]}"; do
      [[ -n "${off:-}" ]] && echo "https://www.ncei.noaa.gov/data/global-forecast-system/access/grid-004-0.5-degree/analysis/${YM}/${YMD}/gfs_4_${YMD}_${HH}00_${off}.grb2" >> "$tmp_urls"
    done
  done

  echo "Verificando disponibilidade no NCEI (analises 0.5°)..."
  : > "$tmp_ok"
  if [[ "$SKIP_HEAD" == "1" ]]; then
    cp "$tmp_urls" "$tmp_ok"
  else
    if tem_cmd xargs; then
      set +e
      < "$tmp_urls" xargs -P "$HEAD_THREADS" -r -n1 sh -c '
        u="$1"
        curl -fsI --retry 2 --retry-delay 1 "$u" >/dev/null && echo "$u"
      ' _ > "$tmp_ok"
      set -e
    else
      while IFS= read -r u; do url_ok "$u" && echo "$u" >> "$tmp_ok"; done < "$tmp_urls"
    fi
  fi

  total=$(wc -l < "$tmp_urls" || echo 0)
  ok=$(wc -l < "$tmp_ok" || echo 0)
  echo "URLs previstas: $total | Disponiveis: $ok"

  if [[ ! -s "$tmp_ok" ]]; then
    echo "NCEI nao possui dados para essa janela. Trocando para FNL (GDEX / ds083.2)..."
    ORIGEM="rda_fnl"
  else
    echo ""
    echo "Baixando arquivos (NCEI GFS 0.5°)..."
    if tem_cmd aria2c; then
      aria2c -x8 -s8 -j"$THREADS" -c -d "$DIR_SAIDA" -i "$tmp_ok"
    else
      if tem_cmd xargs; then
        < "$tmp_ok" xargs -n1 -P"$THREADS" -I{} wget -c --show-progress -P "$DIR_SAIDA" {}
      else
        while IFS= read -r u; do wget -c --show-progress -P "$DIR_SAIDA" "$u"; done < "$tmp_ok"
      fi
    fi
  fi
fi

# ================ FNL: GDEX / ds083.2 (1.0°) =================
if [[ "$ORIGEM" == "rda_fnl" ]]; then
  # Aqui usamos a mesma ideia do script csh da GDEX, mas gerando datas a partir de base_dt.
  steps=$(( HORA_FINAL_FCST / 6 ))
  t0=$(date -u -d "$base_dt" +%s) || { echo "Data base invalida: $base_dt"; exit 2; }

  : > "$tmp_urls"
  for ((k=0; k<=steps; k++)); do
    tk=$(( t0 + k*6*3600 ))
    Y=$(date -u -d "@$tk" +%Y)
    YM=$(date -u -d "@$tk" +%Y.%m)
    YMD=$(date -u -d "@$tk" +%Y%m%d)
    HH=$(date -u -d "@$tk" +%H)
    printf "%s/%s/%s/fnl_%s_%s_00.grib2\n" \
      "$FNL_GDEX_BASE" "$Y" "$YM" "$YMD" "$HH" >> "$tmp_urls"
  done

  echo "Verificando disponibilidade no GDEX (FNL 1.0° / ds083.2)..."
  : > "$tmp_ok"
  if [[ "$SKIP_HEAD" == "1" ]]; then
    cp "$tmp_urls" "$tmp_ok"
  else
    if tem_cmd xargs; then
      set +e
      < "$tmp_urls" xargs -P "$HEAD_THREADS" -r -n1 sh -c '
        u="$1"
        curl -fsI --retry 2 --retry-delay 1 "$u" >/dev/null && echo "$u"
      ' _ > "$tmp_ok"
      set -e
    else
      while IFS= read -r u; do url_ok "$u" && echo "$u" >> "$tmp_ok"; done < "$tmp_urls"
    fi
  fi

  total=$(wc -l < "$tmp_urls" || echo 0)
  ok=$(wc -l < "$tmp_ok" || echo 0)
  echo "URLs previstas: $total | Disponiveis (HTTP 200): $ok"

  [[ -s "$tmp_ok" ]] || { 
    echo "Nenhuma URL FNL GDEX respondeu OK. Verifique datas/janela ou necessidade de autenticacao.";
    exit 3
  }

  echo ""
  echo "Baixando arquivos (FNL GDEX / ds083.2)..."
  if tem_cmd aria2c; then
    aria2c -x8 -s8 -j"$THREADS" -c -d "$DIR_SAIDA" -i "$tmp_ok"
  else
    if tem_cmd xargs; then
      < "$tmp_ok" xargs -n1 -P"$THREADS" -I{} wget -c --show-progress -P "$DIR_SAIDA" {}
    else
      while IFS= read -r u; do wget -c --show-progress -P "$DIR_SAIDA" "$u"; done < "$tmp_ok"
      fi
  fi
fi

echo ""
echo "================================================="
echo "Concluido! Arquivos em: $DIR_SAIDA"
echo "================================================="
