EXEC sp_helptext 'SearchBackFlush';
EXEC sp_helptext 'ConfirmBackFlush';

EXEC SearchBackFlush @date = '2026-11-27', @PlanOrderNumber = '', @Material = 'PNBC1711ZA1/AS',
     @Plant = '', @Sloc = '', @ProductionVersion = '', @Status = NULL,
     @PageNumber = 1, @PageSize = 1000;
