# wrf-ferramentas

Scripts para preparar o ambiente de execução e obter as condições iniciais e de contorno do modelo WRF-ARW a partir do GFS. Reúnem procedimentos usados na dissertação de mestrado e no artigo derivado do TCC do autor, generalizados para reutilização.

## Estrutura

```text
wrf-ferramentas/
├── 00_ambiente/
│   ├── instalar_dependencias_wrf.sh   pacotes de sistema (NetCDF, HDF5, MPI, NCO)
│   └── ambiente_wrf.sh                variáveis de ambiente (carregar com source)
├── 01_dados_entrada/
│   └── baixar_gfs.sh                  download do GFS/FNL para o ungrib
├── MANIFESTO.tsv
├── LICENSE
└── README.md
```

## Uso

### Ambiente

```bash
bash 00_ambiente/instalar_dependencias_wrf.sh   # uma vez
source 00_ambiente/ambiente_wrf.sh              # em cada sessão
```

`ambiente_wrf.sh` deve ser carregado com `source`; executado com `bash`, as variáveis não permanecem na sessão.

### Condições iniciais e de contorno

Todas as opções de `baixar_gfs.sh` são lidas de variáveis de ambiente. Exemplo para a janela de 216 h iniciada em 25/11/2022 00 UTC, com análises a cada 6 h:

```bash
ANO=2022 MES=11 DIA=25 CICLO=00 HORA_FINAL_FCST=216 PASSO_FCST=6 \
ORIGEM=ncei_gfs05 bash 01_dados_entrada/baixar_gfs.sh
```

| `ORIGEM` | Produto | Resolução | Período |
|---|---|---|---|
| `nomads` | GFS operacional (NOMADS/NCEP), previsões | 0,25° | últimos dias |
| `ncei_gfs05` | GFS, análises da grade 004 (NCEI) | 0,5° | histórico |
| `rda_fnl` (ou `fnl`) | FNL, ds083.2 (NCAR GDEX) | 1,0° | histórico |
| `auto` | `nomads` para datas com menos de 9 dias; `ncei_gfs05` nos demais casos, com recurso ao FNL | | |

Outras variáveis: `HORA_INICIAL_FCST`, `DIR_BASE` (padrão `$HOME/arquivos/Build_WRF/DATA`), `NAME`, `SKIP_HEAD`, `THREADS`, `HEAD_THREADS`, `NCEI_PLUS`, `FNL_GDEX_BASE`. Usa `aria2c` quando disponível e, caso contrário, `wget`.

Para o `ungrib.exe`, use a tabela `Vtable.GFS` distribuída com o WPS (`WPS/ungrib/Variable_Tables/Vtable.GFS`).

## Ambiente testado

WRF-ARW 4.6.1 e WPS 4.6.0 no JupyterLab do VLAB/UFSC (Ubuntu).

## Autor

Vinícius José Dias, Programa de Pós-Graduação em Oceanografia (PPGOceano/UFSC).

## Licença

Código distribuído sob a licença MIT. Ver [`LICENSE`](LICENSE).
