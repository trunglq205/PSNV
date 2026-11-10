-- Chạy từng cái, xem cái nào chậm
EXEC GetRCByStoreByMaterial 'ZM2NS221W276-H'
EXEC GetQtyStoredByMaterial 'ZM2NS221W276-H'
EXEC GetKittingListDetailById <id>
EXEC GetReceivingCardByMaterial 'ZM2NS221W276-H', 1
EXEC GetTypeFrequencyByKey 'ZM2NS221W276-H', 'VR01', '<sloc>'
EXEC GetQMByKT 'ZM2NS221W276-H', 'VR01'
EXEC GetPOSMCSByRCID <rcid>
