SELECT ReceivingCardID, Barcode, ReceivingCardDate, ReceivingCardTime, PlanOrderNumber,
       CreatedDate, CreatedBy, Status
FROM tblReceivingCard WITH (NOLOCK)
WHERE ReceivingType = 2
  AND Material = 'PNBC1711ZA1/AS'
  AND PlanOrderNumber LIKE '%2026112701%'
ORDER BY CreatedDate DESC;
