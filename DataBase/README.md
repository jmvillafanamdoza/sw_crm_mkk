# Base de datos CRM MKK (MAKOKOS)

- `db_ac5777_mkkprod1.sql`: esquema y catálogos exportados de producción el 2026-10-06 (punto de partida).
- `scripts/`: cambios para alinear la BD con el frontend (`starter-kit-front`).

## Cómo aplicar

Los scripts son **idempotentes**: se pueden ejecutar varias veces sin duplicar datos. Ejecútalos en orden; `00_ejecutar_todo.sql` los lanza todos.

```bash
cd DataBase/scripts
sqlcmd -S <servidor> -d <base> -U <usuario> -P <clave> -b -i 00_ejecutar_todo.sql
```

En SSMS, activa *Query > SQLCMD Mode* y abre `00_ejecutar_todo.sql` desde la carpeta `scripts`.

> Pruébalos primero en una copia de la BD. Se validaron en SQL Server LocalDB partiendo de `db_ac5777_mkkprod1.sql`: dos ejecuciones completas seguidas y pruebas funcionales de cada módulo.

| Script | Contenido |
|---|---|
| `01_correcciones.sql` | SPs de `TMKK_TIP_VALOR` corregidos y `PRMKK_DEL_BOF_TIP_VALOR` (la API ya lo invocaba). Corrige tipos de columna inconsistentes y deja los catálogos de asistencia y estados de venta como los usa el front. |
| `02_seguridad_login.sql` | `ESQUEMA_LOGIN.sql` del front (sesiones, recuperación, intentos), ahora idempotente. Sistema, perfiles y menú (espejo de `navigation/vertical`), y SPs de login, sesión, contraseña y menú por usuario. |
| `03_maestros.sql` | Campañas, sedes, ubigeo, planes y listas cortas en `TMKK_TIP_VALOR`, con su CRUD (Mantenimiento). |
| `04_personal_usuarios.sql` | HeadCount (datos laborales, historial de periodos), Registro-Bajas y Mantenimiento > Usuarios. |
| `05_asistencia.sql` | Registro diario, cierre de día, matriz Empleado x Día y dashboard. |
| `06_llamadas.sql` | Tipificaciones y Dash Tipificaciones. |
| `07_ventas.sql` | Registro, lista, detalle, Gestión BO (estados con historial), biometría y metas. |
| `08_comisiones.sql` | Reglas, cálculo mensual y aprobación de comisiones. |
| `09_perfil_dashboard.sql` | Perfil, bitácora, notificaciones y dashboard principal. |

## Correcciones al esquema existente

- **`PRMKK_UPD_BOF_TIP_VALOR` nunca actualizaba.** El `WHERE` comparaba `CTPV_COD_TIP_VALOR` con `@i_CTPV_TIP_VALOR`. Además pisaba `AUD_INS_USER` y podía poner en `NULL` parte de la PK.
- **`PRMKK_CON_BOF_TIP_VALOR`.**
  - Parámetros opcionales: la API lo llama solo con `@i_TIP_VALOR`, y antes eso fallaba.
  - Devuelve las columnas que espera `TipoValorSpResultDto`.
  - Ya no devuelve `id`. El DTO lo declara `int?` y los códigos pueden ser letras (`'P'`), lo que hacía fallar a Dapper.
- **`PRMKK_UPD_BOF_EST_TIP_VALOR`** acepta `A` (lo que envía la API) como sinónimo de `V`.
- **Tipos de columna.** `TMKK_VENTA.SVEN_TIPO_VENTA` pasa a `INT`, como en llamadas y personal. `TPLS_PERSONA.FPER_TIP_DOC_IDENTIDAD` pasa a `TINYINT` con FK a `TMKK_TIP_DOC_IDENTIDAD`. Si hay datos que no se pueden convertir, el script se detiene con un mensaje y no toca nada.
- **`TMKK_SISTEMA`** ahora usa `'V'` como estado por defecto, igual que el resto de tablas.
- **`TMKK_ASISTENCIA`.** `SASI_VISTA` ahora tiene el código del front (`FALTA_INJUSTIFICADA`, ...) y `SASI_COLOR` el color de Vuetify.
- **Estado de venta `INGRESADO`.** Lo usa la lista de ventas y no existía; se agrega con el código `8`.

## Pantalla → stored procedures

| Pantalla | SPs |
|---|---|
| Login | `PRMKK_CON_BOF_LOGIN_USUARIO`, `PRMKK_INS_BOF_INTENTO_LOGIN`, `PRMKK_INS_BOF_USUARIO_SESION`, `PRMKK_CON_BOF_USUARIO_SESION`, `PRMKK_UPD_BOF_REFRESCAR_SESION`, `PRMKK_UPD_BOF_CERRAR_SESION`, `PRMKK_INS_BOF_TOKEN_RECUPERACION`, `PRMKK_UPD_BOF_RESTABLECER_PASSWORD`, `PRMKK_CON_BOF_MENU_USUARIO` |
| Dashboard (`index.vue`) | `PRMKK_CON_BOF_DASHBOARD_GENERAL` (9 result sets) |
| Ventas > Registro | `PRMKK_INS_BOF_VENTA`; combos: `PRMKK_CON_BOF_TIP_DOC_IDENTIDAD`, `PRMKK_CON_BOF_OPERADOR`, `PRMKK_CON_BOF_PLAN`, `PRMKK_CON_BOF_UBIGEO`, `PRMKK_CON_BOF_TIP_VALOR 'MODALIDAD_LINEA'` |
| Ventas > Lista | `PRMKK_CON_BOF_VENTA` (paginada), `PRMKK_CON_BOF_VENTA_RESUMEN_TIPO`, `PRMKK_CON_BOF_VENTA_DETALLE`, `PRMKK_UPD_BOF_VENTA`, `PRMKK_UPD_BOF_VENTA_ESTADO`, `PRMKK_DEL_BOF_VENTA`; combos: `PRMKK_CON_BOF_TIP_VALOR 'CANAL_VENTA' / 'TIPO_VENTA' / 'TIP_ESTADO_VENTA' / 'TIP_MOTIVO_CAIDA'` |
| Asistencia > Registro | `PRMKK_CON_BOF_ASISTENCIA_DIA`, `PRMKK_CON_BOF_ASISTENCIA_EMPLEADO`, `PRMKK_INS_BOF_ASISTENCIA_REGISTRO`, `PRMKK_UPD_BOF_ASISTENCIA_CERRAR_DIA`, `PRMKK_UPD_BOF_ASISTENCIA_REABRIR_DIA`, `PRMKK_CON_BOF_TIPO_ASISTENCIA` |
| Asistencia > Reportes | `PRMKK_CON_BOF_ASISTENCIA_MATRIZ`, `PRMKK_CON_BOF_ASISTENCIA_DASHBOARD` (4 result sets) |
| Llamadas > Dash Tipificaciones | `PRMKK_CON_BOF_LLAMADA_DASH_TIPIFICACION` (2 result sets), `PRMKK_CON_BOF_TIPIFICACION`, `PRMKK_INS_BOF_LLAMADA`, `PRMKK_CON_BOF_LLAMADA` |
| Comisiones | `PRMKK_CON_BOF_COMISION_REGLA`, `PRMKK_INS_BOF_COMISION_REGLA`, `PRMKK_UPD_BOF_EST_COMISION_REGLA`, `PRMKK_PRC_BOF_CALCULAR_COMISION`, `PRMKK_CON_BOF_COMISION`, `PRMKK_CON_BOF_COMISION_DETALLE`, `PRMKK_UPD_BOF_COMISION_ESTADO` |
| HeadCount | `PRMKK_CON_BOF_PERSONAL`, `PRMKK_CON_BOF_PERSONAL_PERIODO`, `PRMKK_CON_BOF_PERSONAL_INDICADORES`, `PRMKK_CON_BOF_ASISTENCIA_MATRIZ @i_CPEL_ID_PERSONAL` (diálogo de asistencias) |
| HeadCount > Registro-Bajas | `PRMKK_CON_BOF_PERSONAL_POR_DOCUMENTO`, `PRMKK_INS_BOF_PERSONAL_BAJA` |
| Mantenimiento > Usuarios | `PRMKK_CON_BOF_USUARIO`, `PRMKK_CON_BOF_USUARIO_RESUMEN`, `PRMKK_INS_BOF_USUARIO`, `PRMKK_UPD_BOF_USUARIO`, `PRMKK_UPD_BOF_EST_USUARIO`, `PRMKK_CON_BOF_PERFIL`, `PRMKK_CON_BOF_SUPERVISOR` |
| Mantenimiento > Campañas / Estados / Operadores | `PRMKK_*_BOF_CAMPANIA`, `PRMKK_*_BOF_TIP_VALOR` (grupo `TIP_ESTADO_VENTA`), `PRMKK_*_BOF_OPERADOR`, `PRMKK_*_BOF_PLAN`, `PRMKK_*_BOF_SEDE` |
| Perfil | `PRMKK_CON_BOF_PERFIL_USUARIO`, `PRMKK_UPD_BOF_PERFIL_USUARIO`, `PRMKK_UPD_BOF_CAMBIAR_PASSWORD`, `PRMKK_CON_BOF_BITACORA`, `PRMKK_CON_BOF_NOTIFICACION`, `PRMKK_UPD_BOF_NOTIFICACION_LEIDA` |

Todos los SPs de escritura devuelven `@o_resultMessage` con el formato `'1|mensaje'` / `'0|error'` que ya parsea `ParsearRespuestaSp` en la API. Los que crean registros devuelven también el id generado en un parámetro `@o_...`.

## Convenciones y decisiones

- **Estados de registro.** `V` = vigente, `I` = inactivo. En `TMKK_PERSONAL` también existe `B` = baja.
- **Contraseñas y tokens.** Solo se guardan hashes; la API genera y verifica los hashes (BCrypt o Argon2).
- **Usuario del front.** Equivale a `TPLS_PERSONA` + `TMKK_USUARIO` + `TMKK_USUARIO_PERFIL` + `TMKK_PERSONAL`; los SPs de usuarios mantienen las cuatro tablas sincronizadas.
- **Bajas y reingresos.** Se registran en `TMKK_PERSONAL_PERIODO`, la fuente del diálogo "Histórico".
- **Nombre completo.** El front captura "Nombres y Apellidos" en un solo campo; se guarda en `TPLS_PERSONA.SPER_NOM_COMPLETO`.
- **Venta nueva.** Arranca en estado `PENDIENTE` (`'3'`). Pasar a `CAIDO` exige un motivo de caída. Pasar a `ACTIVADO` registra la fecha de activación, que es la fecha que usan las comisiones.
- **Resultados que se pivotean.** La matriz de asistencia y "Cantidad por Vendedor" se devuelven en formato largo; la API o el front los pivotean.

## Pendiente de definir por el negocio

- **Campañas iniciales.** Se cargaron PORTABILIDAD, MIGRACIÓN, MANTRA, OUT e IVR PORTABILIDAD. El front usa listas distintas en cada pantalla (son datos mock), así que hay que confirmar la lista real.
- **Reglas de comisión.** No se cargó ninguna; los montos los debe definir el negocio.
- **Ubigeo.** Solo están los distritos que usa el front hoy; falta cargar la lista oficial del INEI.
- **Accesos por perfil.** Los accesos de SUPERVISOR, ASESOR y BACKOFFICE son una propuesta; están en `02_seguridad_login.sql`.
- **Usuario administrador inicial.** No se creó, porque su contraseña depende del algoritmo de hash de la API. Créalo con `PRMKK_INS_BOF_USUARIO` desde la API.
- **"Procesos y Reportes".** La página está vacía en el front y no tiene SPs todavía.
