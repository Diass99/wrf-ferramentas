# =====================================================================
# ambiente_wrf.sh
#
# Define as variáveis de ambiente para executar o WPS e o WRF-ARW
# compilados com as bibliotecas do sistema (NetCDF em /usr, HDF5 serial).
#
# Uso: source ambiente_wrf.sh
# O arquivo deve ser carregado com "source": executado com "bash", as
# variáveis desapareceriam ao fim do processo. Compatível com bash e zsh.
# =====================================================================

if [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "Use: source ${0}"
    exit 1
fi

export NETCDF=/usr
export HDF5=/usr/lib/x86_64-linux-gnu/hdf5/serial
export LDFLAGS="-L/usr/lib/x86_64-linux-gnu/hdf5/serial/ -L/usr/lib"
export CPPFLAGS="-I/usr/include/hdf5/serial/ -I/usr/include"

# /usr/lib no LD_LIBRARY_PATH (localização de libnetcdff.so.*)
case ":${LD_LIBRARY_PATH:-}:" in
    *:/usr/lib:*) ;;
    *) export LD_LIBRARY_PATH="/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
esac

echo "NETCDF          = $NETCDF"
echo "HDF5            = $HDF5"
echo "LDFLAGS         = $LDFLAGS"
echo "CPPFLAGS        = $CPPFLAGS"
echo "LD_LIBRARY_PATH = $LD_LIBRARY_PATH"
