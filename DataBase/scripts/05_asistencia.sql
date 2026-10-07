-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- SCRIPT 05: ASISTENCIA (Registro de Asistencia, Reportes: Matriz y Dashboard)
--   Tablas : TMKK_ASISTENCIA_REGISTRO (marcaciones por persona y día)
--            TMKK_ASISTENCIA_CIERRE   (días cerrados: bloquean la edición)
--   SPs    : vista "Por Día", vista "Por Empleado", guardado, cierre/reapertura
--            de día, matriz Empleado x Día y dashboard.
--
-- El tipo de asistencia viaja con el código que usa el front (TMKK_ASISTENCIA.SASI_VISTA:
-- PUNTUAL, TARDANZA, FALTA_JUSTIFICADA, ...). 'PENDIENTE' = sin tipo (NULL).
-- ==============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================================
-- 1. TABLAS
-- ==============================================================================

IF OBJECT_ID('dbo.TMKK_ASISTENCIA_REGISTRO') IS NULL
CREATE TABLE dbo.TMKK_ASISTENCIA_REGISTRO (
    CARE_ID_REGISTRO    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_ASISTENCIA_REGISTRO PRIMARY KEY,
    CPEL_ID_PERSONAL    INT NOT NULL,
    DARE_FECHA          DATE NOT NULL,
    HARE_ENTRADA        TIME(0) NULL,
    HARE_INICIO_BREAK   TIME(0) NULL,
    HARE_FIN_BREAK      TIME(0) NULL,
    HARE_SALIDA         TIME(0) NULL,
    CASI_ID_ASISTENCIA  INT NULL,               -- NULL = PENDIENTE
    NARE_MIN_TARDANZA   SMALLINT NOT NULL CONSTRAINT DF_TMKK_ARE_TARDANZA DEFAULT 0,
    FARE_PRESENTE       CHAR(1) NOT NULL CONSTRAINT DF_TMKK_ARE_PRESENTE DEFAULT 'N',   -- S/N
    FARE_CERRADO        CHAR(1) NOT NULL CONSTRAINT DF_TMKK_ARE_CERRADO DEFAULT 'N',    -- S = día cerrado
    SARE_OBSERVACION    VARCHAR(500) NULL,
    FARE_ESTADO         CHAR(1) NOT NULL CONSTRAINT DF_TMKK_ARE_ESTADO DEFAULT 'V',
    AUD_INS_FEC         DATETIME NULL,
    AUD_INS_USER        VARCHAR(16) NULL,
    AUD_UPD_FEC         DATETIME NULL,
    AUD_UPD_USER        VARCHAR(16) NULL,
    CONSTRAINT UQ_TMKK_ARE_PERSONAL_FECHA UNIQUE (CPEL_ID_PERSONAL, DARE_FECHA),
    CONSTRAINT FK_TMKK_ARE_PERSONAL FOREIGN KEY (CPEL_ID_PERSONAL) REFERENCES dbo.TMKK_PERSONAL (CPEL_ID_PERSONAL),
    CONSTRAINT FK_TMKK_ARE_ASISTENCIA FOREIGN KEY (CASI_ID_ASISTENCIA) REFERENCES dbo.TMKK_ASISTENCIA (CASI_ID_ASISTENCIA),
    CONSTRAINT CK_TMKK_ARE_TARDANZA CHECK (NARE_MIN_TARDANZA >= 0)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TMKK_ARE_FECHA')
    CREATE INDEX IX_TMKK_ARE_FECHA ON dbo.TMKK_ASISTENCIA_REGISTRO (DARE_FECHA) INCLUDE (CPEL_ID_PERSONAL, CASI_ID_ASISTENCIA, NARE_MIN_TARDANZA, FARE_PRESENTE);
GO

IF OBJECT_ID('dbo.TMKK_ASISTENCIA_CIERRE') IS NULL
CREATE TABLE dbo.TMKK_ASISTENCIA_CIERRE (
    CACI_ID_CIERRE      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_ASISTENCIA_CIERRE PRIMARY KEY,
    DACI_FECHA          DATE NOT NULL,
    CCAM_ID_CAMPANIA    INT NULL,               -- NULL = todas las campañas
    FACI_ESTADO         CHAR(1) NOT NULL CONSTRAINT DF_TMKK_ACI_ESTADO DEFAULT 'V',   -- V = cerrado, I = reabierto
    AUD_INS_FEC         DATETIME NULL,
    AUD_INS_USER        VARCHAR(16) NULL,
    AUD_UPD_FEC         DATETIME NULL,
    AUD_UPD_USER        VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_ACI_CAMPANIA FOREIGN KEY (CCAM_ID_CAMPANIA) REFERENCES dbo.TMKK_CAMPANIA (CCAM_ID_CAMPANIA)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TMKK_ACI_FECHA')
    CREATE INDEX IX_TMKK_ACI_FECHA ON dbo.TMKK_ASISTENCIA_CIERRE (DACI_FECHA, CCAM_ID_CAMPANIA) WHERE FACI_ESTADO = 'V';
GO

-- ==============================================================================
-- 2. STORED PROCEDURES
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Vista "Por Día": todo el personal vigente en la fecha (tenga o no marcación).
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_ASISTENCIA_DIA
    @i_FECHA            DATE,
    @i_CCAM_ID_CAMPANIA INT = NULL,
    @i_CPEL_ID_SUPERVISOR INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.CARE_ID_REGISTRO,
        pe.CPEL_ID_PERSONAL,
        COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SEMPLEADO,
        c.SCAM_NOMBRE                                   AS SCAMPANIA,
        CONVERT(VARCHAR(5), pe.HPEL_HORA_INICIO, 108) + ' - ' + CONVERT(VARCHAR(5), pe.HPEL_HORA_FIN, 108) AS SHORARIO,
        @i_FECHA                                        AS DFECHA,
        CONVERT(VARCHAR(5), r.HARE_ENTRADA, 108)        AS SENTRADA,
        CONVERT(VARCHAR(5), r.HARE_INICIO_BREAK, 108)   AS SINICIO_BREAK,
        CONVERT(VARCHAR(5), r.HARE_FIN_BREAK, 108)      AS SFIN_BREAK,
        CONVERT(VARCHAR(5), r.HARE_SALIDA, 108)         AS SSALIDA,
        ISNULL(a.SASI_VISTA, 'PENDIENTE')               AS STIPO_ASISTENCIA,
        ISNULL(r.NARE_MIN_TARDANZA, 0)                  AS NTARDANZA,
        CASE WHEN r.FARE_PRESENTE = 'S' THEN 1 ELSE 0 END AS BPRESENTE,
        CASE WHEN r.FARE_CERRADO = 'S' OR ci.CACI_ID_CIERRE IS NOT NULL THEN 1 ELSE 0 END AS BCERRADO,
        r.SARE_OBSERVACION
    FROM dbo.TMKK_PERSONAL pe
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_ASISTENCIA_REGISTRO r ON r.CPEL_ID_PERSONAL = pe.CPEL_ID_PERSONAL AND r.DARE_FECHA = @i_FECHA AND r.FARE_ESTADO = 'V'
    LEFT JOIN dbo.TMKK_ASISTENCIA a ON a.CASI_ID_ASISTENCIA = r.CASI_ID_ASISTENCIA
    OUTER APPLY (SELECT TOP (1) CACI_ID_CIERRE FROM dbo.TMKK_ASISTENCIA_CIERRE
                 WHERE DACI_FECHA = @i_FECHA AND FACI_ESTADO = 'V'
                   AND (CCAM_ID_CAMPANIA IS NULL OR CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA)) ci
    WHERE (r.CARE_ID_REGISTRO IS NOT NULL
           OR EXISTS (SELECT 1 FROM dbo.TMKK_PERSONAL_PERIODO pp
                      WHERE pp.CPEL_ID_PERSONAL = pe.CPEL_ID_PERSONAL AND pp.FPPE_ESTADO = 'V'
                        AND pp.DPPE_FEC_INICIO <= @i_FECHA AND (pp.DPPE_FEC_FIN IS NULL OR pp.DPPE_FEC_FIN >= @i_FECHA)))
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (@i_CPEL_ID_SUPERVISOR IS NULL OR pe.CPEL_ID_SUPERVISOR = @i_CPEL_ID_SUPERVISOR)
    ORDER BY SEMPLEADO;
END
GO

-- ------------------------------------------------------------------------------
-- Vista "Por Empleado": una fila por cada día del rango (máximo 366 días).
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_ASISTENCIA_EMPLEADO
    @i_CPEL_ID_PERSONAL INT,
    @i_FEC_INICIO       DATE,
    @i_FEC_FIN          DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @i_FEC_FIN < @i_FEC_INICIO OR DATEDIFF(DAY, @i_FEC_INICIO, @i_FEC_FIN) > 365
    BEGIN
        RAISERROR('Rango de fechas no válido (máximo 366 días).', 16, 1);
        RETURN;
    END

    ;WITH dias AS (
        SELECT TOP (DATEDIFF(DAY, @i_FEC_INICIO, @i_FEC_FIN) + 1)
               DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, @i_FEC_INICIO) AS fecha
        FROM sys.all_objects
    )
    SELECT
        r.CARE_ID_REGISTRO,
        pe.CPEL_ID_PERSONAL,
        COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SEMPLEADO,
        c.SCAM_NOMBRE                                   AS SCAMPANIA,
        d.fecha                                         AS DFECHA,
        CONVERT(VARCHAR(5), r.HARE_ENTRADA, 108)        AS SENTRADA,
        CONVERT(VARCHAR(5), r.HARE_INICIO_BREAK, 108)   AS SINICIO_BREAK,
        CONVERT(VARCHAR(5), r.HARE_FIN_BREAK, 108)      AS SFIN_BREAK,
        CONVERT(VARCHAR(5), r.HARE_SALIDA, 108)         AS SSALIDA,
        ISNULL(a.SASI_VISTA, 'PENDIENTE')               AS STIPO_ASISTENCIA,
        ISNULL(r.NARE_MIN_TARDANZA, 0)                  AS NTARDANZA,
        CASE WHEN r.FARE_PRESENTE = 'S' THEN 1 ELSE 0 END AS BPRESENTE,
        CASE WHEN r.FARE_CERRADO = 'S' OR EXISTS (
                 SELECT 1 FROM dbo.TMKK_ASISTENCIA_CIERRE ci
                 WHERE ci.DACI_FECHA = d.fecha AND ci.FACI_ESTADO = 'V'
                   AND (ci.CCAM_ID_CAMPANIA IS NULL OR ci.CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA))
             THEN 1 ELSE 0 END                          AS BCERRADO,
        r.SARE_OBSERVACION
    FROM dias d
    CROSS JOIN dbo.TMKK_PERSONAL pe
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_ASISTENCIA_REGISTRO r ON r.CPEL_ID_PERSONAL = pe.CPEL_ID_PERSONAL AND r.DARE_FECHA = d.fecha AND r.FARE_ESTADO = 'V'
    LEFT JOIN dbo.TMKK_ASISTENCIA a ON a.CASI_ID_ASISTENCIA = r.CASI_ID_ASISTENCIA
    WHERE pe.CPEL_ID_PERSONAL = @i_CPEL_ID_PERSONAL
    ORDER BY d.fecha;
END
GO

-- ------------------------------------------------------------------------------
-- Guardado único (lo usan las vistas "Por Día" y "Por Empleado"): inserta o
-- actualiza la marcación del día. No permite editar días cerrados.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_ASISTENCIA_REGISTRO
    @i_CPEL_ID_PERSONAL INT,
    @i_FECHA            DATE,
    @i_TIPO_ASISTENCIA  VARCHAR(100),           -- SASI_VISTA o 'PENDIENTE'
    @i_MIN_TARDANZA     SMALLINT     = 0,
    @i_PRESENTE         CHAR(1)      = 'N',     -- S/N
    @i_HORA_ENTRADA     TIME(0)      = NULL,
    @i_HORA_INICIO_BREAK TIME(0)     = NULL,
    @i_HORA_FIN_BREAK   TIME(0)      = NULL,
    @i_HORA_SALIDA      TIME(0)      = NULL,
    @i_OBSERVACION      VARCHAR(500) = NULL,
    @i_AUD_USER         VARCHAR(16),
    @o_CARE_ID_REGISTRO INT OUTPUT,
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @tipo INT = NULL, @campania INT;

        SELECT @campania = CCAM_ID_CAMPANIA FROM dbo.TMKK_PERSONAL WHERE CPEL_ID_PERSONAL = @i_CPEL_ID_PERSONAL;
        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_resultMessage = '0|Personal no encontrado';
            RETURN;
        END

        IF ISNULL(@i_TIPO_ASISTENCIA, 'PENDIENTE') <> 'PENDIENTE'
        BEGIN
            SELECT @tipo = CASI_ID_ASISTENCIA FROM dbo.TMKK_ASISTENCIA
            WHERE SASI_VISTA = @i_TIPO_ASISTENCIA AND FASI_ESTADO = 'V';

            IF @tipo IS NULL
            BEGIN
                SET @o_resultMessage = '0|Tipo de asistencia no válido: ' + @i_TIPO_ASISTENCIA;
                RETURN;
            END
        END

        IF EXISTS (SELECT 1 FROM dbo.TMKK_ASISTENCIA_REGISTRO
                   WHERE CPEL_ID_PERSONAL = @i_CPEL_ID_PERSONAL AND DARE_FECHA = @i_FECHA AND FARE_CERRADO = 'S')
           OR EXISTS (SELECT 1 FROM dbo.TMKK_ASISTENCIA_CIERRE
                      WHERE DACI_FECHA = @i_FECHA AND FACI_ESTADO = 'V'
                        AND (CCAM_ID_CAMPANIA IS NULL OR CCAM_ID_CAMPANIA = @campania))
        BEGIN
            SET @o_resultMessage = '0|El día ya fue cerrado; no se puede modificar';
            RETURN;
        END

        UPDATE dbo.TMKK_ASISTENCIA_REGISTRO
        SET @o_CARE_ID_REGISTRO = CARE_ID_REGISTRO,
            CASI_ID_ASISTENCIA = @tipo,
            NARE_MIN_TARDANZA  = ISNULL(@i_MIN_TARDANZA, 0),
            FARE_PRESENTE      = ISNULL(@i_PRESENTE, 'N'),
            HARE_ENTRADA       = COALESCE(@i_HORA_ENTRADA, HARE_ENTRADA),
            HARE_INICIO_BREAK  = COALESCE(@i_HORA_INICIO_BREAK, HARE_INICIO_BREAK),
            HARE_FIN_BREAK     = COALESCE(@i_HORA_FIN_BREAK, HARE_FIN_BREAK),
            HARE_SALIDA        = COALESCE(@i_HORA_SALIDA, HARE_SALIDA),
            SARE_OBSERVACION   = COALESCE(NULLIF(@i_OBSERVACION, ''), SARE_OBSERVACION),
            FARE_ESTADO        = 'V',
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
        WHERE CPEL_ID_PERSONAL = @i_CPEL_ID_PERSONAL AND DARE_FECHA = @i_FECHA;

        IF @@ROWCOUNT = 0
        BEGIN
            INSERT INTO dbo.TMKK_ASISTENCIA_REGISTRO
                (CPEL_ID_PERSONAL, DARE_FECHA, HARE_ENTRADA, HARE_INICIO_BREAK, HARE_FIN_BREAK, HARE_SALIDA,
                 CASI_ID_ASISTENCIA, NARE_MIN_TARDANZA, FARE_PRESENTE, SARE_OBSERVACION, AUD_INS_FEC, AUD_INS_USER)
            VALUES
                (@i_CPEL_ID_PERSONAL, @i_FECHA, @i_HORA_ENTRADA, @i_HORA_INICIO_BREAK, @i_HORA_FIN_BREAK, @i_HORA_SALIDA,
                 @tipo, ISNULL(@i_MIN_TARDANZA, 0), ISNULL(@i_PRESENTE, 'N'), NULLIF(@i_OBSERVACION, ''), GETDATE(), @i_AUD_USER);

            SET @o_CARE_ID_REGISTRO = SCOPE_IDENTITY();
        END

        SET @o_resultMessage = '1|Asistencia guardada';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- Botón "Cerrar Día": crea las filas que falten (quedan como PENDIENTE) para el
-- personal vigente y bloquea la edición de esa fecha.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_ASISTENCIA_CERRAR_DIA
    @i_FECHA            DATE,
    @i_CCAM_ID_CAMPANIA INT = NULL,     -- NULL = todas las campañas
    @i_AUD_USER         VARCHAR(16),
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.TMKK_ASISTENCIA_CIERRE
                   WHERE DACI_FECHA = @i_FECHA AND FACI_ESTADO = 'V'
                     AND (CCAM_ID_CAMPANIA IS NULL OR CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA))
        BEGIN
            SET @o_resultMessage = '0|El día ya se encuentra cerrado';
            RETURN;
        END

        BEGIN TRANSACTION;

        INSERT INTO dbo.TMKK_ASISTENCIA_REGISTRO (CPEL_ID_PERSONAL, DARE_FECHA, AUD_INS_FEC, AUD_INS_USER)
        SELECT pe.CPEL_ID_PERSONAL, @i_FECHA, GETDATE(), @i_AUD_USER
        FROM dbo.TMKK_PERSONAL pe
        WHERE (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
          AND EXISTS (SELECT 1 FROM dbo.TMKK_PERSONAL_PERIODO pp
                      WHERE pp.CPEL_ID_PERSONAL = pe.CPEL_ID_PERSONAL AND pp.FPPE_ESTADO = 'V'
                        AND pp.DPPE_FEC_INICIO <= @i_FECHA AND (pp.DPPE_FEC_FIN IS NULL OR pp.DPPE_FEC_FIN >= @i_FECHA))
          AND NOT EXISTS (SELECT 1 FROM dbo.TMKK_ASISTENCIA_REGISTRO r
                          WHERE r.CPEL_ID_PERSONAL = pe.CPEL_ID_PERSONAL AND r.DARE_FECHA = @i_FECHA);

        UPDATE r
        SET FARE_CERRADO = 'S', AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
        FROM dbo.TMKK_ASISTENCIA_REGISTRO r
        JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = r.CPEL_ID_PERSONAL
        WHERE r.DARE_FECHA = @i_FECHA
          AND (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA);

        INSERT INTO dbo.TMKK_ASISTENCIA_CIERRE (DACI_FECHA, CCAM_ID_CAMPANIA, AUD_INS_FEC, AUD_INS_USER)
        VALUES (@i_FECHA, @i_CCAM_ID_CAMPANIA, GETDATE(), @i_AUD_USER);

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Día cerrado correctamente';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- Reapertura de un día cerrado (uso administrativo)
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_ASISTENCIA_REABRIR_DIA
    @i_FECHA            DATE,
    @i_CCAM_ID_CAMPANIA INT = NULL,
    @i_AUD_USER         VARCHAR(16),
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.TMKK_ASISTENCIA_CIERRE
        SET FACI_ESTADO = 'I', AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
        WHERE DACI_FECHA = @i_FECHA AND FACI_ESTADO = 'V'
          AND ((@i_CCAM_ID_CAMPANIA IS NULL AND CCAM_ID_CAMPANIA IS NULL) OR CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA);

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SET @o_resultMessage = '0|El día no se encuentra cerrado';
            RETURN;
        END

        UPDATE r
        SET FARE_CERRADO = 'N', AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
        FROM dbo.TMKK_ASISTENCIA_REGISTRO r
        JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = r.CPEL_ID_PERSONAL
        WHERE r.DARE_FECHA = @i_FECHA
          AND (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA);

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Día reabierto correctamente';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- Reportes > Matriz (Empleado x Día). Se devuelve en formato largo (una fila por
-- empleado y día); la API/front lo pivotea. SCODIGO sigue codigoAsistencia() del
-- front: P, T<min>, FJ, FI, DM, otra abreviatura, o '-' sin registro.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_ASISTENCIA_MATRIZ
    @i_FEC_INICIO       DATE,
    @i_FEC_FIN          DATE,
    @i_CCAM_ID_CAMPANIA INT = NULL,
    @i_CPEL_ID_SUPERVISOR INT = NULL,
    @i_CPEL_ID_PERSONAL INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @i_FEC_FIN < @i_FEC_INICIO OR DATEDIFF(DAY, @i_FEC_INICIO, @i_FEC_FIN) > 365
    BEGIN
        RAISERROR('Rango de fechas no válido (máximo 366 días).', 16, 1);
        RETURN;
    END

    ;WITH dias AS (
        SELECT TOP (DATEDIFF(DAY, @i_FEC_INICIO, @i_FEC_FIN) + 1)
               DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, @i_FEC_INICIO) AS fecha
        FROM sys.all_objects
    ),
    personal AS (
        SELECT pe.CPEL_ID_PERSONAL, pe.CCAM_ID_CAMPANIA, pe.CPEL_ID_SUPERVISOR, pe.CPER_ID_PERSONA,
               pe.HPEL_HORA_INICIO, pe.HPEL_HORA_FIN
        FROM dbo.TMKK_PERSONAL pe
        WHERE (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
          AND (@i_CPEL_ID_SUPERVISOR IS NULL OR pe.CPEL_ID_SUPERVISOR = @i_CPEL_ID_SUPERVISOR)
          AND (@i_CPEL_ID_PERSONAL IS NULL OR pe.CPEL_ID_PERSONAL = @i_CPEL_ID_PERSONAL)
          AND EXISTS (SELECT 1 FROM dbo.TMKK_PERSONAL_PERIODO pp
                      WHERE pp.CPEL_ID_PERSONAL = pe.CPEL_ID_PERSONAL AND pp.FPPE_ESTADO = 'V'
                        AND pp.DPPE_FEC_INICIO <= @i_FEC_FIN AND (pp.DPPE_FEC_FIN IS NULL OR pp.DPPE_FEC_FIN >= @i_FEC_INICIO))
    )
    SELECT
        pe.CPEL_ID_PERSONAL,
        COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SEMPLEADO,
        c.SCAM_NOMBRE AS SCAMPANIA,
        COALESCE(ps.SPER_NOM_COMPLETO, NULLIF(LTRIM(CONCAT(ps.SPER_APE_PATERNO, ' ', ps.SPER_APE_MATERNO, ' ', ps.SPER_NOMBRE)), '')) AS SSUPERVISOR,
        CONVERT(VARCHAR(5), pe.HPEL_HORA_INICIO, 108) + ' - ' + CONVERT(VARCHAR(5), pe.HPEL_HORA_FIN, 108) AS SHORARIO,
        d.fecha AS DFECHA,
        CASE
            WHEN a.SASI_ABREVIATURA IS NULL THEN '-'
            WHEN a.SASI_ABREVIATURA = 'T' THEN 'T' + CAST(r.NARE_MIN_TARDANZA AS VARCHAR(5))
            ELSE a.SASI_ABREVIATURA
        END AS SCODIGO,
        a.SASI_VISTA AS STIPO_ASISTENCIA,
        a.SASI_COLOR
    FROM personal pe
    CROSS JOIN dias d
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_PERSONAL sup ON sup.CPEL_ID_PERSONAL = pe.CPEL_ID_SUPERVISOR
    LEFT JOIN dbo.TPLS_PERSONA ps ON ps.CPER_ID_PERSONA = sup.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_ASISTENCIA_REGISTRO r ON r.CPEL_ID_PERSONAL = pe.CPEL_ID_PERSONAL AND r.DARE_FECHA = d.fecha AND r.FARE_ESTADO = 'V'
    LEFT JOIN dbo.TMKK_ASISTENCIA a ON a.CASI_ID_ASISTENCIA = r.CASI_ID_ASISTENCIA
    ORDER BY SEMPLEADO, d.fecha;
END
GO

-- ------------------------------------------------------------------------------
-- Reportes > Dashboard. Cuatro result sets (QueryMultiple en Dapper):
--   1. Distribución por tipo de asistencia (KPIs %, gráfico dona)
--   2. Conteo por día y tipo (barras apiladas)
--   3. Top 5 minutos de tardanza por empleado
--   4. Top 5 faltas injustificadas por empleado
-- Los registros PENDIENTE no cuentan para los porcentajes.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_ASISTENCIA_DASHBOARD
    @i_FEC_INICIO         DATE,
    @i_FEC_FIN            DATE,
    @i_CCAM_ID_CAMPANIA   INT = NULL,
    @i_CPEL_ID_SUPERVISOR INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.CPEL_ID_PERSONAL, r.DARE_FECHA, r.NARE_MIN_TARDANZA, a.CASI_ID_ASISTENCIA, a.SASI_VISTA, a.SASI_NOMBRE, a.SASI_COLOR,
           COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SEMPLEADO
    INTO #reg
    FROM dbo.TMKK_ASISTENCIA_REGISTRO r
    JOIN dbo.TMKK_ASISTENCIA a ON a.CASI_ID_ASISTENCIA = r.CASI_ID_ASISTENCIA
    JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = r.CPEL_ID_PERSONAL
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    WHERE r.FARE_ESTADO = 'V'
      AND r.DARE_FECHA BETWEEN @i_FEC_INICIO AND @i_FEC_FIN
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (@i_CPEL_ID_SUPERVISOR IS NULL OR pe.CPEL_ID_SUPERVISOR = @i_CPEL_ID_SUPERVISOR);

    DECLARE @total INT = (SELECT COUNT(*) FROM #reg);

    -- 1
    SELECT a.SASI_VISTA, a.SASI_NOMBRE, a.SASI_ABREVIATURA, a.SASI_COLOR,
           COUNT(r.CPEL_ID_PERSONAL) AS NCANTIDAD,
           CAST(CASE WHEN @total = 0 THEN 0 ELSE 100.0 * COUNT(r.CPEL_ID_PERSONAL) / @total END AS DECIMAL(5, 2)) AS NPORCENTAJE
    FROM dbo.TMKK_ASISTENCIA a
    LEFT JOIN #reg r ON r.CASI_ID_ASISTENCIA = a.CASI_ID_ASISTENCIA
    WHERE a.FASI_ESTADO = 'V'
    GROUP BY a.CASI_ID_ASISTENCIA, a.SASI_VISTA, a.SASI_NOMBRE, a.SASI_ABREVIATURA, a.SASI_COLOR
    ORDER BY a.CASI_ID_ASISTENCIA;

    -- 2
    SELECT DARE_FECHA AS DFECHA, SASI_VISTA, COUNT(*) AS NCANTIDAD
    FROM #reg
    GROUP BY DARE_FECHA, SASI_VISTA
    ORDER BY DARE_FECHA, SASI_VISTA;

    -- 3
    SELECT TOP (5) SEMPLEADO, SUM(NARE_MIN_TARDANZA) AS NMINUTOS
    FROM #reg
    WHERE NARE_MIN_TARDANZA > 0
    GROUP BY CPEL_ID_PERSONAL, SEMPLEADO
    ORDER BY NMINUTOS DESC;

    -- 4
    SELECT TOP (5) SEMPLEADO, COUNT(*) AS NFALTAS
    FROM #reg
    WHERE SASI_VISTA = 'FALTA_INJUSTIFICADA'
    GROUP BY CPEL_ID_PERSONAL, SEMPLEADO
    ORDER BY NFALTAS DESC;
END
GO

-- Catálogo de tipos de asistencia (selects, chips y leyendas del front)
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_TIPO_ASISTENCIA
    @i_ESTADO CHAR(1) = 'V'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CASI_ID_ASISTENCIA, SASI_NOMBRE, SASI_ABREVIATURA, SASI_VISTA, SASI_COLOR, FASI_DESCUENTA, FASI_ESTADO
    FROM dbo.TMKK_ASISTENCIA
    WHERE NULLIF(@i_ESTADO, '') IS NULL OR FASI_ESTADO = @i_ESTADO
    ORDER BY CASI_ID_ASISTENCIA;
END
GO
