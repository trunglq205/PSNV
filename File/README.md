SELECT ID, KittingListID, '[' + Material + ']' AS Material, Quantity, QuantityReplace,
       MaterialReplace, PickedQuantity, KittingStatus, Plant, Sloc, LocationName
FROM KittingListDetails
WHERE Material LIKE '%ZM5PCA450BUVK108R%' AND KittingType = 5;
