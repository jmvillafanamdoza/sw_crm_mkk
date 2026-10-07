-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- Ejecuta todos los scripts en orden. Requiere modo SQLCMD:
--   * sqlcmd:  sqlcmd -S <servidor> -d <base> -U <usuario> -P <clave> -b -f 65001 -i 00_ejecutar_todo.sql
--   * SSMS  :  menú Query > SQLCMD Mode, abrir este archivo desde la carpeta scripts y ejecutar.
-- Todos los scripts son idempotentes: si uno falla, corrija y vuelva a ejecutar todo.
-- ==============================================================================
:on error exit

:r 01_correcciones.sql
:r 02_seguridad_login.sql
:r 03_maestros.sql
:r 04_personal_usuarios.sql
:r 05_asistencia.sql
:r 06_llamadas.sql
:r 07_ventas.sql
:r 08_comisiones.sql
:r 09_perfil_dashboard.sql

PRINT 'Scripts aplicados correctamente.';
GO
