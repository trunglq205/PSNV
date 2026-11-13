USE [CrtiticalListDB]
GO
/****** Object:  StoredProcedure [dbo].[sp_UpdateInboundFromZMV029]    Script Date: 11/13/2026 2:26:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_UpdateInboundFromZMV029]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @DataSource TINYINT = 0;

    BEGIN TRY
        BEGIN TRAN;

        -- Xóa toàn bộ LA của Material+Plant có trong ZMV029_STG
		DELETE FROM ZFMA0037_WORK 
		WHERE Elm = 'LA' 
		  AND DataSource = @DataSource
		  AND EXISTS (
			  SELECT 1 FROM ZMV029_STG z
			  WHERE z.Plant = ZFMA0037_WORK.Plant
				AND z.Material = ZFMA0037_WORK.Material
		  );

		-- Insert lại từ ZMV029_STG
		INSERT INTO ZFMA0037_WORK (Plant, Material, ETA_PSNV, Elm, InboundQty, DataSource)
		SELECT 
			Plant,
			Material,
			CONVERT(NVARCHAR(20), DelivDate, 23) AS ETA_PSNV,
			'LA',
			InboundQty,
			@DataSource
		FROM ZMV029_STG
		WHERE Plant IS NOT NULL 
		  AND Material IS NOT NULL 
		  AND InboundQty <> 0;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('sp_UpdateInboundFromZMV029 failed: %s', 16, 1, @ErrMsg);
    END CATCH
END
