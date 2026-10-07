-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- SCRIPT 09: PERFIL, ACTIVIDAD, NOTIFICACIONES Y DASHBOARD PRINCIPAL
--   Tablas : TMKK_BITACORA      (Perfil > Cuenta > actividad reciente)
--            TMKK_NOTIFICACION  (Perfil > Notificaciones)
--   SPs    : perfil del usuario en sesión, actualización de datos propios,
--            bitácora, notificaciones y dashboard principal (index.vue).
-- ==============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================================
-- 1. TABLAS
-- ==============================================================================

IF OBJECT_ID('dbo.TMKK_BITACORA') IS NULL
CREATE TABLE dbo.TMKK_BITACORA (
    CBIT_ID_BITACORA    BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_BITACORA PRIMARY KEY,
    CUSU_ID_USUARIO     INT NULL,
    SBIT_MODULO         VARCHAR(50) NOT NULL,       -- LOGIN, USUARIOS, VENTAS, ASISTENCIA, ...
    SBIT_ACCION         VARCHAR(50) NOT NULL,       -- INICIO_SESION, USUARIO_CREADO, USUARIO_EDITADO, PASSWORD_RESTABLECIDO, ...
    SBIT_TITULO         VARCHAR(100) NOT NULL,
    SBIT_DESCRIPCION    VARCHAR(500) NULL,
    SBIT_ENTIDAD        VARCHAR(50) NULL,           -- tabla/entidad afectada
    SBIT_ID_ENTIDAD     VARCHAR(50) NULL,
    SBIT_IP             VARCHAR(45) NULL,
    DBIT_FECHA          DATETIME NOT NULL CONSTRAINT DF_TMKK_BIT_FECHA DEFAULT GETDATE(),
    CONSTRAINT FK_TMKK_BIT_USUARIO FOREIGN KEY (CUSU_ID_USUARIO) REFERENCES dbo.TMKK_USUARIO (CUSU_ID_USUARIO)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TMKK_BIT_USUARIO')
    CREATE INDEX IX_TMKK_BIT_USUARIO ON dbo.TMKK_BITACORA (CUSU_ID_USUARIO, DBIT_FECHA DESC);
GO

IF OBJECT_ID('dbo.TMKK_NOTIFICACION') IS NULL
CREATE TABLE dbo.TMKK_NOTIFICACION (
    CNOT_ID_NOTIFICACION INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_NOTIFICACION PRIMARY KEY,
    CUSU_ID_USUARIO      INT NOT NULL,
    SNOT_TITULO          VARCHAR(100) NOT NULL,
    SNOT_MENSAJE         VARCHAR(500) NULL,
    SNOT_COLOR           VARCHAR(20) NULL,          -- color de Vuetify (primary, success, warning, error, info)
    SNOT_ICONO           VARCHAR(50) NULL,          -- p.ej. tabler-bell
    SNOT_RUTA            VARCHAR(255) NULL,         -- nombre de ruta del front a abrir
    FNOT_LEIDA           CHAR(1) NOT NULL CONSTRAINT DF_TMKK_NOT_LEIDA DEFAULT 'N',
    DNOT_FEC_LECTURA     DATETIME NULL,
    FNOT_ESTADO          CHAR(1) NOT NULL CONSTRAINT DF_TMKK_NOT_ESTADO DEFAULT 'V',
    AUD_INS_FEC          DATETIME NULL,
    AUD_INS_USER         VARCHAR(16) NULL,
    AUD_UPD_FEC          DATETIME NULL,
    AUD_UPD_USER         VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_NOT_USUARIO FOREIGN KEY (CUSU_ID_USUARIO) REFERENCES dbo.TMKK_USUARIO (CUSU_ID_USUARIO) ON DELETE CASCADE
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TMKK_NOT_USUARIO')
    CREATE INDEX IX_TMKK_NOT_USUARIO ON dbo.TMKK_NOTIFICACION (CUSU_ID_USUARIO, FNOT_LEIDA) WHERE FNOT_ESTADO = 'V';
GO

-- ==============================================================================
-- 2. PERFIL DEL USUARIO EN SESIÓN
-- ==============================================================================

-- Dos result sets: 1. datos del usuario (mismas columnas que PRMKK_CON_BOF_USUARIO)
--                  2. estadísticas rápidas de la cabecera del perfil
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_PERFIL_USUARIO
    @i_CUSU_ID_USUARIO INT
AS
BEGIN
    SET NOCOUNT ON;

    EXEC dbo.PRMKK_CON_BOF_USUARIO @i_CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;

    DECLARE @username VARCHAR(50) = (SELECT SUSU_USERNAME FROM dbo.TMKK_USUARIO WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO);

    SELECT
        (SELECT COUNT(DISTINCT CBIT.SBIT_ID_ENTIDAD) FROM dbo.TMKK_BITACORA CBIT
         WHERE CBIT.CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND CBIT.SBIT_MODULO = 'USUARIOS')            AS NUSUARIOS_GESTIONADOS,
        (SELECT COUNT(*) FROM dbo.TMKK_USUARIO WHERE AUD_INS_USER = @username)                          AS NUSUARIOS_CREADOS,
        (SELECT COUNT(*) FROM dbo.TMKK_CAMPANIA WHERE FCAM_ESTADO = 'V')                               AS NCAMPANIAS_ACTIVAS,
        (SELECT COUNT(*) FROM dbo.TMKK_NOTIFICACION
         WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND FNOT_LEIDA = 'N' AND FNOT_ESTADO = 'V')         AS NNOTIFICACIONES_PENDIENTES;
END
GO

-- Datos que el propio usuario puede cambiar (el resto se edita desde Mantenimiento > Usuarios)
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_PERFIL_USUARIO
    @i_CUSU_ID_USUARIO      INT,
    @i_NOMBRE_COMPLETO      VARCHAR(200) = NULL,
    @i_CORREO               VARCHAR(100) = NULL,
    @i_CELULAR              VARCHAR(16)  = NULL,
    @i_CONTACTO_EMERGENCIA  VARCHAR(150) = NULL,
    @i_TEL_EMERGENCIA       VARCHAR(16)  = NULL,
    @i_DIRECCION            VARCHAR(250) = NULL,
    @o_resultMessage        VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @username VARCHAR(16);

        SELECT @username = LEFT(SUSU_USERNAME, 16) FROM dbo.TMKK_USUARIO WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;

        UPDATE p
        SET SPER_NOM_COMPLETO        = COALESCE(NULLIF(@i_NOMBRE_COMPLETO, ''), p.SPER_NOM_COMPLETO),
            SPER_COR_LABORAL         = COALESCE(NULLIF(@i_CORREO, ''), p.SPER_COR_LABORAL),
            SPER_CELULAR             = COALESCE(NULLIF(@i_CELULAR, ''), p.SPER_CELULAR),
            SPER_CONTACTO_EMERGENCIA = COALESCE(NULLIF(@i_CONTACTO_EMERGENCIA, ''), p.SPER_CONTACTO_EMERGENCIA),
            SPER_TEL_EMERGENCIA      = COALESCE(NULLIF(@i_TEL_EMERGENCIA, ''), p.SPER_TEL_EMERGENCIA),
            SPER_DIRECCION           = COALESCE(NULLIF(@i_DIRECCION, ''), p.SPER_DIRECCION),
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @username
        FROM dbo.TPLS_PERSONA p
        JOIN dbo.TMKK_USUARIO u ON u.CPER_ID_PERSONA = p.CPER_ID_PERSONA
        WHERE u.CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_resultMessage = '0|Usuario no encontrado';
            RETURN;
        END

        SET @o_resultMessage = '1|Perfil actualizado';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ==============================================================================
-- 3. BITÁCORA
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_BITACORA
    @i_CUSU_ID_USUARIO INT          = NULL,
    @i_MODULO          VARCHAR(50),
    @i_ACCION          VARCHAR(50),
    @i_TITULO          VARCHAR(100),
    @i_DESCRIPCION     VARCHAR(500) = NULL,
    @i_ENTIDAD         VARCHAR(50)  = NULL,
    @i_ID_ENTIDAD      VARCHAR(50)  = NULL,
    @i_IP              VARCHAR(45)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.TMKK_BITACORA (CUSU_ID_USUARIO, SBIT_MODULO, SBIT_ACCION, SBIT_TITULO, SBIT_DESCRIPCION, SBIT_ENTIDAD, SBIT_ID_ENTIDAD, SBIT_IP)
    VALUES (@i_CUSU_ID_USUARIO, @i_MODULO, @i_ACCION, @i_TITULO, NULLIF(@i_DESCRIPCION, ''), @i_ENTIDAD, @i_ID_ENTIDAD, @i_IP);
END
GO

-- Actividad reciente. El front calcula "hace 12 min" a partir de DBIT_FECHA.
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_BITACORA
    @i_CUSU_ID_USUARIO INT         = NULL,
    @i_MODULO          VARCHAR(50) = NULL,
    @i_TOP             INT         = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@i_TOP)
        b.CBIT_ID_BITACORA, b.CUSU_ID_USUARIO, u.SUSU_USERNAME, b.SBIT_MODULO, b.SBIT_ACCION,
        b.SBIT_TITULO, b.SBIT_DESCRIPCION, b.SBIT_ENTIDAD, b.SBIT_ID_ENTIDAD, b.DBIT_FECHA,
        CASE
            WHEN b.SBIT_ACCION LIKE '%CREAD%' OR b.SBIT_ACCION LIKE '%REGISTR%' THEN 'success'
            WHEN b.SBIT_ACCION LIKE '%EDITAD%' OR b.SBIT_ACCION LIKE '%ACTUALIZ%' THEN 'info'
            WHEN b.SBIT_ACCION LIKE '%PASSWORD%' OR b.SBIT_ACCION LIKE '%BAJA%' THEN 'warning'
            WHEN b.SBIT_ACCION LIKE '%ELIMIN%' OR b.SBIT_ACCION LIKE '%FALL%' THEN 'error'
            ELSE 'primary'
        END AS SCOLOR
    FROM dbo.TMKK_BITACORA b
    LEFT JOIN dbo.TMKK_USUARIO u ON u.CUSU_ID_USUARIO = b.CUSU_ID_USUARIO
    WHERE (@i_CUSU_ID_USUARIO IS NULL OR b.CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO)
      AND (NULLIF(@i_MODULO, '') IS NULL OR b.SBIT_MODULO = @i_MODULO)
    ORDER BY b.DBIT_FECHA DESC, b.CBIT_ID_BITACORA DESC;
END
GO

-- ==============================================================================
-- 4. NOTIFICACIONES
-- ==============================================================================

-- Con @i_CUSU_ID_USUARIO NULL se notifica a todos los usuarios activos del perfil indicado
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_NOTIFICACION
    @i_CUSU_ID_USUARIO INT          = NULL,
    @i_CPFL_ID_PERFIL  INT          = NULL,
    @i_TITULO          VARCHAR(100),
    @i_MENSAJE         VARCHAR(500) = NULL,
    @i_COLOR           VARCHAR(20)  = 'primary',
    @i_ICONO           VARCHAR(50)  = NULL,
    @i_RUTA            VARCHAR(255) = NULL,
    @i_AUD_USER        VARCHAR(16),
    @o_resultMessage   VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @i_CUSU_ID_USUARIO IS NULL AND @i_CPFL_ID_PERFIL IS NULL
        BEGIN
            SET @o_resultMessage = '0|Indique el usuario o el perfil destinatario';
            RETURN;
        END

        INSERT INTO dbo.TMKK_NOTIFICACION (CUSU_ID_USUARIO, SNOT_TITULO, SNOT_MENSAJE, SNOT_COLOR, SNOT_ICONO, SNOT_RUTA, AUD_INS_FEC, AUD_INS_USER)
        SELECT u.CUSU_ID_USUARIO, @i_TITULO, NULLIF(@i_MENSAJE, ''), @i_COLOR, @i_ICONO, @i_RUTA, GETDATE(), @i_AUD_USER
        FROM dbo.TMKK_USUARIO u
        WHERE u.FUSU_ESTADO = 'V'
          AND (u.CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO
               OR (@i_CUSU_ID_USUARIO IS NULL AND EXISTS (SELECT 1 FROM dbo.TMKK_USUARIO_PERFIL up
                                                          WHERE up.CUSU_ID_USUARIO = u.CUSU_ID_USUARIO
                                                            AND up.CPFL_ID_PERFIL = @i_CPFL_ID_PERFIL AND up.FUSR_ESTADO = 'V')));

        SET @o_resultMessage = '1|Se enviaron ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' notificaciones';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_NOTIFICACION
    @i_CUSU_ID_USUARIO INT,
    @i_SOLO_NO_LEIDAS  CHAR(1) = 'N',
    @i_TOP             INT     = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@i_TOP)
        CNOT_ID_NOTIFICACION, SNOT_TITULO, SNOT_MENSAJE, SNOT_COLOR, SNOT_ICONO, SNOT_RUTA,
        CASE WHEN FNOT_LEIDA = 'S' THEN 1 ELSE 0 END AS BLEIDA, DNOT_FEC_LECTURA, AUD_INS_FEC AS DFECHA
    FROM dbo.TMKK_NOTIFICACION
    WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND FNOT_ESTADO = 'V'
      AND (ISNULL(@i_SOLO_NO_LEIDAS, 'N') <> 'S' OR FNOT_LEIDA = 'N')
    ORDER BY AUD_INS_FEC DESC, CNOT_ID_NOTIFICACION DESC;
END
GO

-- Marca como leída una notificación, o todas las del usuario si @i_CNOT_ID_NOTIFICACION es NULL
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_NOTIFICACION_LEIDA
    @i_CUSU_ID_USUARIO      INT,
    @i_CNOT_ID_NOTIFICACION INT = NULL,
    @o_resultMessage        VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        UPDATE dbo.TMKK_NOTIFICACION
        SET FNOT_LEIDA = 'S', DNOT_FEC_LECTURA = GETDATE(), AUD_UPD_FEC = GETDATE()
        WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND FNOT_LEIDA = 'N' AND FNOT_ESTADO = 'V'
          AND (@i_CNOT_ID_NOTIFICACION IS NULL OR CNOT_ID_NOTIFICACION = @i_CNOT_ID_NOTIFICACION);

        SET @o_resultMessage = '1|Notificaciones marcadas como leídas';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ==============================================================================
-- 5. DASHBOARD PRINCIPAL (src/pages/index.vue)
--    Nueve result sets (QueryMultiple):
--      1. KPIs del mes vs. mes anterior (ventas, llamadas, asistencia, comisiones) y meta
--      2. Ventas exitosas por día de la semana de referencia (L..D)
--      3. Ventas por tipo
--      4. Ventas por plan
--      5. Ventas por campaña
--      6. Ventas por estado
--      7. Top 5 asesores
--      8. Últimas 5 ventas
--      9. Serie mensual del año (ventas, llamadas, % asistencia, comisiones)
--    "Ventas exitosas" = estado ACTIVADO o INGRESADO.
--    Con @i_CPEL_ID_ASESOR el dashboard se limita a ese asesor (perfil ASESOR).
-- ==============================================================================
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_DASHBOARD_GENERAL
    @i_PERIODO          INT = NULL,      -- AAAAMM; NULL = mes actual
    @i_CCAM_ID_CAMPANIA INT = NULL,
    @i_CPEL_ID_ASESOR   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);
    SET @i_PERIODO = ISNULL(@i_PERIODO, YEAR(@hoy) * 100 + MONTH(@hoy));

    DECLARE @ini DATE = DATEFROMPARTS(@i_PERIODO / 100, @i_PERIODO % 100, 1);
    DECLARE @fin DATE = DATEADD(MONTH, 1, @ini);                    -- exclusivo
    DECLARE @iniAnt DATE = DATEADD(MONTH, -1, @ini);
    DECLARE @periodoAnt INT = YEAR(@iniAnt) * 100 + MONTH(@iniAnt);
    DECLARE @ref DATE = CASE WHEN @hoy < @fin THEN @hoy ELSE DATEADD(DAY, -1, @fin) END;   -- último día con datos del periodo
    DECLARE @lunes DATE = DATEADD(DAY, -((DATEPART(WEEKDAY, @ref) + @@DATEFIRST - 2) % 7), @ref);
    DECLARE @iniAnio DATE = DATEFROMPARTS(YEAR(@ini), 1, 1);

    -- Ventas vigentes del año del periodo (base de casi todos los result sets)
    SELECT v.CVEN_ID_VENTA, v.DVEN_FECHA_REGISTRO, CAST(v.DVEN_FECHA_REGISTRO AS DATE) AS DFECHA, v.SVEN_TIPO_VENTA,
           v.CVEN_ESTADO_VENTA, v.CPLN_ID_CODIGO, v.CCAM_ID_CAMPANIA, v.CPEL_ID_ASESOR, v.NVEN_VALOR, v.SVEN_CELULAR
    INTO #ven
    FROM dbo.TMKK_VENTA v
    WHERE v.FVEN_ESTADO = 'V'
      AND v.DVEN_FECHA_REGISTRO >= CASE WHEN @iniAnt < @iniAnio THEN @iniAnt ELSE @iniAnio END
      AND v.DVEN_FECHA_REGISTRO < CASE WHEN @fin > DATEADD(YEAR, 1, @iniAnio) THEN @fin ELSE DATEADD(YEAR, 1, @iniAnio) END
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR v.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (@i_CPEL_ID_ASESOR IS NULL OR v.CPEL_ID_ASESOR = @i_CPEL_ID_ASESOR);

    SELECT l.CLLM_ID_LLAMADA, CAST(l.DLLM_FEC_LLAMADA AS DATE) AS DFECHA
    INTO #lla
    FROM dbo.TMKK_LLAMADA l
    WHERE l.FLLM_ESTADO = 'V'
      AND l.DLLM_FEC_LLAMADA >= CASE WHEN @iniAnt < @iniAnio THEN @iniAnt ELSE @iniAnio END
      AND l.DLLM_FEC_LLAMADA < CASE WHEN @fin > DATEADD(YEAR, 1, @iniAnio) THEN @fin ELSE DATEADD(YEAR, 1, @iniAnio) END
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR l.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (@i_CPEL_ID_ASESOR IS NULL OR l.CPEL_ID_PERSONAL = @i_CPEL_ID_ASESOR);

    SELECT r.DARE_FECHA AS DFECHA, r.FARE_PRESENTE, r.CPEL_ID_PERSONAL
    INTO #asi
    FROM dbo.TMKK_ASISTENCIA_REGISTRO r
    JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = r.CPEL_ID_PERSONAL
    WHERE r.FARE_ESTADO = 'V' AND r.CASI_ID_ASISTENCIA IS NOT NULL
      AND r.DARE_FECHA >= CASE WHEN @iniAnt < @iniAnio THEN @iniAnt ELSE @iniAnio END
      AND r.DARE_FECHA < CASE WHEN @fin > DATEADD(YEAR, 1, @iniAnio) THEN @fin ELSE DATEADD(YEAR, 1, @iniAnio) END
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (@i_CPEL_ID_ASESOR IS NULL OR r.CPEL_ID_PERSONAL = @i_CPEL_ID_ASESOR);

    SELECT c.NCOM_PERIODO, c.NCOM_MONTO_COMISION
    INTO #com
    FROM dbo.TMKK_COMISION c
    JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = c.CPEL_ID_PERSONAL
    WHERE c.FCOM_ESTADO <> 'X'
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (@i_CPEL_ID_ASESOR IS NULL OR c.CPEL_ID_PERSONAL = @i_CPEL_ID_ASESOR);

    -- 1. KPIs
    SELECT
        @i_PERIODO AS NPERIODO,
        (SELECT COUNT(*) FROM #ven WHERE DFECHA >= @ini AND DFECHA < @fin)                         AS NVENTAS_MES,
        (SELECT COUNT(*) FROM #ven WHERE DFECHA >= @iniAnt AND DFECHA < @ini)                      AS NVENTAS_MES_ANTERIOR,
        (SELECT COUNT(*) FROM #ven WHERE DFECHA BETWEEN @lunes AND @ref)                           AS NVENTAS_SEMANA,
        (SELECT COUNT(*) FROM #lla WHERE DFECHA >= @ini AND DFECHA < @fin)                         AS NLLAMADAS_MES,
        (SELECT COUNT(*) FROM #lla WHERE DFECHA >= @iniAnt AND DFECHA < @ini)                      AS NLLAMADAS_MES_ANTERIOR,
        (SELECT COUNT(*) FROM #lla WHERE DFECHA = @ref)                                            AS NLLAMADAS_DIA,
        (SELECT CAST(ISNULL(100.0 * SUM(CASE WHEN FARE_PRESENTE = 'S' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 0) AS DECIMAL(5, 2))
         FROM #asi WHERE DFECHA >= @ini AND DFECHA < @fin)                                         AS NASISTENCIA_MES,
        (SELECT CAST(ISNULL(100.0 * SUM(CASE WHEN FARE_PRESENTE = 'S' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 0) AS DECIMAL(5, 2))
         FROM #asi WHERE DFECHA >= @iniAnt AND DFECHA < @ini)                                      AS NASISTENCIA_MES_ANTERIOR,
        (SELECT COUNT(*) FROM #asi WHERE DFECHA = @ref AND FARE_PRESENTE = 'S')                    AS NPRESENTES_DIA,
        (SELECT COUNT(*) FROM dbo.TMKK_PERSONAL
         WHERE FPEl_ESTADO = 'V' AND (@i_CCAM_ID_CAMPANIA IS NULL OR CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
           AND (@i_CPEL_ID_ASESOR IS NULL OR CPEL_ID_PERSONAL = @i_CPEL_ID_ASESOR))                AS NPERSONAL_ACTIVO,
        (SELECT ISNULL(SUM(NCOM_MONTO_COMISION), 0) FROM #com WHERE NCOM_PERIODO = @i_PERIODO)     AS NCOMISIONES_MES,
        (SELECT ISNULL(SUM(NCOM_MONTO_COMISION), 0) FROM #com WHERE NCOM_PERIODO = @periodoAnt)    AS NCOMISIONES_MES_ANTERIOR,
        (SELECT TOP (1) NMET_CANTIDAD FROM dbo.TMKK_META_VENTA
         WHERE NMET_PERIODO = @i_PERIODO AND FMET_ESTADO = 'V'
           AND ((@i_CCAM_ID_CAMPANIA IS NULL AND CCAM_ID_CAMPANIA IS NULL) OR CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)) AS NMETA_VENTAS,
        (SELECT COUNT(*) FROM #ven WHERE DFECHA >= @ini AND DFECHA < @fin AND CVEN_ESTADO_VENTA IN ('1', '8')) AS NVENTAS_EXITOSAS_MES;

    -- 2. Ventas exitosas por día de la semana (L..D)
    ;WITH dias AS (
        SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
    )
    SELECT DATEADD(DAY, d.n, @lunes) AS DFECHA,
           SUBSTRING('LMXJVSD', d.n + 1, 1) AS SDIA,
           (SELECT COUNT(*) FROM #ven v WHERE v.DFECHA = DATEADD(DAY, d.n, @lunes) AND v.CVEN_ESTADO_VENTA IN ('1', '8')) AS NCANTIDAD
    FROM dias d
    ORDER BY d.n;

    -- 3. Por tipo
    SELECT CAST(tv.CTPV_TIP_VALOR AS INT) AS NTIPO_VENTA, tv.STPV_DES_TIP_VALOR_1 AS STIPO_VENTA, COUNT(v.CVEN_ID_VENTA) AS NCANTIDAD,
           CAST(ISNULL(100.0 * COUNT(v.CVEN_ID_VENTA) / NULLIF(SUM(COUNT(v.CVEN_ID_VENTA)) OVER (), 0), 0) AS DECIMAL(5, 2)) AS NPORCENTAJE
    FROM dbo.TMKK_TIP_VALOR tv
    LEFT JOIN #ven v ON v.SVEN_TIPO_VENTA = CAST(tv.CTPV_TIP_VALOR AS INT) AND v.DFECHA >= @ini AND v.DFECHA < @fin
    WHERE tv.CTPV_COD_TIP_VALOR = 'TIPO_VENTA' AND tv.FTPV_ESTADO = 'V'
    GROUP BY tv.CTPV_TIP_VALOR, tv.STPV_DES_TIP_VALOR_1
    ORDER BY NCANTIDAD DESC;

    -- 4. Por plan
    SELECT pl.CPLN_ID_CODIGO, pl.SPLN_NOMBRE AS SPLAN, COUNT(*) AS NVENTAS
    FROM #ven v
    JOIN dbo.TMKK_PLAN pl ON pl.CPLN_ID_CODIGO = v.CPLN_ID_CODIGO
    WHERE v.DFECHA >= @ini AND v.DFECHA < @fin
    GROUP BY pl.CPLN_ID_CODIGO, pl.SPLN_NOMBRE
    ORDER BY NVENTAS DESC;

    -- 5. Por campaña
    SELECT c.CCAM_ID_CAMPANIA, ISNULL(c.SCAM_NOMBRE, 'SIN CAMPAÑA') AS SCAMPANIA, c.SCAM_COLOR, COUNT(*) AS NCANTIDAD,
           CAST(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0) AS DECIMAL(5, 2)) AS NPORCENTAJE
    FROM #ven v
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = v.CCAM_ID_CAMPANIA
    WHERE v.DFECHA >= @ini AND v.DFECHA < @fin
    GROUP BY c.CCAM_ID_CAMPANIA, c.SCAM_NOMBRE, c.SCAM_COLOR
    ORDER BY NCANTIDAD DESC;

    -- 6. Por estado
    SELECT v.CVEN_ESTADO_VENTA, ev.STPV_DES_TIP_VALOR_1 AS SESTADO_VENTA, ev.STPV_DES_TIP_VALOR_2 AS SESTADO_COLOR, COUNT(*) AS NCANTIDAD,
           CAST(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0) AS DECIMAL(5, 2)) AS NPORCENTAJE
    FROM #ven v
    LEFT JOIN dbo.TMKK_TIP_VALOR ev ON ev.CTPV_COD_TIP_VALOR = 'TIP_ESTADO_VENTA' AND ev.CTPV_TIP_VALOR = v.CVEN_ESTADO_VENTA
    WHERE v.DFECHA >= @ini AND v.DFECHA < @fin
    GROUP BY v.CVEN_ESTADO_VENTA, ev.STPV_DES_TIP_VALOR_1, ev.STPV_DES_TIP_VALOR_2
    ORDER BY NCANTIDAD DESC;

    -- 7. Top asesores
    SELECT TOP (5) v.CPEL_ID_ASESOR,
           COALESCE(p.SPER_NOM_COMPLETO, NULLIF(LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE)), '')) AS SASESOR,
           c.SCAM_NOMBRE AS SCAMPANIA,
           COUNT(*) AS NVENTAS,
           SUM(CASE WHEN v.CVEN_ESTADO_VENTA IN ('1', '8') THEN 1 ELSE 0 END) AS NVENTAS_EXITOSAS,
           ISNULL(SUM(v.NVEN_VALOR), 0) AS NMONTO
    FROM #ven v
    JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = v.CPEL_ID_ASESOR
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA
    WHERE v.DFECHA >= @ini AND v.DFECHA < @fin
    GROUP BY v.CPEL_ID_ASESOR, p.SPER_NOM_COMPLETO, p.SPER_APE_PATERNO, p.SPER_APE_MATERNO, p.SPER_NOMBRE, c.SCAM_NOMBRE
    ORDER BY NVENTAS DESC, NMONTO DESC;

    -- 8. Últimas ventas
    SELECT TOP (5) v.CVEN_ID_VENTA, v.DVEN_FECHA_REGISTRO,
           COALESCE(p.SPER_NOM_COMPLETO, NULLIF(LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE)), '')) AS SASESOR,
           v.SVEN_CELULAR AS SCEL_MIGRACION, pl.SPLN_NOMBRE AS SPLAN, v.NVEN_VALOR,
           ev.STPV_DES_TIP_VALOR_1 AS SESTADO_VENTA, ev.STPV_DES_TIP_VALOR_2 AS SESTADO_COLOR
    FROM #ven v
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = v.CPEL_ID_ASESOR
    LEFT JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_PLAN pl ON pl.CPLN_ID_CODIGO = v.CPLN_ID_CODIGO
    LEFT JOIN dbo.TMKK_TIP_VALOR ev ON ev.CTPV_COD_TIP_VALOR = 'TIP_ESTADO_VENTA' AND ev.CTPV_TIP_VALOR = v.CVEN_ESTADO_VENTA
    WHERE v.DFECHA < @fin
    ORDER BY v.DVEN_FECHA_REGISTRO DESC;

    -- 9. Serie mensual del año
    ;WITH meses AS (
        SELECT 1 AS m UNION ALL SELECT m + 1 FROM meses WHERE m < 12
    )
    SELECT ms.m AS NMES,
           YEAR(@ini) * 100 + ms.m AS NPERIODO,
           (SELECT COUNT(*) FROM #ven v WHERE YEAR(v.DFECHA) = YEAR(@ini) AND MONTH(v.DFECHA) = ms.m) AS NVENTAS,
           (SELECT COUNT(*) FROM #lla l WHERE YEAR(l.DFECHA) = YEAR(@ini) AND MONTH(l.DFECHA) = ms.m) AS NLLAMADAS,
           (SELECT CAST(ISNULL(100.0 * SUM(CASE WHEN a.FARE_PRESENTE = 'S' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 0) AS DECIMAL(5, 2))
            FROM #asi a WHERE YEAR(a.DFECHA) = YEAR(@ini) AND MONTH(a.DFECHA) = ms.m) AS NASISTENCIA,
           (SELECT ISNULL(SUM(c.NCOM_MONTO_COMISION), 0) FROM #com c WHERE c.NCOM_PERIODO = YEAR(@ini) * 100 + ms.m) AS NCOMISIONES
    FROM meses ms
    ORDER BY ms.m;
END
GO
