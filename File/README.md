SELECT d.ID,
       d.KittingListID,
       '[' + d.Material + ']'  AS Material,   -- ngoặc vuông để lộ khoảng trắng thừa
       LEN(d.Material)         AS LenMaterial,
       d.Quantity,
       d.QuantityReplace,
       d.MaterialReplace,
       d.PickedQuantity,
       d.KittingStatus,
       k.Plant,
       d.Sloc,
       '[' + d.LocationName + ']' AS LocationName,
       k.KittingType,
       k.Deliverydate
FROM tblKittingListDetail d
JOIN tblKittingList k ON k.ID = d.KittingListID
WHERE d.Material LIKE '%ZM5PCA450BUVK108R%'
  AND k.KittingType = 5          -- PMD
ORDER BY k.Deliverydate, d.ID;
