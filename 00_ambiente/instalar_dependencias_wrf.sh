#!/usr/bin/env bash
# =====================================================================
# instalar_dependencias_wrf.sh
#
# Instala os pacotes de sistema necessários para executar o WPS e o
# WRF-ARW já compilados (real.exe, wrf.exe), em Debian/Ubuntu.
# Não compila o modelo.
#
# Uso: bash instalar_dependencias_wrf.sh
# Depois, em cada nova sessão: source ambiente_wrf.sh
#
# Origem: unificação de WRF_runtime_libs_setup.sh (JupyterLab do
# VLAB/UFSC) e libs_download_super.sh (cluster da UFSC), por
# Vinícius José Dias.
# =====================================================================
set -euo pipefail

command -v apt-get >/dev/null 2>&1 || { echo "ERRO: requer apt-get (Debian/Ubuntu)."; exit 1; }

echo "Atualizando a lista de pacotes..."
sudo apt-get update

# Escolha da pilha MPI, preservada do instalador original: com mpich >= 4
# no repositório, usa-se OpenMPI; caso contrário, mpich.
versao_mpich="$(apt-cache policy mpich | awk '/Candidate:/ {print $2}' | sed -E 's/^[0-9]+://' | cut -d. -f1)"
if [[ "${versao_mpich:-}" =~ ^[0-9]+$ ]] && (( versao_mpich >= 4 )); then
    pacotes_mpi="libopenmpi-dev libhdf5-openmpi-dev"
else
    pacotes_mpi="mpich libhdf5-mpich-dev"
fi

echo "Instalando NetCDF, NetCDF-Fortran, HDF5, MPI e NCO..."
# shellcheck disable=SC2086
sudo apt-get install -y \
    build-essential csh gfortran m4 curl perl \
    $pacotes_mpi \
    libpng-dev netcdf-bin libnetcdff-dev nco

echo
echo "Dependências instaladas. Em cada nova sessão, carregue o ambiente com:"
echo "  source $(dirname "$0")/ambiente_wrf.sh"
