### DB=SWMS_FINISH_GOODS_DEV | SERVER=PCV-S-WEBTEMP2\MSSQLSERVER1 | LUC=2026-11-18 13:46:59
### VERSION=15.0.2000.5
 
line
----------------------------------------------------------------------------------------------------------------------------------
S|dbo
S|master
S|wms

line
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
T|master.api_keys
C|master.api_keys|id|bigint|NOT NULL|IDENTITY||#1
C|master.api_keys|client_name|nvarchar(100)|NOT NULL|||#2
C|master.api_keys|key_prefix|char(12)|NOT NULL|||#3
C|master.api_keys|key_hash|nvarchar(256)|NOT NULL|||#4
C|master.api_keys|permissions_csv|nvarchar(2000)|NOT NULL||('')|#5
C|master.api_keys|is_active|bit|NOT NULL||((1))|#6
C|master.api_keys|expires_at|datetime2(7)|NULL|||#7
C|master.api_keys|last_used_at|datetime2(7)|NULL|||#8
C|master.api_keys|revoked_at|datetime2(7)|NULL|||#9
C|master.api_keys|is_deleted|bit|NOT NULL||((0))|#10
C|master.api_keys|created_at|datetime2(7)|NOT NULL||(sysutcdatetime())|#11
C|master.api_keys|created_by|nvarchar(100)|NULL|||#12
C|master.api_keys|updated_at|datetime2(7)|NULL|||#13
C|master.api_keys|updated_by|nvarchar(100)|NULL|||#14
T|master.categories
C|master.categories|code|int|NOT NULL|||#1
C|master.categories|name|nvarchar(100)|NOT NULL|||#2
C|master.categories|description|nvarchar(255)|NULL|||#3
C|master.categories|bd|nvarchar(20)|NULL|||#4
C|master.categories|plant_code|nvarchar(20)|NULL|||#5
C|master.categories|product|nvarchar(20)|NULL|||#6
C|master.categories|slock_pmd|nvarchar(20)|NULL|||#7
C|master.categories|slock_fa|nvarchar(20)|NULL|||#8
C|master.categories|slock_scs|nvarchar(20)|NULL|||#9
C|master.categories|slock_jpt|nvarchar(20)|NULL|||#10
C|master.categories|slock_port|nvarchar(20)|NULL|||#11
C|master.categories|is_deleted|bit|NOT NULL||((0))|#12
C|master.categories|created_at|datetime|NOT NULL||(getdate())|#13
C|master.categories|created_by|nvarchar(50)|NULL|||#14
C|master.categories|updated_at|datetime|NULL|||#15
C|master.categories|updated_by|nvarchar(50)|NULL|||#16
C|master.categories|production_version|varchar(20)|NULL|||#17
T|master.configs
C|master.configs|id|bigint|NOT NULL|IDENTITY||#1
C|master.configs|config_key|varchar(100)|NOT NULL|||#2
C|master.configs|config_value|nvarchar(max)|NULL|||#3
C|master.configs|description|nvarchar(500)|NULL|||#4
C|master.configs|is_deleted|bit|NOT NULL||((0))|#5
C|master.configs|created_at|datetime2(7)|NOT NULL||(sysdatetime())|#6
C|master.configs|created_by|nvarchar(100)|NULL|||#7
C|master.configs|updated_at|datetime2(7)|NULL|||#8
C|master.configs|updated_by|nvarchar(100)|NULL|||#9
T|master.email_config
C|master.email_config|id|bigint|NOT NULL|IDENTITY||#1
C|master.email_config|event_code|nvarchar(40)|NOT NULL|||#2
C|master.email_config|department|nvarchar(10)|NULL|||#3
C|master.email_config|sub_code|nvarchar(30)|NULL|||#4
C|master.email_config|category|nvarchar(20)|NULL|||#5
C|master.email_config|model|nvarchar(50)|NULL|||#6
C|master.email_config|area_code|nvarchar(50)|NULL|||#7
C|master.email_config|recipient_type|nvarchar(3)|NOT NULL||(N'TO')|#8
C|master.email_config|user_id|bigint|NULL|||#9
C|master.email_config|email|nvarchar(200)|NULL|||#10
C|master.email_config|display_name|nvarchar(200)|NULL|||#11
C|master.email_config|is_active|bit|NOT NULL||((1))|#12
C|master.email_config|is_deleted|bit|NOT NULL||((0))|#13
C|master.email_config|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#14
C|master.email_config|created_by|nvarchar(100)|NULL|||#15
C|master.email_config|updated_at|datetime2(0)|NULL|||#16
C|master.email_config|updated_by|nvarchar(100)|NULL|||#17
T|master.email_event_subtypes
C|master.email_event_subtypes|event_code|nvarchar(40)|NOT NULL|||#1
C|master.email_event_subtypes|sub_code|nvarchar(30)|NOT NULL|||#2
C|master.email_event_subtypes|name_key|nvarchar(100)|NOT NULL|||#3
C|master.email_event_subtypes|severity|nvarchar(10)|NOT NULL||(N'info')|#4
C|master.email_event_subtypes|sort_order|int|NOT NULL||((0))|#5
C|master.email_event_subtypes|is_active|bit|NOT NULL||((1))|#6
T|master.email_events
C|master.email_events|code|nvarchar(40)|NOT NULL|||#1
C|master.email_events|module|nvarchar(20)|NOT NULL|||#2
C|master.email_events|name_key|nvarchar(100)|NOT NULL|||#3
C|master.email_events|description|nvarchar(500)|NULL|||#4
C|master.email_events|subject_template|nvarchar(300)|NULL|||#5
C|master.email_events|ref_type|nvarchar(30)|NULL|||#6
C|master.email_events|sort_order|int|NOT NULL||((0))|#7
C|master.email_events|is_active|bit|NOT NULL||((1))|#8
C|master.email_events|body_template|nvarchar(max)|NULL|||#9
C|master.email_events|updated_at|datetime2(0)|NULL|||#10
C|master.email_events|updated_by|nvarchar(100)|NULL|||#11
T|master.locator_map
C|master.locator_map|id|bigint|NOT NULL|IDENTITY||#1
C|master.locator_map|parent_type|nvarchar(20)|NOT NULL|||#2
C|master.locator_map|parent_id|bigint|NOT NULL|||#3
C|master.locator_map|target_type|nvarchar(20)|NOT NULL|||#4
C|master.locator_map|locator_id|bigint|NULL|||#5
C|master.locator_map|rack_id|bigint|NULL|||#6
C|master.locator_map|grid_x|int|NOT NULL|||#7
C|master.locator_map|grid_y|int|NOT NULL|||#8
C|master.locator_map|grid_w|int|NOT NULL||((1))|#9
C|master.locator_map|grid_h|int|NOT NULL||((1))|#10
C|master.locator_map|arrow|nvarchar(20)|NULL|||#11
C|master.locator_map|color|nvarchar(40)|NULL|||#12
C|master.locator_map|label|nvarchar(400)|NULL|||#13
C|master.locator_map|sort_order|int|NOT NULL||((0))|#14
C|master.locator_map|is_active|bit|NOT NULL||((1))|#15
C|master.locator_map|is_deleted|bit|NOT NULL||((0))|#16
C|master.locator_map|created_at|datetime2(7)|NOT NULL||(sysutcdatetime())|#17
C|master.locator_map|created_by|nvarchar(100)|NULL|||#18
C|master.locator_map|updated_at|datetime2(7)|NULL|||#19
C|master.locator_map|updated_by|nvarchar(100)|NULL|||#20
T|master.locators
C|master.locators|id|bigint|NOT NULL|IDENTITY||#1
C|master.locators|locator_code|nvarchar(100)|NOT NULL|||#2
C|master.locators|area_id|bigint|NULL|||#5
C|master.locators|rack_id|bigint|NULL|||#6
C|master.locators|rack_row|int|NULL|||#7
C|master.locators|rack_col|int|NULL|||#8
C|master.locators|rack_level|nvarchar(10)|NULL|||#9
C|master.locators|current_status|nvarchar(40)|NOT NULL||(N'empty')|#10
C|master.locators|status_updated_at|datetime2(7)|NULL|||#11
C|master.locators|status_updated_by|nvarchar(100)|NULL|||#12
C|master.locators|sort_order|int|NOT NULL||((0))|#13
C|master.locators|is_active|bit|NOT NULL||((1))|#14
C|master.locators|is_deleted|bit|NOT NULL||((0))|#15
C|master.locators|created_at|datetime2(7)|NOT NULL||(sysutcdatetime())|#16
C|master.locators|created_by|nvarchar(100)|NULL|||#17
C|master.locators|updated_at|datetime2(7)|NULL|||#18
C|master.locators|updated_by|nvarchar(100)|NULL|||#19
C|master.locators|slot_kind|nvarchar(20)|NULL|||#20
T|master.models
C|master.models|id|bigint|NOT NULL|IDENTITY||#1
C|master.models|code|nvarchar(100)|NOT NULL|||#2
C|master.models|category_id|int|NULL|||#3
C|master.models|length|int|NOT NULL|||#4
C|master.models|width|int|NOT NULL|||#5
C|master.models|height|int|NOT NULL|||#6
C|master.models|standard_packing|int|NOT NULL|||#8
C|master.models|is_active|bit|NOT NULL||((1))|#9
C|master.models|is_deleted|bit|NOT NULL||((0))|#10
C|master.models|created_at|datetime2(7)|NOT NULL||(sysutcdatetime())|#11
C|master.models|created_by|nvarchar(200)|NULL|||#12
C|master.models|updated_at|datetime2(7)|NULL|||#13
C|master.models|updated_by|nvarchar(200)|NULL|||#14
C|master.models|gtin|varchar(14)|NULL|||#15
C|master.models|suggest_area|bigint|NULL|||#17
C|master.models|suggest_rack_row|varchar(20)|NULL|||#18
C|master.models|layer_limit|int|NULL|||#19
C|master.models|layer_count|int|NULL|||#20
C|master.models|stacking_length|int|NULL|||#21
C|master.models|stacking_width|int|NULL|||#22
C|master.models|origin|char(2)|NULL|||#23
C|master.models|weight|decimal(9,3)|NULL|||#24
T|master.models_bak_20261012
C|master.models_bak_20261012|id|bigint|NOT NULL|IDENTITY||#1
C|master.models_bak_20261012|code|nvarchar(100)|NOT NULL|||#2
C|master.models_bak_20261012|category_id|int|NULL|||#3
C|master.models_bak_20261012|length|int|NOT NULL|||#4
C|master.models_bak_20261012|width|int|NOT NULL|||#5
C|master.models_bak_20261012|height|int|NOT NULL|||#6
C|master.models_bak_20261012|standard_packing|int|NOT NULL|||#7
C|master.models_bak_20261012|is_active|bit|NOT NULL|||#8
C|master.models_bak_20261012|is_deleted|bit|NOT NULL|||#9
C|master.models_bak_20261012|created_at|datetime2(7)|NOT NULL|||#10
C|master.models_bak_20261012|created_by|nvarchar(200)|NULL|||#11
C|master.models_bak_20261012|updated_at|datetime2(7)|NULL|||#12
C|master.models_bak_20261012|updated_by|nvarchar(200)|NULL|||#13
C|master.models_bak_20261012|gtin|varchar(14)|NULL|||#14
C|master.models_bak_20261012|suggest_area|bigint|NULL|||#15
C|master.models_bak_20261012|suggest_rack_row|varchar(20)|NULL|||#16
C|master.models_bak_20261012|layer_limit|int|NULL|||#17
C|master.models_bak_20261012|layer_count|int|NULL|||#18
C|master.models_bak_20261012|stacking_length|int|NULL|||#19
C|master.models_bak_20261012|stacking_width|int|NULL|||#20
C|master.models_bak_20261012|origin|char(2)|NULL|||#21
T|master.pda_app_versions
C|master.pda_app_versions|id|bigint|NOT NULL|IDENTITY||#1
C|master.pda_app_versions|version|nvarchar(50)|NOT NULL|||#2
C|master.pda_app_versions|version_code|int|NOT NULL|||#3
C|master.pda_app_versions|release_note|nvarchar(1000)|NOT NULL||(N'')|#4
C|master.pda_app_versions|apk_path|nvarchar(500)|NOT NULL|||#5
C|master.pda_app_versions|apk_url|nvarchar(500)|NOT NULL|||#6
C|master.pda_app_versions|size_bytes|bigint|NOT NULL|||#7
C|master.pda_app_versions|force_update|bit|NOT NULL||((0))|#8
C|master.pda_app_versions|is_current|bit|NOT NULL||((0))|#9
C|master.pda_app_versions|published_at|datetime2(3)|NOT NULL|||#10
C|master.pda_app_versions|created_at|datetime2(3)|NOT NULL||(sysutcdatetime())|#11
C|master.pda_app_versions|created_by|nvarchar(100)|NULL|||#12
C|master.pda_app_versions|updated_at|datetime2(3)|NULL|||#13
C|master.pda_app_versions|updated_by|nvarchar(100)|NULL|||#14
C|master.pda_app_versions|is_deleted|bit|NOT NULL||((0))|#15
T|master.permission_modules
C|master.permission_modules|id|bigint|NOT NULL|IDENTITY||#1
C|master.permission_modules|code|nvarchar(50)|NOT NULL|||#2
C|master.permission_modules|sort_order|int|NOT NULL||((0))|#3
C|master.permission_modules|is_deleted|bit|NOT NULL||((0))|#4
C|master.permission_modules|created_at|datetime|NOT NULL||(sysutcdatetime())|#5
C|master.permission_modules|created_by|nvarchar(200)|NULL|||#6
C|master.permission_modules|updated_at|datetime|NULL|||#7
C|master.permission_modules|updated_by|nvarchar(200)|NULL|||#8
T|master.permission_screens
C|master.permission_screens|id|bigint|NOT NULL|IDENTITY||#1
C|master.permission_screens|module_id|bigint|NOT NULL|||#2
C|master.permission_screens|code|nvarchar(50)|NOT NULL|||#3
C|master.permission_screens|sort_order|int|NOT NULL||((0))|#4
C|master.permission_screens|is_deleted|bit|NOT NULL||((0))|#5
C|master.permission_screens|created_at|datetime|NOT NULL||(sysutcdatetime())|#6
C|master.permission_screens|created_by|nvarchar(200)|NULL|||#7
C|master.permission_screens|updated_at|datetime|NULL|||#8
C|master.permission_screens|updated_by|nvarchar(200)|NULL|||#9
T|master.permissions
C|master.permissions|id|bigint|NOT NULL|IDENTITY||#1
C|master.permissions|screen_id|bigint|NOT NULL|||#2
C|master.permissions|action|nvarchar(50)|NOT NULL|||#3
C|master.permissions|code|nvarchar(100)|NOT NULL|||#4
C|master.permissions|sort_order|int|NOT NULL||((0))|#5
C|master.permissions|is_deleted|bit|NOT NULL||((0))|#6
C|master.permissions|created_at|datetime|NOT NULL||(sysutcdatetime())|#7
C|master.permissions|created_by|nvarchar(200)|NULL|||#8
C|master.permissions|updated_at|datetime|NULL|||#9
C|master.permissions|updated_by|nvarchar(200)|NULL|||#10
T|master.racks
C|master.racks|id|bigint|NOT NULL|IDENTITY||#1
C|master.racks|rack_code|nvarchar(100)|NOT NULL|||#2
C|master.racks|rack_name|nvarchar(400)|NOT NULL|||#3
C|master.racks|area_id|bigint|NOT NULL|||#4
C|master.racks|rows|int|NOT NULL|||#5
C|master.racks|cols|int|NOT NULL|||#6
C|master.racks|sort_order|int|NOT NULL||((0))|#7
C|master.racks|is_active|bit|NOT NULL||((1))|#8
C|master.racks|is_deleted|bit|NOT NULL||((0))|#9
C|master.racks|created_at|datetime2(7)|NOT NULL||(sysutcdatetime())|#10
C|master.racks|created_by|nvarchar(100)|NULL|||#11
C|master.racks|updated_at|datetime2(7)|NULL|||#12
C|master.racks|updated_by|nvarchar(100)|NULL|||#13
T|master.role_permissions
C|master.role_permissions|id|bigint|NOT NULL|IDENTITY||#1
C|master.role_permissions|role_id|bigint|NOT NULL|||#2
C|master.role_permissions|permission_id|bigint|NOT NULL|||#3
C|master.role_permissions|created_at|datetime|NOT NULL||(sysutcdatetime())|#4
C|master.role_permissions|created_by|nvarchar(200)|NULL|||#5
T|master.roles
C|master.roles|id|bigint|NOT NULL|IDENTITY||#1
C|master.roles|code|nvarchar(50)|NOT NULL|||#2
C|master.roles|name|nvarchar(200)|NOT NULL|||#3
C|master.roles|description|nvarchar(500)|NULL|||#4
C|master.roles|dot|nvarchar(20)|NOT NULL||('info')|#5
C|master.roles|is_system|bit|NOT NULL||((0))|#6
C|master.roles|is_deleted|bit|NOT NULL||((0))|#7
C|master.roles|created_at|datetime|NOT NULL||(sysutcdatetime())|#8
C|master.roles|created_by|nvarchar(200)|NULL|||#9
C|master.roles|updated_at|datetime|NULL|||#10
C|master.roles|updated_by|nvarchar(200)|NULL|||#11
T|master.shortage_reasons
C|master.shortage_reasons|code|nvarchar(20)|NOT NULL|||#1
C|master.shortage_reasons|name_key|nvarchar(100)|NOT NULL|||#2
C|master.shortage_reasons|department|nvarchar(10)|NOT NULL|||#3
C|master.shortage_reasons|color_token|nvarchar(20)|NOT NULL|||#4
C|master.shortage_reasons|lead_time_minutes|int|NOT NULL|||#5
C|master.shortage_reasons|is_plan_only|bit|NOT NULL|||#6
C|master.shortage_reasons|sort_order|int|NOT NULL|||#7
C|master.shortage_reasons|is_active|bit|NOT NULL||((1))|#8
T|master.stock_event_types
C|master.stock_event_types|id|int|NOT NULL|IDENTITY||#1
C|master.stock_event_types|code|varchar(40)|NOT NULL|||#2
C|master.stock_event_types|name_key|nvarchar(100)|NOT NULL|||#3
C|master.stock_event_types|subject_type|varchar(10)|NOT NULL|||#4
C|master.stock_event_types|group_code|varchar(20)|NOT NULL|||#5
C|master.stock_event_types|color_token|varchar(20)|NOT NULL|||#6
C|master.stock_event_types|icon|varchar(40)|NULL|||#7
C|master.stock_event_types|sort_order|int|NOT NULL||((0))|#8
C|master.stock_event_types|is_active|bit|NOT NULL||((1))|#9
T|master.user_roles
C|master.user_roles|id|bigint|NOT NULL|IDENTITY||#1
C|master.user_roles|user_id|bigint|NOT NULL|||#2
C|master.user_roles|role_id|bigint|NOT NULL|||#3
C|master.user_roles|created_at|datetime|NOT NULL||(sysutcdatetime())|#4
C|master.user_roles|created_by|nvarchar(200)|NULL|||#5
T|master.users
C|master.users|id|bigint|NOT NULL|IDENTITY||#1
C|master.users|full_name|nvarchar(200)|NOT NULL|||#2
C|master.users|email|nvarchar(200)|NULL|||#3
C|master.users|department|nvarchar(50)|NOT NULL|||#4
C|master.users|employee_code|nvarchar(50)|NOT NULL|||#5
C|master.users|password_hash|nvarchar(256)|NOT NULL|||#6
C|master.users|is_active|bit|NOT NULL||((1))|#7
C|master.users|is_deleted|bit|NOT NULL||((0))|#8
C|master.users|last_login_at|datetime2(7)|NULL|||#9
C|master.users|created_at|datetime2(7)|NOT NULL||(sysutcdatetime())|#10
C|master.users|created_by|nvarchar(50)|NULL|||#11
C|master.users|updated_at|datetime2(7)|NULL|||#12
C|master.users|updated_by|nvarchar(50)|NULL|||#13
T|master.warehouse_areas
C|master.warehouse_areas|id|bigint|NOT NULL|IDENTITY||#1
C|master.warehouse_areas|area_code|nvarchar(50)|NOT NULL|||#2
C|master.warehouse_areas|area_name|nvarchar(200)|NOT NULL|||#3
C|master.warehouse_areas|cols|int|NOT NULL|||#4
C|master.warehouse_areas|rows|int|NOT NULL|||#5
C|master.warehouse_areas|cell_meters|decimal(5,3)|NOT NULL||((0.2))|#6
C|master.warehouse_areas|is_active|bit|NOT NULL||((1))|#7
C|master.warehouse_areas|is_deleted|bit|NOT NULL||((0))|#8
C|master.warehouse_areas|created_at|datetime2(7)|NOT NULL||(sysutcdatetime())|#9
C|master.warehouse_areas|created_by|nvarchar(50)|NULL|||#10
C|master.warehouse_areas|updated_at|datetime2(7)|NULL|||#11
C|master.warehouse_areas|updated_by|nvarchar(50)|NULL|||#12
C|master.warehouse_areas|warehouse_id|bigint|NULL|||#13
C|master.warehouse_areas|map_type|nvarchar(20)|NOT NULL||(N'storing')|#14
T|master.warehouses
C|master.warehouses|id|bigint|NOT NULL|IDENTITY||#1
C|master.warehouses|code|nvarchar(50)|NOT NULL|||#2
C|master.warehouses|name|nvarchar(200)|NOT NULL|||#3
C|master.warehouses|address|nvarchar(500)|NULL|||#4
C|master.warehouses|is_active|bit|NOT NULL||((1))|#5
C|master.warehouses|created_at|datetime2(7)|NOT NULL||(getdate())|#6
C|master.warehouses|created_by|bigint|NULL|||#7
C|master.warehouses|updated_at|datetime2(7)|NOT NULL||(getdate())|#8
C|master.warehouses|updated_by|bigint|NULL|||#9
C|master.warehouses|is_deleted|bit|NOT NULL||((0))|#10
T|wms.balance_docs
C|wms.balance_docs|id|bigint|NOT NULL|IDENTITY||#1
C|wms.balance_docs|doc_no|nvarchar(50)|NOT NULL|||#2
C|wms.balance_docs|count_id|bigint|NOT NULL|||#3
C|wms.balance_docs|doc_status|nvarchar(20)|NOT NULL|||#4
C|wms.balance_docs|fa_ref|nvarchar(50)|NULL|||#5
C|wms.balance_docs|issued_at|datetime2(3)|NULL|||#6
C|wms.balance_docs|issued_by|nvarchar(200)|NULL|||#7
C|wms.balance_docs|created_at|datetime2(3)|NOT NULL||(sysdatetime())|#8
C|wms.balance_docs|created_by|nvarchar(200)|NULL|||#9
C|wms.balance_docs|updated_at|datetime2(3)|NULL|||#10
C|wms.balance_docs|updated_by|nvarchar(200)|NULL|||#11
C|wms.balance_docs|is_deleted|bit|NOT NULL||((0))|#12
T|wms.box_lines
C|wms.box_lines|id|bigint|NOT NULL|IDENTITY||#1
C|wms.box_lines|box_id|bigint|NOT NULL|||#2
C|wms.box_lines|qty|int|NOT NULL|||#3
C|wms.box_lines|serial_no|nvarchar(50)|NULL|||#4
C|wms.box_lines|production_date|date|NULL|||#5
C|wms.box_lines|carton_qty|int|NULL|||#6
C|wms.box_lines|is_deleted|bit|NOT NULL||((0))|#7
C|wms.box_lines|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#8
C|wms.box_lines|created_by|nvarchar(50)|NULL|||#9
C|wms.box_lines|updated_at|datetime2(0)|NULL|||#10
C|wms.box_lines|updated_by|nvarchar(50)|NULL|||#11
C|wms.box_lines|model|nvarchar(50)|NOT NULL||('')|#12
T|wms.boxes
C|wms.boxes|id|bigint|NOT NULL|IDENTITY||#1
C|wms.boxes|lot_id|bigint|NOT NULL|||#2
C|wms.boxes|box_no|nvarchar(50)|NOT NULL|||#3
C|wms.boxes|psnv_po|nvarchar(50)|NULL|||#4
C|wms.boxes|customer_po|nvarchar(50)|NULL|||#5
C|wms.boxes|production_date|date|NULL|||#6
C|wms.boxes|raw_payload|nvarchar(2000)|NULL|||#7
C|wms.boxes|is_deleted|bit|NOT NULL||((0))|#8
C|wms.boxes|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#9
C|wms.boxes|created_by|nvarchar(50)|NULL|||#10
C|wms.boxes|updated_at|datetime2(0)|NULL|||#11
C|wms.boxes|updated_by|nvarchar(50)|NULL|||#12
C|wms.boxes|oqc_status|tinyint|NULL|||#13
C|wms.boxes|line|nvarchar(20)|NULL|||#14
C|wms.boxes|lot_name|nvarchar(50)|NULL|||#15
C|wms.boxes|model|nvarchar(50)|NULL|||#16
C|wms.boxes|raw_payload_hash|binary(32)|NULL|COMPUTED||#17
C|wms.boxes|weight|decimal(9,3)|NULL|||#18
T|wms.inventory_count_lines
C|wms.inventory_count_lines|id|bigint|NOT NULL|IDENTITY||#1
C|wms.inventory_count_lines|count_id|bigint|NOT NULL|||#2
C|wms.inventory_count_lines|line_no|int|NOT NULL|||#3
C|wms.inventory_count_lines|product_id|bigint|NULL|||#4
C|wms.inventory_count_lines|locator_id|bigint|NOT NULL|||#5
C|wms.inventory_count_lines|lot_id|bigint|NULL|||#6
C|wms.inventory_count_lines|qty_system|int|NOT NULL||((0))|#7
C|wms.inventory_count_lines|qty_count|int|NULL|||#8
C|wms.inventory_count_lines|is_adjusted|bit|NOT NULL||((0))|#10
C|wms.inventory_count_lines|note|nvarchar(500)|NULL|||#11
C|wms.inventory_count_lines|created_at|datetime2(7)|NOT NULL||(getdate())|#12
C|wms.inventory_count_lines|created_by|bigint|NULL|||#13
C|wms.inventory_count_lines|updated_at|datetime2(7)|NOT NULL||(getdate())|#14
C|wms.inventory_count_lines|updated_by|bigint|NULL|||#15
C|wms.inventory_count_lines|is_deleted|bit|NOT NULL||((0))|#16
C|wms.inventory_count_lines|qty_diff|int|NULL|COMPUTED||#17
C|wms.inventory_count_lines|resolution|nvarchar(20)|NULL|||#18
C|wms.inventory_count_lines|is_found|bit|NOT NULL||((0))|#19
C|wms.inventory_count_lines|system_locator_id|bigint|NULL|||#20
C|wms.inventory_count_lines|box_count_system|int|NULL|||#21
C|wms.inventory_count_lines|box_count_counted|int|NULL|||#22
C|wms.inventory_count_lines|standard_packing|int|NULL|||#23
T|wms.inventory_counts
C|wms.inventory_counts|id|bigint|NOT NULL|IDENTITY||#1
C|wms.inventory_counts|doc_no|nvarchar(50)|NOT NULL|||#2
C|wms.inventory_counts|warehouse_id|bigint|NOT NULL|||#3
C|wms.inventory_counts|count_date|date|NOT NULL|||#4
C|wms.inventory_counts|doc_status|nvarchar(20)|NOT NULL||('draft')|#5
C|wms.inventory_counts|description|nvarchar(max)|NULL|||#6
C|wms.inventory_counts|created_at|datetime2(7)|NOT NULL||(getdate())|#7
C|wms.inventory_counts|created_by|bigint|NULL|||#8
C|wms.inventory_counts|updated_at|datetime2(7)|NOT NULL||(getdate())|#9
C|wms.inventory_counts|updated_by|bigint|NULL|||#10
C|wms.inventory_counts|confirmed_at|datetime2(7)|NULL|||#11
C|wms.inventory_counts|confirmed_by|bigint|NULL|||#12
C|wms.inventory_counts|is_deleted|bit|NOT NULL||((0))|#13
C|wms.inventory_counts|count_type|nvarchar(20)|NULL|||#14
C|wms.inventory_counts|source_ref|nvarchar(50)|NULL|||#15
T|wms.inventory_move_lines
C|wms.inventory_move_lines|id|bigint|NOT NULL|IDENTITY||#1
C|wms.inventory_move_lines|move_id|bigint|NOT NULL|||#2
C|wms.inventory_move_lines|line_no|int|NOT NULL|||#3
C|wms.inventory_move_lines|product_id|bigint|NOT NULL|||#4
C|wms.inventory_move_lines|lot_id|bigint|NULL|||#5
C|wms.inventory_move_lines|from_locator_id|bigint|NOT NULL|||#6
C|wms.inventory_move_lines|to_locator_id|bigint|NOT NULL|||#7
C|wms.inventory_move_lines|qty|decimal(18,4)|NOT NULL|||#8
C|wms.inventory_move_lines|note|nvarchar(500)|NULL|||#9
C|wms.inventory_move_lines|created_at|datetime2(7)|NOT NULL||(getdate())|#10
C|wms.inventory_move_lines|created_by|bigint|NULL|||#11
C|wms.inventory_move_lines|updated_at|datetime2(7)|NOT NULL||(getdate())|#12
C|wms.inventory_move_lines|updated_by|bigint|NULL|||#13
C|wms.inventory_move_lines|is_deleted|bit|NOT NULL||((0))|#14
T|wms.inventory_moves
C|wms.inventory_moves|id|bigint|NOT NULL|IDENTITY||#1
C|wms.inventory_moves|doc_no|nvarchar(50)|NOT NULL|||#2
C|wms.inventory_moves|move_date|date|NOT NULL|||#3
C|wms.inventory_moves|move_type|nvarchar(50)|NOT NULL||('internal')|#4
C|wms.inventory_moves|doc_status|nvarchar(20)|NOT NULL||('draft')|#5
C|wms.inventory_moves|description|nvarchar(max)|NULL|||#6
C|wms.inventory_moves|created_at|datetime2(7)|NOT NULL||(getdate())|#7
C|wms.inventory_moves|created_by|bigint|NULL|||#8
C|wms.inventory_moves|updated_at|datetime2(7)|NOT NULL||(getdate())|#9
C|wms.inventory_moves|updated_by|bigint|NULL|||#10
C|wms.inventory_moves|confirmed_at|datetime2(7)|NULL|||#11
C|wms.inventory_moves|confirmed_by|bigint|NULL|||#12
C|wms.inventory_moves|is_deleted|bit|NOT NULL||((0))|#13
T|wms.pallets
C|wms.pallets|id|bigint|NOT NULL|IDENTITY||#1
C|wms.pallets|pallet_id|char(12)|NOT NULL|||#2
C|wms.pallets|category_id|int|NULL|||#3
C|wms.pallets|lot_type|nvarchar(20)|NOT NULL|||#4
C|wms.pallets|locator_id|bigint|NULL|||#5
C|wms.pallets|detail_level|nvarchar(20)|NOT NULL|||#6
C|wms.pallets|box_count|int|NULL|||#7
C|wms.pallets|inspection_status|nvarchar(20)|NOT NULL||('not_required')|#8
C|wms.pallets|is_urgent|bit|NOT NULL||((0))|#9
C|wms.pallets|production_date|date|NULL|||#10
C|wms.pallets|is_deleted|bit|NOT NULL||((0))|#11
C|wms.pallets|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#12
C|wms.pallets|created_by|nvarchar(50)|NULL|||#13
C|wms.pallets|updated_at|datetime2(0)|NULL|||#14
C|wms.pallets|updated_by|nvarchar(50)|NULL|||#15
C|wms.pallets|model|nvarchar(50)|NULL|||#16
C|wms.pallets|stocky_code|nvarchar(50)|NULL|||#17
C|wms.pallets|even_lot|bit|NULL|||#18
C|wms.pallets|sap_status|tinyint|NOT NULL||((0))|#19
C|wms.pallets|sap_pushed_at|datetime2(3)|NULL|||#20
C|wms.pallets|disposition|nvarchar(20)|NULL|||#21
C|wms.pallets|stop_shipment|bit|NOT NULL||((0))|#22
C|wms.pallets|standard_packing|int|NULL|||#23
C|wms.pallets|si_no|nvarchar(20)|NULL|||#24
T|wms.part_card_lineage
C|wms.part_card_lineage|id|bigint|NOT NULL|IDENTITY||#1
C|wms.part_card_lineage|part_card_id|bigint|NOT NULL|||#2
C|wms.part_card_lineage|source_part_card_id|bigint|NOT NULL|||#3
C|wms.part_card_lineage|source_payload|varchar(500)|NULL|||#4
C|wms.part_card_lineage|action|varchar(10)|NOT NULL|||#5
C|wms.part_card_lineage|created_at|datetime2(7)|NOT NULL||(sysutcdatetime())|#6
C|wms.part_card_lineage|created_by|nvarchar(200)|NULL|||#7
T|wms.part_card_rows
C|wms.part_card_rows|id|bigint|NOT NULL|IDENTITY||#1
C|wms.part_card_rows|part_card_id|bigint|NOT NULL|||#2
C|wms.part_card_rows|line_no|int|NOT NULL|||#3
C|wms.part_card_rows|g21_part|nvarchar(200)|NULL|||#4
C|wms.part_card_rows|model|nvarchar(200)|NOT NULL|||#5
C|wms.part_card_rows|inner_box|nvarchar(100)|NULL|||#6
C|wms.part_card_rows|qty|int|NOT NULL||((0))|#7
C|wms.part_card_rows|origin|nvarchar(100)|NULL|||#8
C|wms.part_card_rows|oqc_checked|bit|NOT NULL||((0))|#9
C|wms.part_card_rows|inner_length|decimal(18,4)|NULL|||#10
C|wms.part_card_rows|inner_width|decimal(18,4)|NULL|||#11
C|wms.part_card_rows|inner_height|decimal(18,4)|NULL|||#12
C|wms.part_card_rows|inner_weight|decimal(18,4)|NULL|||#13
T|wms.part_cards
C|wms.part_cards|id|bigint|NOT NULL|IDENTITY||#1
C|wms.part_cards|po_no|nvarchar(100)|NULL|||#2
C|wms.part_cards|customer_po_no|nvarchar(100)|NULL|||#3
C|wms.part_cards|production_date|date|NOT NULL|||#4
C|wms.part_cards|packer|nvarchar(100)|NULL|||#5
C|wms.part_cards|checker|nvarchar(100)|NULL|||#6
C|wms.part_cards|length|decimal(18,4)|NULL|||#7
C|wms.part_cards|width|decimal(18,4)|NULL|||#8
C|wms.part_cards|height|decimal(18,4)|NULL|||#9
C|wms.part_cards|weight|decimal(18,4)|NULL|||#10
C|wms.part_cards|is_oversea_service|bit|NOT NULL||((0))|#11
C|wms.part_cards|printed_at|datetime2(7)|NOT NULL||(sysutcdatetime())|#12
C|wms.part_cards|printed_by|nvarchar(200)|NULL|||#13
C|wms.part_cards|created_at|datetime2(7)|NOT NULL||(sysutcdatetime())|#14
C|wms.part_cards|created_by|nvarchar(200)|NULL|||#15
C|wms.part_cards|updated_at|datetime2(7)|NULL|||#16
C|wms.part_cards|updated_by|nvarchar(200)|NULL|||#17
C|wms.part_cards|is_deleted|bit|NOT NULL||((0))|#18
C|wms.part_cards|payload|varchar(500)|NULL|||#19
C|wms.part_cards|model|varchar(50)|NULL|||#20
C|wms.part_cards|origin|varchar(50)|NULL|||#21
C|wms.part_cards|qty|int|NULL|||#22
C|wms.part_cards|category|smallint|NULL|||#23
C|wms.part_cards|LotName|nvarchar(50)|NULL|||#24
C|wms.part_cards|Status_OQC|tinyint|NULL||((0))|#25
C|wms.part_cards|BoxNo|nvarchar(10)|NULL|||#26
C|wms.part_cards|PackingStock|nvarchar(50)|NULL|||#27
C|wms.part_cards|Flag_print|tinyint|NULL||((0))|#28
C|wms.part_cards|is_locked|bit|NOT NULL||((0))|#29
C|wms.part_cards|locked_at|datetime2(7)|NULL|||#30
C|wms.part_cards|locked_by|nvarchar(200)|NULL|||#31
C|wms.part_cards|payload_hash|binary(32)|NULL|COMPUTED||#32
T|wms.production_plans
C|wms.production_plans|id|bigint|NOT NULL|IDENTITY||#1
C|wms.production_plans|plant_code|nvarchar(20)|NOT NULL|||#2
C|wms.production_plans|model|nvarchar(50)|NOT NULL|||#3
C|wms.production_plans|order_no|nvarchar(30)|NULL|||#4
C|wms.production_plans|plan_date|date|NOT NULL|||#5
C|wms.production_plans|planned_qty|int|NOT NULL|||#6
C|wms.production_plans|produced_qty|int|NOT NULL||((0))|#7
C|wms.production_plans|status|nvarchar(20)|NOT NULL|||#8
C|wms.production_plans|synced_at|datetime2(0)|NULL|||#9
T|wms.return_back_deliveries
C|wms.return_back_deliveries|id|bigint|NOT NULL|IDENTITY||#1
C|wms.return_back_deliveries|doc_id|bigint|NOT NULL|||#2
C|wms.return_back_deliveries|pallet_id|bigint|NULL|||#3
C|wms.return_back_deliveries|lot_no|nvarchar(30)|NOT NULL|||#4
C|wms.return_back_deliveries|serial_count|int|NOT NULL||((0))|#5
C|wms.return_back_deliveries|delivered_at|datetime2(0)|NOT NULL||(sysdatetime())|#6
C|wms.return_back_deliveries|delivered_by|nvarchar(100)|NULL|||#7
C|wms.return_back_deliveries|round|int|NOT NULL||((1))|#8
C|wms.return_back_deliveries|kind|nvarchar(10)|NOT NULL||(N'handover')|#9
C|wms.return_back_deliveries|locator_code|nvarchar(50)|NULL|||#10
T|wms.return_back_lines
C|wms.return_back_lines|id|bigint|NOT NULL|IDENTITY||#1
C|wms.return_back_lines|doc_id|bigint|NOT NULL|||#2
C|wms.return_back_lines|model|nvarchar(100)|NOT NULL|||#3
C|wms.return_back_lines|req_qty|int|NOT NULL|||#4
C|wms.return_back_lines|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#5
C|wms.return_back_lines|created_by|nvarchar(100)|NULL|||#6
C|wms.return_back_lines|updated_at|datetime2(0)|NULL|||#7
C|wms.return_back_lines|updated_by|nvarchar(100)|NULL|||#8
C|wms.return_back_lines|round|int|NOT NULL||((1))|#9
T|wms.return_back_rounds
C|wms.return_back_rounds|id|bigint|NOT NULL|IDENTITY||#1
C|wms.return_back_rounds|doc_id|bigint|NOT NULL|||#2
C|wms.return_back_rounds|round|int|NOT NULL|||#3
C|wms.return_back_rounds|asked_qty|int|NULL|||#4
C|wms.return_back_rounds|note|nvarchar(500)|NULL|||#5
C|wms.return_back_rounds|requested_by|nvarchar(100)|NULL|||#6
C|wms.return_back_rounds|requested_at|datetime2(0)|NULL|||#7
C|wms.return_back_rounds|fa_approved_by|nvarchar(100)|NULL|||#8
C|wms.return_back_rounds|fa_approved_at|datetime2(0)|NULL|||#9
C|wms.return_back_rounds|fa_comment|nvarchar(500)|NULL|||#10
C|wms.return_back_rounds|scs_approved_by|nvarchar(100)|NULL|||#11
C|wms.return_back_rounds|scs_approved_at|datetime2(0)|NULL|||#12
C|wms.return_back_rounds|scs_comment|nvarchar(500)|NULL|||#13
C|wms.return_back_rounds|delivered_by|nvarchar(100)|NULL|||#14
C|wms.return_back_rounds|delivered_at|datetime2(0)|NULL|||#15
C|wms.return_back_rounds|cancelled_by|nvarchar(100)|NULL|||#16
C|wms.return_back_rounds|cancelled_at|datetime2(0)|NULL|||#17
C|wms.return_back_rounds|cancel_reason|nvarchar(500)|NULL|||#18
C|wms.return_back_rounds|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#19
T|wms.return_instruction_lines
C|wms.return_instruction_lines|id|bigint|NOT NULL|IDENTITY||#1
C|wms.return_instruction_lines|doc_id|bigint|NOT NULL|||#2
C|wms.return_instruction_lines|line_no|int|NOT NULL||((1))|#3
C|wms.return_instruction_lines|model|nvarchar(100)|NOT NULL|||#4
C|wms.return_instruction_lines|qty|int|NOT NULL|||#5
C|wms.return_instruction_lines|note|nvarchar(500)|NULL|||#6
C|wms.return_instruction_lines|is_deleted|bit|NOT NULL||((0))|#7
C|wms.return_instruction_lines|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#8
C|wms.return_instruction_lines|created_by|nvarchar(100)|NULL|||#9
C|wms.return_instruction_lines|updated_at|datetime2(0)|NULL|||#10
C|wms.return_instruction_lines|updated_by|nvarchar(100)|NULL|||#11
T|wms.return_instruction_serials
C|wms.return_instruction_serials|id|bigint|NOT NULL|IDENTITY||#1
C|wms.return_instruction_serials|doc_id|bigint|NOT NULL|||#2
C|wms.return_instruction_serials|model|nvarchar(100)|NOT NULL|||#3
C|wms.return_instruction_serials|serial_no|nvarchar(100)|NOT NULL|||#4
C|wms.return_instruction_serials|box_no|nvarchar(50)|NULL|||#5
C|wms.return_instruction_serials|pallet_id|bigint|NULL|||#6
C|wms.return_instruction_serials|status|nvarchar(20)|NOT NULL||(N'received')|#7
C|wms.return_instruction_serials|received_at|datetime2(0)|NOT NULL||(sysdatetime())|#8
C|wms.return_instruction_serials|is_deleted|bit|NOT NULL||((0))|#9
C|wms.return_instruction_serials|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#10
C|wms.return_instruction_serials|created_by|nvarchar(100)|NULL|||#11
C|wms.return_instruction_serials|updated_at|datetime2(0)|NULL|||#12
C|wms.return_instruction_serials|updated_by|nvarchar(100)|NULL|||#13
C|wms.return_instruction_serials|sent_fa_at|datetime2(0)|NULL|||#14
C|wms.return_instruction_serials|returned_at|datetime2(0)|NULL|||#15
C|wms.return_instruction_serials|back_round|int|NULL|||#16
T|wms.return_instructions
C|wms.return_instructions|id|bigint|NOT NULL|IDENTITY||#1
C|wms.return_instructions|doc_no|nvarchar(30)|NOT NULL|||#2
C|wms.return_instructions|goods_type|nvarchar(20)|NOT NULL|||#3
C|wms.return_instructions|customer|nvarchar(200)|NULL|||#4
C|wms.return_instructions|expected_date|date|NULL|||#5
C|wms.return_instructions|doc_status|nvarchar(20)|NOT NULL||(N'open')|#6
C|wms.return_instructions|note|nvarchar(500)|NULL|||#7
C|wms.return_instructions|mail_sent_at|datetime2(0)|NULL|||#8
C|wms.return_instructions|mail_sent_to|nvarchar(2000)|NULL|||#9
C|wms.return_instructions|is_deleted|bit|NOT NULL||((0))|#10
C|wms.return_instructions|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#11
C|wms.return_instructions|created_by|nvarchar(100)|NULL|||#12
C|wms.return_instructions|updated_at|datetime2(0)|NULL|||#13
C|wms.return_instructions|updated_by|nvarchar(100)|NULL|||#14
C|wms.return_instructions|closed_at|datetime2(0)|NULL|||#15
C|wms.return_instructions|closed_by|nvarchar(100)|NULL|||#16
C|wms.return_instructions|actual_mail_sent_at|datetime2(0)|NULL|||#17
C|wms.return_instructions|actual_mail_sent_to|nvarchar(2000)|NULL|||#18
C|wms.return_instructions|back_status|nvarchar(20)|NULL|||#19
C|wms.return_instructions|back_note|nvarchar(500)|NULL|||#20
C|wms.return_instructions|back_requested_by|nvarchar(100)|NULL|||#21
C|wms.return_instructions|back_requested_at|datetime2(0)|NULL|||#22
C|wms.return_instructions|back_approved_by|nvarchar(100)|NULL|||#23
C|wms.return_instructions|back_approved_at|datetime2(0)|NULL|||#24
C|wms.return_instructions|back_fa_comment|nvarchar(500)|NULL|||#25
C|wms.return_instructions|back_delivered_by|nvarchar(100)|NULL|||#26
C|wms.return_instructions|back_delivered_at|datetime2(0)|NULL|||#27
C|wms.return_instructions|back_scs_comment|nvarchar(500)|NULL|||#28
C|wms.return_instructions|back_cancelled_by|nvarchar(100)|NULL|||#29
C|wms.return_instructions|back_cancelled_at|datetime2(0)|NULL|||#30
C|wms.return_instructions|back_cancel_reason|nvarchar(500)|NULL|||#31
C|wms.return_instructions|back_scs_approved_by|nvarchar(100)|NULL|||#32
C|wms.return_instructions|back_scs_approved_at|datetime2(0)|NULL|||#33
C|wms.return_instructions|back_round|int|NOT NULL||((0))|#34
T|wms.return_serial_mismatches
C|wms.return_serial_mismatches|id|bigint|NOT NULL|IDENTITY||#1
C|wms.return_serial_mismatches|doc_id|bigint|NOT NULL|||#2
C|wms.return_serial_mismatches|pallet_id|bigint|NULL|||#3
C|wms.return_serial_mismatches|serial_no|nvarchar(100)|NOT NULL|||#4
C|wms.return_serial_mismatches|model|nvarchar(100)|NULL|||#5
C|wms.return_serial_mismatches|reason|nvarchar(20)|NOT NULL|||#6
C|wms.return_serial_mismatches|found_status|nvarchar(20)|NULL|||#7
C|wms.return_serial_mismatches|other_doc_no|nvarchar(30)|NULL|||#8
C|wms.return_serial_mismatches|scanned_at|datetime2(0)|NOT NULL||(sysdatetime())|#9
C|wms.return_serial_mismatches|scanned_by|nvarchar(100)|NULL|||#10
C|wms.return_serial_mismatches|resolved_at|datetime2(0)|NULL|||#11
C|wms.return_serial_mismatches|resolved_by|nvarchar(100)|NULL|||#12
C|wms.return_serial_mismatches|resolve_note|nvarchar(500)|NULL|||#13
C|wms.return_serial_mismatches|is_deleted|bit|NOT NULL||((0))|#14
C|wms.return_serial_mismatches|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#15
C|wms.return_serial_mismatches|created_by|nvarchar(100)|NULL|||#16
C|wms.return_serial_mismatches|updated_at|datetime2(0)|NULL|||#17
C|wms.return_serial_mismatches|updated_by|nvarchar(100)|NULL|||#18
T|wms.sap_import_error_log
C|wms.sap_import_error_log|id|int|NOT NULL|IDENTITY||#1
C|wms.sap_import_error_log|job_name|nvarchar(50)|NOT NULL|||#2
C|wms.sap_import_error_log|plant|nvarchar(10)|NOT NULL|||#3
C|wms.sap_import_error_log|source_file_name|nvarchar(255)|NOT NULL|||#4
C|wms.sap_import_error_log|material_number|nvarchar(50)|NULL|||#5
C|wms.sap_import_error_log|prod_ver|nvarchar(20)|NULL|||#6
C|wms.sap_import_error_log|posting_date|nvarchar(20)|NULL|||#7
C|wms.sap_import_error_log|quantity|nvarchar(20)|NULL|||#8
C|wms.sap_import_error_log|doc_header_text|nvarchar(255)|NULL|||#9
C|wms.sap_import_error_log|planned_order_receive_sloc|nvarchar(50)|NULL|||#10
C|wms.sap_import_error_log|comment|nvarchar(500)|NULL|||#11
C|wms.sap_import_error_log|is_deleted|bit|NOT NULL||((0))|#12
C|wms.sap_import_error_log|created_at|datetime|NOT NULL||(getdate())|#13
C|wms.sap_import_error_log|created_by|nvarchar(50)|NULL|||#14
C|wms.sap_import_error_log|updated_at|datetime|NULL|||#15
C|wms.sap_import_error_log|updated_by|nvarchar(50)|NULL|||#16
T|wms.sap_inbound_logs
C|wms.sap_inbound_logs|id|bigint|NOT NULL|IDENTITY||#1
C|wms.sap_inbound_logs|endpoint|nvarchar(200)|NOT NULL|||#2
C|wms.sap_inbound_logs|doc_no|nvarchar(60)|NULL|||#3
C|wms.sap_inbound_logs|si_no|nvarchar(30)|NULL|||#4
C|wms.sap_inbound_logs|request_body|nvarchar(max)|NULL|||#5
C|wms.sap_inbound_logs|http_status|int|NOT NULL|||#6
C|wms.sap_inbound_logs|result|nvarchar(20)|NOT NULL|||#7
C|wms.sap_inbound_logs|si_id|bigint|NULL|||#8
C|wms.sap_inbound_logs|error_message|nvarchar(2000)|NULL|||#9
C|wms.sap_inbound_logs|remote_ip|nvarchar(45)|NULL|||#10
C|wms.sap_inbound_logs|duration_ms|int|NOT NULL|||#11
C|wms.sap_inbound_logs|received_at|datetime2(3)|NOT NULL|||#12
C|wms.sap_inbound_logs|changed_by|nvarchar(100)|NULL|||#13
C|wms.sap_inbound_logs|change_summary|nvarchar(500)|NULL|||#14
C|wms.sap_inbound_logs|changes|nvarchar(max)|NULL|||#15
T|wms.shipment_instruction_boxes
C|wms.shipment_instruction_boxes|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_instruction_boxes|line_id|bigint|NOT NULL|||#2
C|wms.shipment_instruction_boxes|si_pallet_id|bigint|NULL|||#3
C|wms.shipment_instruction_boxes|box_no|nvarchar(50)|NOT NULL|||#4
C|wms.shipment_instruction_boxes|box_id|bigint|NULL|||#5
C|wms.shipment_instruction_boxes|assign_source|nvarchar(12)|NOT NULL||(N'fifo')|#6
C|wms.shipment_instruction_boxes|match_status|nvarchar(20)|NOT NULL||(N'pending')|#7
C|wms.shipment_instruction_boxes|matched_at|datetime2(0)|NULL|||#8
C|wms.shipment_instruction_boxes|picked_at|datetime2(0)|NULL|||#9
C|wms.shipment_instruction_boxes|picked_by|nvarchar(100)|NULL|||#10
T|wms.shipment_instruction_lines
C|wms.shipment_instruction_lines|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_instruction_lines|si_id|bigint|NOT NULL|||#2
C|wms.shipment_instruction_lines|line_no|int|NOT NULL|||#3
C|wms.shipment_instruction_lines|model|nvarchar(50)|NOT NULL|||#4
C|wms.shipment_instruction_lines|customer_material|nvarchar(50)|NULL|||#5
C|wms.shipment_instruction_lines|po_no|nvarchar(50)|NULL|||#6
C|wms.shipment_instruction_lines|packing_list_no|nvarchar(30)|NULL|||#7
C|wms.shipment_instruction_lines|packing_item_no|nvarchar(10)|NULL|||#8
C|wms.shipment_instruction_lines|invoice_no|nvarchar(30)|NULL|||#9
C|wms.shipment_instruction_lines|so_no|nvarchar(30)|NULL|||#10
C|wms.shipment_instruction_lines|so_item_no|nvarchar(10)|NULL|||#11
C|wms.shipment_instruction_lines|qty_required|int|NOT NULL|||#12
C|wms.shipment_instruction_lines|uom|nvarchar(10)|NULL|||#13
C|wms.shipment_instruction_lines|package_plt|int|NULL|||#14
C|wms.shipment_instruction_lines|package_ctn|int|NULL|||#15
C|wms.shipment_instruction_lines|volume_m3|decimal(18,6)|NULL|||#16
C|wms.shipment_instruction_lines|weight_kg|decimal(18,4)|NULL|||#17
C|wms.shipment_instruction_lines|unit_price|decimal(18,4)|NULL|||#18
C|wms.shipment_instruction_lines|amount|decimal(18,4)|NULL|||#19
C|wms.shipment_instruction_lines|qty_delivered_erp|int|NULL|||#20
C|wms.shipment_instruction_lines|qty_cut|int|NULL|||#21
C|wms.shipment_instruction_lines|cut_by|nvarchar(100)|NULL|||#22
C|wms.shipment_instruction_lines|cut_at|datetime2(0)|NULL|||#23
T|wms.shipment_instruction_pallets
C|wms.shipment_instruction_pallets|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_instruction_pallets|line_id|bigint|NOT NULL|||#2
C|wms.shipment_instruction_pallets|pallet_id|bigint|NOT NULL|||#3
C|wms.shipment_instruction_pallets|unit_type|nvarchar(10)|NOT NULL|||#4
C|wms.shipment_instruction_pallets|box_planned|int|NOT NULL|||#5
C|wms.shipment_instruction_pallets|qty_planned|int|NOT NULL|||#6
C|wms.shipment_instruction_pallets|to_locator_id|bigint|NULL|||#7
C|wms.shipment_instruction_pallets|assigned_to|nvarchar(100)|NULL|||#8
C|wms.shipment_instruction_pallets|pick_mode|nvarchar(12)|NOT NULL||(N'fifo')|#9
C|wms.shipment_instruction_pallets|is_fifo|bit|NOT NULL||((1))|#10
C|wms.shipment_instruction_pallets|approved_by|nvarchar(100)|NULL|||#11
C|wms.shipment_instruction_pallets|approved_at|datetime2(0)|NULL|||#12
C|wms.shipment_instruction_pallets|shipment_status|nvarchar(20)|NOT NULL||(N'pending')|#13
C|wms.shipment_instruction_pallets|picked_at|datetime2(0)|NULL|||#14
C|wms.shipment_instruction_pallets|picked_by|nvarchar(100)|NULL|||#15
C|wms.shipment_instruction_pallets|skip_reason|nvarchar(500)|NULL|||#16
C|wms.shipment_instruction_pallets|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#17
C|wms.shipment_instruction_pallets|created_by|nvarchar(100)|NULL|||#18
T|wms.shipment_instruction_shortages
C|wms.shipment_instruction_shortages|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_instruction_shortages|line_id|bigint|NOT NULL|||#2
C|wms.shipment_instruction_shortages|reason_code|nvarchar(20)|NOT NULL|||#3
C|wms.shipment_instruction_shortages|qty_short|int|NOT NULL|||#4
C|wms.shipment_instruction_shortages|notified_at|datetime2(0)|NOT NULL||(sysdatetime())|#5
C|wms.shipment_instruction_shortages|due_at|datetime2(0)|NULL|||#6
C|wms.shipment_instruction_shortages|eta_at|datetime2(0)|NULL|||#7
C|wms.shipment_instruction_shortages|confirmed_by|nvarchar(100)|NULL|||#8
C|wms.shipment_instruction_shortages|confirmed_at|datetime2(0)|NULL|||#9
C|wms.shipment_instruction_shortages|reason|nvarchar(500)|NULL|||#10
T|wms.shipment_instructions
C|wms.shipment_instructions|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_instructions|doc_no|nvarchar(60)|NOT NULL|||#2
C|wms.shipment_instructions|si_no|nvarchar(30)|NOT NULL|||#3
C|wms.shipment_instructions|revision|nvarchar(20)|NULL|||#4
C|wms.shipment_instructions|category|nvarchar(20)|NULL|||#5
C|wms.shipment_instructions|ship_mode|nvarchar(20)|NULL|||#6
C|wms.shipment_instructions|etd_date|date|NOT NULL|||#7
C|wms.shipment_instructions|eta_date|date|NULL|||#8
C|wms.shipment_instructions|vanning_date|date|NULL|||#9
C|wms.shipment_instructions|cut_off_at|datetime2(0)|NULL|||#10
C|wms.shipment_instructions|port_of_loading|nvarchar(50)|NULL|||#11
C|wms.shipment_instructions|port_of_discharge|nvarchar(50)|NULL|||#12
C|wms.shipment_instructions|country_code|nvarchar(50)|NULL|||#13
C|wms.shipment_instructions|forwarder_code|nvarchar(50)|NULL|||#14
C|wms.shipment_instructions|carrier_code|nvarchar(50)|NULL|||#15
C|wms.shipment_instructions|consignee_code|nvarchar(50)|NULL|||#16
C|wms.shipment_instructions|packing_type|nvarchar(50)|NULL|||#17
C|wms.shipment_instructions|is_white_film|bit|NULL|||#18
C|wms.shipment_instructions|is_case_mark|bit|NULL|||#19
C|wms.shipment_instructions|is_serial_required|bit|NULL|||#20
C|wms.shipment_instructions|pic_name|nvarchar(100)|NULL|||#21
C|wms.shipment_instructions|to_area_id|bigint|NULL|||#22
C|wms.shipment_instructions|doc_status|nvarchar(20)|NOT NULL||(N'released')|#23
C|wms.shipment_instructions|description|nvarchar(500)|NULL|||#24
C|wms.shipment_instructions|header_note|nvarchar(max)|NULL|||#25
C|wms.shipment_instructions|is_deleted|bit|NOT NULL||((0))|#26
C|wms.shipment_instructions|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#27
C|wms.shipment_instructions|created_by|nvarchar(100)|NULL|||#28
C|wms.shipment_instructions|updated_at|datetime2(0)|NULL|||#29
C|wms.shipment_instructions|updated_by|nvarchar(100)|NULL|||#30
C|wms.shipment_instructions|row_version|timestamp|NOT NULL|||#31
T|wms.shipment_trip_columns
C|wms.shipment_trip_columns|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_trip_columns|trip_id|bigint|NOT NULL|||#2
C|wms.shipment_trip_columns|column_code|nvarchar(10)|NOT NULL|||#3
C|wms.shipment_trip_columns|bottom_pallet_id|bigint|NOT NULL|||#4
C|wms.shipment_trip_columns|top_pallet_id|bigint|NULL|||#5
C|wms.shipment_trip_columns|stacked_at|datetime2(0)|NOT NULL||(sysdatetime())|#6
C|wms.shipment_trip_columns|stacked_by|nvarchar(100)|NULL|||#7
C|wms.shipment_trip_columns|placed_at|datetime2(0)|NULL|||#8
C|wms.shipment_trip_columns|placed_by|nvarchar(100)|NULL|||#9
C|wms.shipment_trip_columns|is_deleted|bit|NOT NULL||((0))|#10
C|wms.shipment_trip_columns|deleted_at|datetime2(0)|NULL|||#11
C|wms.shipment_trip_columns|deleted_by|nvarchar(100)|NULL|||#12
T|wms.shipment_trip_inspections
C|wms.shipment_trip_inspections|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_trip_inspections|trip_id|bigint|NOT NULL|||#2
C|wms.shipment_trip_inspections|result|nvarchar(10)|NOT NULL|||#3
C|wms.shipment_trip_inspections|passed_conditions|nvarchar(200)|NULL|||#4
C|wms.shipment_trip_inspections|note|nvarchar(1000)|NULL|||#5
C|wms.shipment_trip_inspections|container_no|nvarchar(20)|NULL|||#6
C|wms.shipment_trip_inspections|inspected_at|datetime2(0)|NOT NULL||(sysdatetime())|#7
C|wms.shipment_trip_inspections|inspected_by|nvarchar(100)|NULL|||#8
T|wms.shipment_trip_pallets
C|wms.shipment_trip_pallets|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_trip_pallets|trip_id|bigint|NOT NULL|||#2
C|wms.shipment_trip_pallets|pallet_id|bigint|NOT NULL|||#3
C|wms.shipment_trip_pallets|is_deleted|bit|NOT NULL||((0))|#4
C|wms.shipment_trip_pallets|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#5
C|wms.shipment_trip_pallets|created_by|nvarchar(100)|NULL|||#6
T|wms.shipment_trip_photos
C|wms.shipment_trip_photos|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_trip_photos|trip_id|bigint|NOT NULL|||#2
C|wms.shipment_trip_photos|item_key|nvarchar(40)|NOT NULL|||#3
C|wms.shipment_trip_photos|unit_no|int|NULL|||#4
C|wms.shipment_trip_photos|slot_no|int|NOT NULL||((1))|#5
C|wms.shipment_trip_photos|file_path|nvarchar(400)|NOT NULL|||#6
C|wms.shipment_trip_photos|file_name|nvarchar(200)|NOT NULL|||#7
C|wms.shipment_trip_photos|content_type|nvarchar(100)|NULL|||#8
C|wms.shipment_trip_photos|size_bytes|bigint|NULL|||#9
C|wms.shipment_trip_photos|is_deleted|bit|NOT NULL||((0))|#10
C|wms.shipment_trip_photos|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#11
C|wms.shipment_trip_photos|created_by|nvarchar(100)|NULL|||#12
C|wms.shipment_trip_photos|deleted_at|datetime2(0)|NULL|||#13
C|wms.shipment_trip_photos|deleted_by|nvarchar(100)|NULL|||#14
C|wms.shipment_trip_photos|pallet_id|bigint|NULL|||#15
T|wms.shipment_trip_sis
C|wms.shipment_trip_sis|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_trip_sis|trip_id|bigint|NOT NULL|||#2
C|wms.shipment_trip_sis|si_id|bigint|NOT NULL|||#3
C|wms.shipment_trip_sis|plt_planned|int|NULL|||#4
C|wms.shipment_trip_sis|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#5
C|wms.shipment_trip_sis|created_by|nvarchar(100)|NULL|||#6
T|wms.shipment_trip_stacks
C|wms.shipment_trip_stacks|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_trip_stacks|trip_id|bigint|NOT NULL|||#2
C|wms.shipment_trip_stacks|coc_no|int|NOT NULL|||#3
C|wms.shipment_trip_stacks|bottom_pallet_id|bigint|NOT NULL|||#4
C|wms.shipment_trip_stacks|top_pallet_id|bigint|NOT NULL|||#5
C|wms.shipment_trip_stacks|is_deleted|bit|NOT NULL||((0))|#6
C|wms.shipment_trip_stacks|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#7
C|wms.shipment_trip_stacks|created_by|nvarchar(100)|NULL|||#8
C|wms.shipment_trip_stacks|deleted_at|datetime2(0)|NULL|||#9
C|wms.shipment_trip_stacks|deleted_by|nvarchar(100)|NULL|||#10
T|wms.shipment_trips
C|wms.shipment_trips|id|bigint|NOT NULL|IDENTITY||#1
C|wms.shipment_trips|vehicle_type|nvarchar(10)|NOT NULL|||#2
C|wms.shipment_trips|plate_no|nvarchar(20)|NULL|||#3
C|wms.shipment_trips|container_no|nvarchar(20)|NULL|||#4
C|wms.shipment_trips|container_size|nvarchar(10)|NULL|||#5
C|wms.shipment_trips|seal_no|nvarchar(30)|NULL|||#6
C|wms.shipment_trips|driver_name|nvarchar(100)|NULL|||#7
C|wms.shipment_trips|driver_phone|nvarchar(20)|NULL|||#8
C|wms.shipment_trips|driver_id_type|nvarchar(10)|NULL|||#9
C|wms.shipment_trips|driver_id_no|nvarchar(20)|NULL|||#10
C|wms.shipment_trips|forwarder_code|nvarchar(50)|NULL|||#11
C|wms.shipment_trips|planned_arrival_at|datetime2(0)|NULL|||#12
C|wms.shipment_trips|status|nvarchar(20)|NOT NULL||(N'planned')|#13
C|wms.shipment_trips|arrived_at|datetime2(0)|NULL|||#14
C|wms.shipment_trips|arrived_by|nvarchar(100)|NULL|||#15
C|wms.shipment_trips|sealed_at|datetime2(0)|NULL|||#16
C|wms.shipment_trips|sealed_by|nvarchar(100)|NULL|||#17
C|wms.shipment_trips|departed_at|datetime2(0)|NULL|||#18
C|wms.shipment_trips|departed_by|nvarchar(100)|NULL|||#19
C|wms.shipment_trips|cancelled_at|datetime2(0)|NULL|||#20
C|wms.shipment_trips|cancelled_by|nvarchar(100)|NULL|||#21
C|wms.shipment_trips|cancel_reason|nvarchar(400)|NULL|||#22
C|wms.shipment_trips|note|nvarchar(500)|NULL|||#23
C|wms.shipment_trips|is_deleted|bit|NOT NULL||((0))|#24
C|wms.shipment_trips|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#25
C|wms.shipment_trips|created_by|nvarchar(100)|NULL|||#26
C|wms.shipment_trips|updated_at|datetime2(0)|NULL|||#27
C|wms.shipment_trips|updated_by|nvarchar(100)|NULL|||#28
C|wms.shipment_trips|row_version|timestamp|NOT NULL|||#29
C|wms.shipment_trips|driver_license_no|nvarchar(20)|NULL|||#30
C|wms.shipment_trips|trip_no|nvarchar(20)|NOT NULL|||#31
T|wms.stock_events
C|wms.stock_events|id|bigint|NOT NULL|IDENTITY||#1
C|wms.stock_events|subject_type|varchar(10)|NOT NULL||('pallet')|#2
C|wms.stock_events|pallet_id|bigint|NULL|||#3
C|wms.stock_events|pallet_code|nvarchar(50)|NULL|||#4
C|wms.stock_events|stocky_code|nvarchar(50)|NULL|||#5
C|wms.stock_events|box_id|bigint|NULL|||#6
C|wms.stock_events|box_no|nvarchar(50)|NULL|||#7
C|wms.stock_events|event_code|varchar(40)|NOT NULL|||#8
C|wms.stock_events|event_at|datetime2(0)|NOT NULL||(sysdatetime())|#9
C|wms.stock_events|actor|nvarchar(100)|NULL|||#10
C|wms.stock_events|source|varchar(10)|NOT NULL||('WEB')|#11
C|wms.stock_events|from_locator_id|bigint|NULL|||#12
C|wms.stock_events|from_locator_code|nvarchar(50)|NULL|||#13
C|wms.stock_events|from_map_type|varchar(20)|NULL|||#14
C|wms.stock_events|from_area_code|nvarchar(30)|NULL|||#15
C|wms.stock_events|to_locator_id|bigint|NULL|||#16
C|wms.stock_events|to_locator_code|nvarchar(50)|NULL|||#17
C|wms.stock_events|to_map_type|varchar(20)|NULL|||#18
C|wms.stock_events|to_area_code|nvarchar(30)|NULL|||#19
C|wms.stock_events|ref_type|varchar(30)|NULL|||#20
C|wms.stock_events|ref_id|bigint|NULL|||#21
C|wms.stock_events|ref_no|nvarchar(50)|NULL|||#22
C|wms.stock_events|related_pallet_id|bigint|NULL|||#23
C|wms.stock_events|box_count_before|int|NULL|||#24
C|wms.stock_events|box_count_after|int|NULL|||#25
C|wms.stock_events|note|nvarchar(500)|NULL|||#26
C|wms.stock_events|payload|nvarchar(max)|NULL|||#27
T|wms.stowage_columns
C|wms.stowage_columns|id|bigint|NOT NULL|IDENTITY||#1
C|wms.stowage_columns|plan_id|bigint|NOT NULL|||#2
C|wms.stowage_columns|code|nvarchar(10)|NOT NULL|||#3
C|wms.stowage_columns|container_index|int|NULL|||#4
C|wms.stowage_columns|row_no|int|NULL|||#5
C|wms.stowage_columns|lane_no|tinyint|NULL|||#6
C|wms.stowage_columns|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#7
C|wms.stowage_columns|created_by|nvarchar(100)|NULL|||#8
C|wms.stowage_columns|rotated|bit|NOT NULL||((0))|#9
T|wms.stowage_pallet_boxes
C|wms.stowage_pallet_boxes|id|bigint|NOT NULL|IDENTITY||#1
C|wms.stowage_pallet_boxes|plan_id|bigint|NOT NULL|||#2
C|wms.stowage_pallet_boxes|stowage_pallet_id|bigint|NOT NULL|||#3
C|wms.stowage_pallet_boxes|si_box_id|bigint|NULL|||#4
C|wms.stowage_pallet_boxes|si_line_id|bigint|NULL|||#5
C|wms.stowage_pallet_boxes|carton_seq|int|NULL|||#6
T|wms.stowage_pallets
C|wms.stowage_pallets|id|bigint|NOT NULL|IDENTITY||#1
C|wms.stowage_pallets|plan_id|bigint|NOT NULL|||#2
C|wms.stowage_pallets|column_id|bigint|NOT NULL|||#3
C|wms.stowage_pallets|tier|tinyint|NOT NULL|||#4
C|wms.stowage_pallets|code|nvarchar(10)|NOT NULL|||#5
C|wms.stowage_pallets|si_id|bigint|NOT NULL|||#6
C|wms.stowage_pallets|pallet_size|nvarchar(10)|NOT NULL||(N'S1210')|#7
C|wms.stowage_pallets|length_cm|decimal(6,1)|NOT NULL||((120))|#8
C|wms.stowage_pallets|width_cm|decimal(6,1)|NOT NULL||((100))|#9
C|wms.stowage_pallets|wms_pallet_id|bigint|NULL|||#10
C|wms.stowage_pallets|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#11
C|wms.stowage_pallets|created_by|nvarchar(100)|NULL|||#12
T|wms.stowage_plan_containers
C|wms.stowage_plan_containers|id|bigint|NOT NULL|IDENTITY||#1
C|wms.stowage_plan_containers|plan_id|bigint|NOT NULL|||#2
C|wms.stowage_plan_containers|container_index|int|NOT NULL|||#3
C|wms.stowage_plan_containers|trip_id|bigint|NULL|||#4
C|wms.stowage_plan_containers|unit_no|nvarchar(20)|NULL|||#5
C|wms.stowage_plan_containers|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#6
C|wms.stowage_plan_containers|created_by|nvarchar(100)|NULL|||#7
T|wms.stowage_plan_sis
C|wms.stowage_plan_sis|id|bigint|NOT NULL|IDENTITY||#1
C|wms.stowage_plan_sis|plan_id|bigint|NOT NULL|||#2
C|wms.stowage_plan_sis|si_id|bigint|NOT NULL|||#3
C|wms.stowage_plan_sis|color|char(7)|NULL|||#4
C|wms.stowage_plan_sis|sort_order|int|NOT NULL||((0))|#5
C|wms.stowage_plan_sis|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#6
C|wms.stowage_plan_sis|created_by|nvarchar(100)|NULL|||#7
T|wms.stowage_plans
C|wms.stowage_plans|id|bigint|NOT NULL|IDENTITY||#1
C|wms.stowage_plans|plan_no|nvarchar(30)|NOT NULL|||#2
C|wms.stowage_plans|unit_kind|nvarchar(10)|NOT NULL||(N'CONT')|#3
C|wms.stowage_plans|ship_mode|nvarchar(10)|NOT NULL|||#4
C|wms.stowage_plans|container_type|nvarchar(20)|NOT NULL|||#5
C|wms.stowage_plans|forwarder_code|nvarchar(50)|NULL|||#6
C|wms.stowage_plans|vanning_date|date|NULL|||#7
C|wms.stowage_plans|etd_date|date|NULL|||#8
C|wms.stowage_plans|destination|nvarchar(100)|NULL|||#9
C|wms.stowage_plans|base_type|nvarchar(10)|NOT NULL||(N'no_base')|#10
C|wms.stowage_plans|status|nvarchar(12)|NOT NULL||(N'not_started')|#11
C|wms.stowage_plans|total_boxes|int|NOT NULL||((0))|#12
C|wms.stowage_plans|total_pallets|int|NOT NULL||((0))|#13
C|wms.stowage_plans|total_columns|int|NOT NULL||((0))|#14
C|wms.stowage_plans|placed_columns|int|NOT NULL||((0))|#15
C|wms.stowage_plans|total_weight_kg|decimal(12,3)|NULL|||#16
C|wms.stowage_plans|saved_at|datetime2(0)|NULL|||#17
C|wms.stowage_plans|saved_by|nvarchar(100)|NULL|||#18
C|wms.stowage_plans|note|nvarchar(500)|NULL|||#19
C|wms.stowage_plans|is_deleted|bit|NOT NULL||((0))|#20
C|wms.stowage_plans|created_at|datetime2(0)|NOT NULL||(sysdatetime())|#21
C|wms.stowage_plans|created_by|nvarchar(100)|NULL|||#22
C|wms.stowage_plans|updated_at|datetime2(0)|NULL|||#23
C|wms.stowage_plans|updated_by|nvarchar(100)|NULL|||#24
C|wms.stowage_plans|row_version|timestamp|NOT NULL|||#25
T|wms.sync_queue_dev
C|wms.sync_queue_dev|queue_id|bigint|NOT NULL|IDENTITY||#1
C|wms.sync_queue_dev|table_name|varchar(10)|NOT NULL|||#2
C|wms.sync_queue_dev|row_id|bigint|NOT NULL|||#3
C|wms.sync_queue_dev|queued_at|datetime2(7)|NOT NULL||(sysdatetime())|#4

line
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
K|master.api_keys|pk_api_keys|id|INCLUDE()||CLUSTERED
K|master.categories|PK__categori__357D4CF8F4BD2F6E|code|INCLUDE()||CLUSTERED
K|master.configs|pk_configs|id|INCLUDE()||CLUSTERED
K|master.email_config|PK_email_config|id|INCLUDE()||CLUSTERED
K|master.email_event_subtypes|PK_email_event_subtypes|event_code,sub_code|INCLUDE()||CLUSTERED
K|master.email_events|PK_email_events|code|INCLUDE()||CLUSTERED
K|master.locator_map|pk_locator_map|id|INCLUDE()||CLUSTERED
K|master.locators|pk_locators_new|id|INCLUDE()||CLUSTERED
K|master.models|PK__models__3213E83F9300A71B|id|INCLUDE()||CLUSTERED
K|master.pda_app_versions|PK_pda_app_versions|id|INCLUDE()||CLUSTERED
K|master.permission_modules|PK_permission_modules|id|INCLUDE()||CLUSTERED
K|master.permission_screens|PK_permission_screens|id|INCLUDE()||CLUSTERED
K|master.permissions|PK_permissions|id|INCLUDE()||CLUSTERED
K|master.racks|pk_racks|id|INCLUDE()||CLUSTERED
K|master.role_permissions|PK_role_permissions|id|INCLUDE()||CLUSTERED
K|master.roles|PK_roles|id|INCLUDE()||CLUSTERED
K|master.shortage_reasons|PK_shortage_reasons|code|INCLUDE()||CLUSTERED
K|master.stock_event_types|PK_stock_event_types|id|INCLUDE()||CLUSTERED
K|master.user_roles|PK_user_roles|id|INCLUDE()||CLUSTERED
K|master.users|PK_users|id|INCLUDE()||CLUSTERED
K|master.warehouse_areas|PK__warehous__3213E83FEDB5FD6C|id|INCLUDE()||CLUSTERED
K|master.warehouses|PK__warehous__3213E83F3DB0BB8C|id|INCLUDE()||CLUSTERED
K|wms.balance_docs|pk_balance_docs|id|INCLUDE()||CLUSTERED
K|wms.box_lines|PK_box_lines|id|INCLUDE()||CLUSTERED
K|wms.boxes|PK_lot_boxes|id|INCLUDE()||CLUSTERED
K|wms.inventory_count_lines|PK__inventor__3213E83FC4F49AC8|id|INCLUDE()||CLUSTERED
K|wms.inventory_counts|PK__inventor__3213E83FB568AB5D|id|INCLUDE()||CLUSTERED
K|wms.inventory_move_lines|PK__inventor__3213E83FC05E0185|id|INCLUDE()||CLUSTERED
K|wms.inventory_moves|PK__inventor__3213E83F85ACF0AA|id|INCLUDE()||CLUSTERED
K|wms.pallets|PK_lots|id|INCLUDE()||CLUSTERED
K|wms.part_card_lineage|PK_part_card_lineage|id|INCLUDE()||CLUSTERED
K|wms.part_card_rows|PK_part_card_rows|id|INCLUDE()||CLUSTERED
K|wms.part_cards|PK_part_cards|id|INCLUDE()||CLUSTERED
K|wms.production_plans|PK_production_plans|id|INCLUDE()||CLUSTERED
K|wms.return_back_deliveries|pk_return_back_deliveries|id|INCLUDE()||CLUSTERED
K|wms.return_back_lines|pk_return_back_lines|id|INCLUDE()||CLUSTERED
K|wms.return_back_rounds|pk_return_back_rounds|id|INCLUDE()||CLUSTERED
K|wms.return_instruction_lines|pk_return_instruction_lines|id|INCLUDE()||CLUSTERED
K|wms.return_instruction_serials|pk_return_instruction_serials|id|INCLUDE()||CLUSTERED
K|wms.return_instructions|pk_return_instructions|id|INCLUDE()||CLUSTERED
K|wms.return_serial_mismatches|pk_return_serial_mismatches|id|INCLUDE()||CLUSTERED
K|wms.sap_import_error_log|PK__sap_impo__3213E83F45F6C0E4|id|INCLUDE()||CLUSTERED
K|wms.sap_inbound_logs|PK_sap_inbound_logs|id|INCLUDE()||CLUSTERED
K|wms.shipment_instruction_boxes|PK_si_boxes|id|INCLUDE()||CLUSTERED
K|wms.shipment_instruction_lines|PK_si_lines|id|INCLUDE()||CLUSTERED
K|wms.shipment_instruction_pallets|PK_si_pallets|id|INCLUDE()||CLUSTERED
K|wms.shipment_instruction_shortages|PK_si_shortages|id|INCLUDE()||CLUSTERED
K|wms.shipment_instructions|PK_shipment_instructions|id|INCLUDE()||CLUSTERED
K|wms.shipment_trip_columns|PK_shipment_trip_columns|id|INCLUDE()||CLUSTERED
K|wms.shipment_trip_inspections|PK_shipment_trip_inspections|id|INCLUDE()||CLUSTERED
K|wms.shipment_trip_pallets|PK_shipment_trip_pallets|id|INCLUDE()||CLUSTERED
K|wms.shipment_trip_photos|PK_shipment_trip_photos|id|INCLUDE()||CLUSTERED
K|wms.shipment_trip_sis|PK_shipment_trip_sis|id|INCLUDE()||CLUSTERED
K|wms.shipment_trip_stacks|PK_shipment_trip_stacks|id|INCLUDE()||CLUSTERED
K|wms.shipment_trips|PK_shipment_trips|id|INCLUDE()||CLUSTERED
K|wms.stock_events|PK_stock_events|id|INCLUDE()||CLUSTERED
K|wms.stowage_columns|PK_stowage_columns|id|INCLUDE()||CLUSTERED
K|wms.stowage_pallet_boxes|PK_stowage_pallet_boxes|id|INCLUDE()||CLUSTERED
K|wms.stowage_pallets|PK_stowage_pallets|id|INCLUDE()||CLUSTERED
K|wms.stowage_plan_containers|PK_stowage_plan_containers|id|INCLUDE()||CLUSTERED
K|wms.stowage_plan_sis|PK_stowage_plan_sis|id|INCLUDE()||CLUSTERED
K|wms.stowage_plans|PK_stowage_plans|id|INCLUDE()||CLUSTERED
K|wms.sync_queue_dev|PK__sync_que__2294FA6EF2B2D260|queue_id|INCLUDE()||CLUSTERED
U|master.api_keys|ux_api_keys_key_prefix|key_prefix|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|master.configs|ux_configs_key_active|config_key|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|master.email_config|UX_email_config_scope|event_code,department,sub_code,category,model,area_code,recipient_type,user_id,email|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|master.locator_map|ux_map_locator|locator_id|INCLUDE()|([locator_id] IS NOT NULL AND [is_deleted]=(0))|NONCLUSTERED
U|master.locator_map|ux_map_rack|rack_id|INCLUDE()|([rack_id] IS NOT NULL AND [is_deleted]=(0))|NONCLUSTERED
U|master.locators|ux_locators_new_code|locator_code|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|master.locators|ux_locators_new_rack_cell|rack_id,rack_row,rack_col,rack_level|INCLUDE()|([rack_id] IS NOT NULL AND [is_deleted]=(0))|NONCLUSTERED
U|master.models|UQ_models_code|code|INCLUDE()||NONCLUSTERED
U|master.pda_app_versions|UX_pda_app_versions_current|is_current|INCLUDE()|([is_current]=(1) AND [is_deleted]=(0))|NONCLUSTERED
U|master.pda_app_versions|UX_pda_app_versions_version_code|version_code|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|master.pda_app_versions|UX_pda_app_versions_version|version|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|master.permission_modules|UQ_permission_modules_code|code|INCLUDE()||NONCLUSTERED
U|master.permission_screens|UQ_permission_screens_code|code|INCLUDE()||NONCLUSTERED
U|master.permissions|UQ_permissions_code|code|INCLUDE()||NONCLUSTERED
U|master.racks|ux_racks_code|rack_code|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|master.role_permissions|UQ_role_permissions|role_id,permission_id|INCLUDE()||NONCLUSTERED
U|master.roles|UQ_roles_code_active|code|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|master.stock_event_types|UQ_stock_event_types_code|code|INCLUDE()||NONCLUSTERED
U|master.user_roles|UQ_user_roles|user_id,role_id|INCLUDE()||NONCLUSTERED
U|master.users|UQ_users_employee_code|employee_code|INCLUDE()||NONCLUSTERED
U|master.warehouse_areas|uq_warehouse_areas_code|area_code|INCLUDE()||NONCLUSTERED
U|master.warehouses|UQ__warehous__357D4CF9E30D1123|code|INCLUDE()||NONCLUSTERED
U|wms.balance_docs|uq_balance_doc_no|doc_no|INCLUDE()||NONCLUSTERED
U|wms.box_lines|UQ_box_lines_box_serial|box_id,serial_no|INCLUDE()|([serial_no] IS NOT NULL AND [is_deleted]=(0))|NONCLUSTERED
U|wms.boxes|UQ_lot_boxes_lot_box|lot_id,box_no|INCLUDE()||NONCLUSTERED
U|wms.inventory_count_lines|uq_count_line|count_id,line_no|INCLUDE()||NONCLUSTERED
U|wms.inventory_counts|UQ__inventor__8AD0FE5EF80B7705|doc_no|INCLUDE()||NONCLUSTERED
U|wms.inventory_move_lines|uq_move_line|move_id,line_no|INCLUDE()||NONCLUSTERED
U|wms.inventory_moves|UQ__inventor__8AD0FE5EF089F6B7|doc_no|INCLUDE()||NONCLUSTERED
U|wms.pallets|UQ_pallets_pallet_id|pallet_id|INCLUDE()||NONCLUSTERED
U|wms.pallets|ux_pallets_pallet_id_active|pallet_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.part_card_rows|UQ_part_card_rows_card_line|part_card_id,line_no|INCLUDE()||NONCLUSTERED
U|wms.production_plans|UQ_production_plans|plant_code,model,plan_date,order_no|INCLUDE()||NONCLUSTERED
U|wms.return_back_lines|ux_rbl_doc_round_model|doc_id,round,model|INCLUDE()||NONCLUSTERED
U|wms.return_back_rounds|ux_rbr_doc_round|doc_id,round|INCLUDE()||NONCLUSTERED
U|wms.return_instruction_lines|ux_ri_lines_doc_model|doc_id,model|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.return_instruction_serials|ux_ris_doc_serial|doc_id,serial_no|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.return_instruction_serials|ux_ris_serial_open|serial_no|INCLUDE()|([is_deleted]=(0) AND [status]<>N'shipped')|NONCLUSTERED
U|wms.return_instructions|ux_return_instructions_doc_no|doc_no|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.shipment_instruction_boxes|UQ_si_boxes_line_box|line_id,box_no|INCLUDE()||NONCLUSTERED
U|wms.shipment_instruction_boxes|UX_si_boxes_box|box_id|INCLUDE()|([box_id] IS NOT NULL)|NONCLUSTERED
U|wms.shipment_instruction_lines|UQ_si_lines_si_line|si_id,line_no|INCLUDE()||NONCLUSTERED
U|wms.shipment_instruction_pallets|UX_si_pallets_full|pallet_id|INCLUDE()|([unit_type]=N'pallet' AND ([shipment_status] IN (N'pending', N'picked')))|NONCLUSTERED
U|wms.shipment_instruction_pallets|UX_si_pallets_pending_line|pallet_id,line_id|INCLUDE()|([shipment_status]=N'pending')|NONCLUSTERED
U|wms.shipment_instruction_shortages|UQ_si_shortages|line_id,reason_code|INCLUDE()||NONCLUSTERED
U|wms.shipment_instructions|UQ_si_doc_no|doc_no|INCLUDE()||NONCLUSTERED
U|wms.shipment_trip_columns|UX_trip_columns_bottom|trip_id,bottom_pallet_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.shipment_trip_columns|UX_trip_columns_code|trip_id,column_code|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.shipment_trip_columns|UX_trip_columns_top|trip_id,top_pallet_id|INCLUDE()|([is_deleted]=(0) AND [top_pallet_id] IS NOT NULL)|NONCLUSTERED
U|wms.shipment_trip_pallets|UX_trip_pallets|trip_id,pallet_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.shipment_trip_photos|UX_trip_photos_slot|trip_id,item_key,unit_no,pallet_id,slot_no|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.shipment_trip_sis|UQ_trip_sis|trip_id,si_id|INCLUDE()||NONCLUSTERED
U|wms.shipment_trip_stacks|UX_trip_stacks_bottom|trip_id,bottom_pallet_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.shipment_trip_stacks|UX_trip_stacks_coc|trip_id,coc_no|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.shipment_trip_stacks|UX_trip_stacks_top|trip_id,top_pallet_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
U|wms.shipment_trips|UX_trips_active_container|container_no|INCLUDE()|([container_no] IS NOT NULL AND [is_deleted]=(0) AND [status]<>N'departed' AND [status]<>N'cancelled')|NONCLUSTERED
U|wms.shipment_trips|UX_trips_trip_no|trip_no|INCLUDE()||NONCLUSTERED
U|wms.stowage_columns|UQ_stw_columns_code|plan_id,code|INCLUDE()||NONCLUSTERED
U|wms.stowage_columns|UX_stw_columns_slot|plan_id,container_index,row_no,lane_no|INCLUDE()|([container_index] IS NOT NULL)|NONCLUSTERED
U|wms.stowage_pallet_boxes|UX_stw_boxes_plan_box|plan_id,si_box_id|INCLUDE()|([si_box_id] IS NOT NULL)|NONCLUSTERED
U|wms.stowage_pallet_boxes|UX_stw_boxes_plan_carton|plan_id,si_line_id,carton_seq|INCLUDE()|([si_line_id] IS NOT NULL)|NONCLUSTERED
U|wms.stowage_pallets|UQ_stw_pallets_code|plan_id,code|INCLUDE()||NONCLUSTERED
U|wms.stowage_pallets|UQ_stw_pallets_tier|column_id,tier|INCLUDE()||NONCLUSTERED
U|wms.stowage_plan_containers|UQ_stw_containers_index|plan_id,container_index|INCLUDE()||NONCLUSTERED
U|wms.stowage_plan_containers|UX_stw_containers_trip|trip_id|INCLUDE()|([trip_id] IS NOT NULL)|NONCLUSTERED
U|wms.stowage_plan_sis|UQ_stw_plan_sis|plan_id,si_id|INCLUDE()||NONCLUSTERED
U|wms.stowage_plans|UQ_stowage_plans_no|plan_no|INCLUDE()||NONCLUSTERED
X|master.api_keys|ix_api_keys_client_name|client_name|INCLUDE()||NONCLUSTERED
X|master.email_config|IX_email_config_event|event_code|INCLUDE(area_code,category,department,email,model,recipient_type,sub_code,user_id)|([is_deleted]=(0) AND [is_active]=(1))|NONCLUSTERED
X|master.locator_map|ix_map_parent|parent_type,parent_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|master.models|IX_models_category_id|category_id|INCLUDE()||NONCLUSTERED
X|master.models|IX_models_is_active|is_active|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|master.models|IX_models_suggest_area|suggest_area|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|master.permission_screens|IX_permission_screens_module_id|module_id|INCLUDE()||NONCLUSTERED
X|master.permissions|IX_permissions_screen_id|screen_id|INCLUDE()||NONCLUSTERED
X|master.role_permissions|IX_role_permissions_role_id|role_id|INCLUDE()||NONCLUSTERED
X|master.user_roles|IX_user_roles_role_id|role_id|INCLUDE()||NONCLUSTERED
X|master.user_roles|IX_user_roles_user_id|user_id|INCLUDE()||NONCLUSTERED
X|master.users|IX_users_department|department|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|master.users|IX_users_is_active|is_active|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.balance_docs|ix_balance_docs_count|count_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.balance_docs|ix_balance_docs_status|doc_status|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.box_lines|IX_box_lines_box_id|box_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.box_lines|IX_box_lines_box_model|box_id,model|INCLUDE(qty)|([is_deleted]=(0))|NONCLUSTERED
X|wms.box_lines|IX_box_lines_box|box_id|INCLUDE(qty)|([is_deleted]=(0))|NONCLUSTERED
X|wms.box_lines|IX_box_lines_model|model|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.box_lines|IX_box_lines_serial_no|serial_no|INCLUDE(box_id,model)|([serial_no] IS NOT NULL AND [is_deleted]=(0))|NONCLUSTERED
X|wms.boxes|IX_boxes_boxno_model|box_no,model|INCLUDE(customer_po,lot_id,production_date)|([is_deleted]=(0))|NONCLUSTERED
X|wms.boxes|IX_boxes_lot_name|lot_name|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.boxes|IX_boxes_lot_po|lot_id,customer_po,production_date|INCLUDE(box_no,model)|([is_deleted]=(0))|NONCLUSTERED
X|wms.boxes|IX_boxes_lot_status|lot_id,oqc_status|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.boxes|IX_boxes_model_date|model,production_date|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.boxes|IX_boxes_raw_payload_hash|raw_payload_hash|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.boxes|IX_lot_boxes_lot_id|lot_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.pallets|IX_lots_category_id|category_id|INCLUDE()||NONCLUSTERED
X|wms.pallets|IX_lots_created_at|created_at DESC,id DESC|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.pallets|IX_lots_inspection|inspection_status|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.pallets|IX_lots_locator_id|locator_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.pallets|IX_lots_production_date|production_date|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.pallets|ix_pallets_disposition|disposition|INCLUDE(box_count,locator_id,model,pallet_id,production_date)|([is_deleted]=(0) AND [disposition] IS NOT NULL)|NONCLUSTERED
X|wms.pallets|IX_pallets_model_date_insp|model,production_date,inspection_status|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.pallets|IX_pallets_sap_claim|sap_status,locator_id|INCLUDE(box_count,detail_level,inspection_status,lot_type,model,pallet_id,production_date,stocky_code)|([is_deleted]=(0) AND ([sap_status] IN ((0), (3))))|NONCLUSTERED
X|wms.pallets|IX_pallets_sap_inflight|sap_status,model|INCLUDE(sap_pushed_at)|([is_deleted]=(0) AND ([sap_status] IN ((1), (2))))|NONCLUSTERED
X|wms.pallets|IX_pallets_sap_status|sap_status|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.pallets|ix_pallets_sync_active|inspection_status|INCLUDE(detail_level,locator_id,pallet_id,si_no)|([is_deleted]=(0))|NONCLUSTERED
X|wms.part_card_lineage|IX_part_card_lineage_card|part_card_id|INCLUDE(action,source_part_card_id)||NONCLUSTERED
X|wms.part_card_lineage|IX_part_card_lineage_source|source_part_card_id|INCLUDE(action,part_card_id)||NONCLUSTERED
X|wms.part_card_rows|IX_part_card_rows_card_id|part_card_id|INCLUDE()||NONCLUSTERED
X|wms.part_cards|IX_part_cards_customer_po|customer_po_no|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.part_cards|IX_part_cards_model_date_status|model,production_date,Status_OQC|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.part_cards|IX_part_cards_model_qty|model,qty,id DESC|INCLUDE(height,length,weight,width)|([is_deleted]=(0) AND [qty]>(0) AND [length]>(0) AND [width]>(0) AND [height]>(0))|NONCLUSTERED
X|wms.part_cards|IX_part_cards_payload_hash|payload_hash,id|INCLUDE(height,length,weight,width)|([is_deleted]=(0) AND [length]>(0) AND [width]>(0) AND [height]>(0))|NONCLUSTERED
X|wms.part_cards|IX_part_cards_payload|payload|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.part_cards|IX_part_cards_po_no|po_no|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.part_cards|IX_part_cards_printed_at|printed_at|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.production_plans|IX_pp_model_date|model,plan_date|INCLUDE(planned_qty,produced_qty,status)||NONCLUSTERED
X|wms.return_back_deliveries|ix_rbd_doc|doc_id,delivered_at DESC|INCLUDE(delivered_by,lot_no,serial_count)||NONCLUSTERED
X|wms.return_instruction_lines|ix_ri_lines_doc|doc_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.return_instruction_lines|ix_ri_lines_model|model|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.return_instruction_serials|ix_ris_doc_model|doc_id,model|INCLUDE(serial_no,status)|([is_deleted]=(0))|NONCLUSTERED
X|wms.return_instruction_serials|ix_ris_pallet|pallet_id|INCLUDE(doc_id,model,serial_no,status)|([is_deleted]=(0) AND [pallet_id] IS NOT NULL)|NONCLUSTERED
X|wms.return_instruction_serials|ix_ris_pickable|doc_id,pallet_id|INCLUDE(model)|([status]=N'received' AND [is_deleted]=(0))|NONCLUSTERED
X|wms.return_instructions|ix_return_instructions_type_status_date|goods_type,doc_status,expected_date DESC|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.return_instructions|ix_ri_back_status|back_status|INCLUDE(doc_no,goods_type)|([back_status] IS NOT NULL)|NONCLUSTERED
X|wms.return_serial_mismatches|ix_rsm_doc_open|doc_id,scanned_at DESC|INCLUDE(found_status,model,other_doc_no,pallet_id,reason,serial_no)|([is_deleted]=(0) AND [resolved_at] IS NULL)|NONCLUSTERED
X|wms.return_serial_mismatches|ix_rsm_serial|serial_no|INCLUDE(doc_id,reason,scanned_at)|([is_deleted]=(0))|NONCLUSTERED
X|wms.sap_inbound_logs|IX_sap_inbound_logs_doc_no|doc_no,received_at DESC|INCLUDE()||NONCLUSTERED
X|wms.sap_inbound_logs|IX_sap_inbound_logs_received_at|received_at DESC|INCLUDE()||NONCLUSTERED
X|wms.sap_inbound_logs|IX_sap_inbound_logs_si_id|si_id,received_at|INCLUDE()||NONCLUSTERED
X|wms.sap_inbound_logs|IX_sap_inbound_logs_si_no|si_no,received_at|INCLUDE()||NONCLUSTERED
X|wms.shipment_instruction_boxes|IX_si_boxes_line|line_id|INCLUDE(box_id,match_status,picked_at,si_pallet_id)||NONCLUSTERED
X|wms.shipment_instruction_boxes|IX_si_boxes_pallet|si_pallet_id|INCLUDE(box_id,picked_at)|([si_pallet_id] IS NOT NULL)|NONCLUSTERED
X|wms.shipment_instruction_lines|IX_si_lines_model|model|INCLUDE(po_no,qty_cut,qty_required,si_id)||NONCLUSTERED
X|wms.shipment_instruction_lines|IX_si_lines_pl|packing_list_no|INCLUDE(invoice_no)||NONCLUSTERED
X|wms.shipment_instruction_lines|IX_si_lines_si|si_id|INCLUDE(model,packing_list_no,po_no,qty_cut,qty_required)||NONCLUSTERED
X|wms.shipment_instruction_pallets|IX_si_pallets_line|line_id|INCLUDE(box_planned,pallet_id,qty_planned,shipment_status,unit_type)||NONCLUSTERED
X|wms.shipment_instructions|IX_si_si_no|si_no,revision|INCLUDE()||NONCLUSTERED
X|wms.shipment_instructions|IX_si_status_etd|doc_status,etd_date|INCLUDE(category,revision,ship_mode,si_no)|([is_deleted]=(0))|NONCLUSTERED
X|wms.shipment_instructions|IX_si_vanning|vanning_date,forwarder_code|INCLUDE(category,ship_mode,si_no)|([is_deleted]=(0))|NONCLUSTERED
X|wms.shipment_trip_inspections|IX_trip_inspections_trip|trip_id,id DESC|INCLUDE()||NONCLUSTERED
X|wms.shipment_trip_pallets|IX_trip_pallets_pallet|pallet_id|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.shipment_trip_sis|IX_trip_sis_si|si_id|INCLUDE(plt_planned,trip_id)||NONCLUSTERED
X|wms.shipment_trips|IX_trips_planned_arrival|planned_arrival_at|INCLUDE()|([is_deleted]=(0))|NONCLUSTERED
X|wms.stock_events|IX_stock_events_box_at|box_id,event_at DESC|INCLUDE()|([box_id] IS NOT NULL)|NONCLUSTERED
X|wms.stock_events|IX_stock_events_box|box_id,event_at|INCLUDE()|([box_id] IS NOT NULL)|NONCLUSTERED
X|wms.stock_events|IX_stock_events_code_at|event_code,event_at DESC|INCLUDE()||NONCLUSTERED
X|wms.stock_events|IX_stock_events_event_at|event_at|INCLUDE(from_locator_id,pallet_id,related_pallet_id,to_locator_id)||NONCLUSTERED
X|wms.stock_events|IX_stock_events_from_loc|from_locator_id,event_at DESC|INCLUDE()|([from_locator_id] IS NOT NULL)|NONCLUSTERED
X|wms.stock_events|IX_stock_events_pallet_at|pallet_id,event_at DESC|INCLUDE(event_code)||NONCLUSTERED
X|wms.stock_events|IX_stock_events_pallet|pallet_id,subject_type,event_at DESC|INCLUDE()|([pallet_id] IS NOT NULL)|NONCLUSTERED
X|wms.stock_events|IX_stock_events_ref|ref_type,ref_id|INCLUDE()|([ref_type] IS NOT NULL)|NONCLUSTERED
X|wms.stock_events|IX_stock_events_to_loc|to_locator_id,event_at DESC|INCLUDE()|([to_locator_id] IS NOT NULL)|NONCLUSTERED
X|wms.stowage_pallet_boxes|IX_stw_boxes_pallet|stowage_pallet_id|INCLUDE()||NONCLUSTERED
X|wms.stowage_pallets|IX_stw_pallets_plan|plan_id|INCLUDE()||NONCLUSTERED
X|wms.stowage_plan_sis|IX_stw_plan_sis_si|si_id|INCLUDE()||NONCLUSTERED
X|wms.stowage_plans|IX_stw_plans_status_vanning|status,vanning_date|INCLUDE(container_type,forwarder_code,plan_no,ship_mode,unit_kind)|([is_deleted]=(0))|NONCLUSTERED

line
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
F|master.email_config|FK_email_config_event|event_code -> master.email_events.code|NO_ACTION
F|master.email_config|FK_email_config_sub|event_code,sub_code -> master.email_event_subtypes.event_code,sub_code|NO_ACTION
F|master.email_config|FK_email_config_user|user_id -> master.users.id|NO_ACTION
F|master.email_event_subtypes|FK_email_sub_event|event_code -> master.email_events.code|NO_ACTION
F|master.locator_map|fk_map_locator|locator_id -> master.locators.id|NO_ACTION
F|master.locator_map|fk_map_rack|rack_id -> master.racks.id|NO_ACTION
F|master.locators|fk_locators_new_rack|rack_id -> master.racks.id|NO_ACTION
F|master.models|FK_models_category|category_id -> master.categories.code|NO_ACTION
F|master.models|FK_models_suggest_area|suggest_area -> master.warehouse_areas.id|NO_ACTION
F|master.permission_screens|FK_permission_screens_module|module_id -> master.permission_modules.id|NO_ACTION
F|master.permissions|FK_permissions_screen|screen_id -> master.permission_screens.id|NO_ACTION
F|master.racks|fk_racks_area|area_id -> master.warehouse_areas.id|NO_ACTION
F|master.role_permissions|FK_role_permissions_permission|permission_id -> master.permissions.id|NO_ACTION
F|master.role_permissions|FK_role_permissions_role|role_id -> master.roles.id|NO_ACTION
F|master.user_roles|FK_user_roles_role|role_id -> master.roles.id|NO_ACTION
F|master.user_roles|FK_user_roles_user|user_id -> master.users.id|NO_ACTION
F|master.warehouse_areas|FK_warehouse_areas_warehouse_id|warehouse_id -> master.warehouses.id|NO_ACTION
F|master.warehouses|FK__warehouse__creat__65370702|created_by -> master.users.id|NO_ACTION
F|master.warehouses|FK__warehouse__updat__662B2B3B|updated_by -> master.users.id|NO_ACTION
F|wms.balance_docs|fk_balance_count|count_id -> wms.inventory_counts.id|NO_ACTION
F|wms.box_lines|FK_box_lines_box|box_id -> wms.boxes.id|NO_ACTION
F|wms.boxes|FK_lot_boxes_lot|lot_id -> wms.pallets.id|NO_ACTION
F|wms.inventory_count_lines|FK__inventory__count__690797E6|count_id -> wms.inventory_counts.id|NO_ACTION
F|wms.inventory_count_lines|FK__inventory__creat__69FBBC1F|created_by -> master.users.id|NO_ACTION
F|wms.inventory_count_lines|FK__inventory__lot_i__6AEFE058|lot_id -> wms.pallets.id|NO_ACTION
F|wms.inventory_count_lines|FK__inventory__updat__6BE40491|updated_by -> master.users.id|NO_ACTION
F|wms.inventory_count_lines|fk_inventory_count_lines_locator|locator_id -> master.locators.id|NO_ACTION
F|wms.inventory_counts|FK__inventory__confi__6DCC4D03|confirmed_by -> master.users.id|NO_ACTION
F|wms.inventory_counts|FK__inventory__creat__6EC0713C|created_by -> master.users.id|NO_ACTION
F|wms.inventory_counts|FK__inventory__updat__6FB49575|updated_by -> master.users.id|NO_ACTION
F|wms.inventory_counts|FK__inventory__wareh__70A8B9AE|warehouse_id -> master.warehouses.id|NO_ACTION
F|wms.inventory_move_lines|FK__inventory__creat__719CDDE7|created_by -> master.users.id|NO_ACTION
F|wms.inventory_move_lines|FK__inventory__lot_i__72910220|lot_id -> wms.pallets.id|NO_ACTION
F|wms.inventory_move_lines|FK__inventory__move___73852659|move_id -> wms.inventory_moves.id|NO_ACTION
F|wms.inventory_move_lines|FK__inventory__updat__74794A92|updated_by -> master.users.id|NO_ACTION
F|wms.inventory_move_lines|fk_inventory_move_lines_from_locator|from_locator_id -> master.locators.id|NO_ACTION
F|wms.inventory_move_lines|fk_inventory_move_lines_to_locator|to_locator_id -> master.locators.id|NO_ACTION
F|wms.inventory_moves|FK__inventory__confi__7755B73D|confirmed_by -> master.users.id|NO_ACTION
F|wms.inventory_moves|FK__inventory__creat__7849DB76|created_by -> master.users.id|NO_ACTION
F|wms.inventory_moves|FK__inventory__updat__793DFFAF|updated_by -> master.users.id|NO_ACTION
F|wms.pallets|FK_lots_category|category_id -> master.categories.code|NO_ACTION
F|wms.pallets|fk_lots_locator|locator_id -> master.locators.id|NO_ACTION
F|wms.part_card_lineage|FK_part_card_lineage_card|part_card_id -> wms.part_cards.id|NO_ACTION
F|wms.part_card_lineage|FK_part_card_lineage_source|source_part_card_id -> wms.part_cards.id|NO_ACTION
F|wms.part_card_rows|FK_part_card_rows_part_card|part_card_id -> wms.part_cards.id|NO_ACTION
F|wms.return_back_deliveries|fk_rbd_doc|doc_id -> wms.return_instructions.id|NO_ACTION
F|wms.return_back_lines|fk_rbl_doc|doc_id -> wms.return_instructions.id|CASCADE
F|wms.return_back_rounds|fk_rbr_doc|doc_id -> wms.return_instructions.id|CASCADE
F|wms.return_instruction_lines|fk_ri_lines_doc|doc_id -> wms.return_instructions.id|NO_ACTION
F|wms.return_instruction_serials|fk_ris_doc|doc_id -> wms.return_instructions.id|NO_ACTION
F|wms.return_instruction_serials|fk_ris_pallet|pallet_id -> wms.pallets.id|NO_ACTION
F|wms.return_serial_mismatches|fk_rsm_doc|doc_id -> wms.return_instructions.id|NO_ACTION
F|wms.shipment_instruction_boxes|FK_si_boxes_box|box_id -> wms.boxes.id|NO_ACTION
F|wms.shipment_instruction_boxes|FK_si_boxes_line|line_id -> wms.shipment_instruction_lines.id|NO_ACTION
F|wms.shipment_instruction_boxes|FK_si_boxes_pallet|si_pallet_id -> wms.shipment_instruction_pallets.id|NO_ACTION
F|wms.shipment_instruction_lines|FK_si_lines_si|si_id -> wms.shipment_instructions.id|NO_ACTION
F|wms.shipment_instruction_pallets|FK_si_pallets_line|line_id -> wms.shipment_instruction_lines.id|NO_ACTION
F|wms.shipment_instruction_pallets|FK_si_pallets_pallet|pallet_id -> wms.pallets.id|NO_ACTION
F|wms.shipment_instruction_pallets|FK_si_pallets_to_loc|to_locator_id -> master.locators.id|NO_ACTION
F|wms.shipment_instruction_shortages|FK_si_shortages_line|line_id -> wms.shipment_instruction_lines.id|NO_ACTION
F|wms.shipment_instruction_shortages|FK_si_shortages_reason|reason_code -> master.shortage_reasons.code|NO_ACTION
F|wms.shipment_instructions|FK_si_to_area|to_area_id -> master.warehouse_areas.id|NO_ACTION
F|wms.shipment_trip_columns|FK_trip_columns_bottom|bottom_pallet_id -> wms.pallets.id|NO_ACTION
F|wms.shipment_trip_columns|FK_trip_columns_top|top_pallet_id -> wms.pallets.id|NO_ACTION
F|wms.shipment_trip_columns|FK_trip_columns_trip|trip_id -> wms.shipment_trips.id|NO_ACTION
F|wms.shipment_trip_inspections|FK_trip_inspections_trip|trip_id -> wms.shipment_trips.id|NO_ACTION
F|wms.shipment_trip_pallets|FK_trip_pallets_pallet|pallet_id -> wms.pallets.id|NO_ACTION
F|wms.shipment_trip_pallets|FK_trip_pallets_trip|trip_id -> wms.shipment_trips.id|NO_ACTION
F|wms.shipment_trip_photos|FK_trip_photos_pallet|pallet_id -> wms.pallets.id|NO_ACTION
F|wms.shipment_trip_photos|FK_trip_photos_trip|trip_id -> wms.shipment_trips.id|NO_ACTION
F|wms.shipment_trip_sis|FK_trip_sis_si|si_id -> wms.shipment_instructions.id|NO_ACTION
F|wms.shipment_trip_sis|FK_trip_sis_trip|trip_id -> wms.shipment_trips.id|NO_ACTION
F|wms.shipment_trip_stacks|FK_trip_stacks_bottom|bottom_pallet_id -> wms.pallets.id|NO_ACTION
F|wms.shipment_trip_stacks|FK_trip_stacks_top|top_pallet_id -> wms.pallets.id|NO_ACTION
F|wms.shipment_trip_stacks|FK_trip_stacks_trip|trip_id -> wms.shipment_trips.id|NO_ACTION
F|wms.stock_events|FK_stock_events_box|box_id -> wms.boxes.id|NO_ACTION
F|wms.stock_events|FK_stock_events_pallet|pallet_id -> wms.pallets.id|NO_ACTION
F|wms.stowage_columns|FK_stw_columns_container|plan_id,container_index -> wms.stowage_plan_containers.plan_id,container_index|NO_ACTION
F|wms.stowage_columns|FK_stw_columns_plan|plan_id -> wms.stowage_plans.id|NO_ACTION
F|wms.stowage_pallet_boxes|FK_stw_boxes_pallet|stowage_pallet_id -> wms.stowage_pallets.id|NO_ACTION
F|wms.stowage_pallet_boxes|FK_stw_boxes_plan|plan_id -> wms.stowage_plans.id|NO_ACTION
F|wms.stowage_pallet_boxes|FK_stw_boxes_si_box|si_box_id -> wms.shipment_instruction_boxes.id|NO_ACTION
F|wms.stowage_pallet_boxes|FK_stw_boxes_si_line|si_line_id -> wms.shipment_instruction_lines.id|NO_ACTION
F|wms.stowage_pallets|FK_stw_pallets_column|column_id -> wms.stowage_columns.id|NO_ACTION
F|wms.stowage_pallets|FK_stw_pallets_pallet|wms_pallet_id -> wms.pallets.id|NO_ACTION
F|wms.stowage_pallets|FK_stw_pallets_plan|plan_id -> wms.stowage_plans.id|NO_ACTION
F|wms.stowage_pallets|FK_stw_pallets_si|si_id -> wms.shipment_instructions.id|NO_ACTION
F|wms.stowage_plan_containers|FK_stw_containers_plan|plan_id -> wms.stowage_plans.id|NO_ACTION
F|wms.stowage_plan_containers|FK_stw_containers_trip|trip_id -> wms.shipment_trips.id|NO_ACTION
F|wms.stowage_plan_sis|FK_stw_plan_sis_plan|plan_id -> wms.stowage_plans.id|NO_ACTION
F|wms.stowage_plan_sis|FK_stw_plan_sis_si|si_id -> wms.shipment_instructions.id|NO_ACTION

line
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
H|master.email_config|CK_email_config_dept|([department] IS NULL OR ([department]=N'FA' OR [department]=N'OQC' OR [department]=N'VP' OR [department]=N'SCS' OR [department]=N'SEC' OR [department]=N'IT'))
H|master.email_config|CK_email_config_mail|([email] IS NULL OR [email] like N'%_@_%._%')
H|master.email_config|CK_email_config_target|([user_id] IS NOT NULL AND [email] IS NULL OR [user_id] IS NULL AND [email] IS NOT NULL)
H|master.email_config|CK_email_config_type|([recipient_type]=N'BCC' OR [recipient_type]=N'CC' OR [recipient_type]=N'TO')
H|master.email_event_subtypes|CK_email_sub_severity|([severity]=N'info' OR [severity]=N'warning' OR [severity]=N'danger')
H|master.email_events|CK_email_events_module|([module]=N'SHIP' OR [module]=N'RECEIVING' OR [module]=N'OQC' OR [module]=N'INVENTORY' OR [module]=N'SYSTEM')
H|master.locator_map|ck_map_parent|([parent_type]=N'rack' OR [parent_type]=N'area')
H|master.locator_map|ck_map_target_xor|([target_type]=N'rack' AND [rack_id] IS NOT NULL AND [locator_id] IS NULL OR [target_type]=N'locator' AND [locator_id] IS NOT NULL AND [rack_id] IS NULL OR [target_type]=N'zone' AND [rack_id] IS NULL AND [locator_id] 
H|master.locator_map|ck_map_target|([target_type]=N'zone' OR [target_type]=N'locator' OR [target_type]=N'rack')
H|master.locators|ck_locators_new_level|([rack_level] IS NULL OR ([rack_level]=N'B' OR [rack_level]=N'A'))
H|master.locators|ck_locators_new_rack_pos|([rack_id] IS NULL OR [rack_row] IS NOT NULL AND [rack_col] IS NOT NULL)
H|master.models|CK_models_layer_count_le_limit|([layer_count] IS NULL OR [layer_limit] IS NULL OR [layer_count]<=[layer_limit])
H|master.models|CK_models_layer_count|([layer_count] IS NULL OR [layer_count]>(0))
H|master.models|CK_models_layer_limit|([layer_limit] IS NULL OR [layer_limit]>(0))
H|master.models|CK_models_origin|([origin] IS NULL OR ([origin]) collate Latin1_General_BIN2 like '[A-Z][A-Z]')
H|master.models|CK_models_stacking_length|([stacking_length] IS NULL OR [stacking_length]>(0))
H|master.models|CK_models_stacking_width|([stacking_width] IS NULL OR [stacking_width]>(0))
H|master.models|CK_models_suggest_rack_row|([suggest_rack_row] IS NULL OR len([suggest_rack_row])>(0) AND NOT [suggest_rack_row] like '%[^1-4,]%' AND NOT [suggest_rack_row] like ',%' AND NOT [suggest_rack_row] like '%,' AND NOT [suggest_rack_row] like '%,,
H|master.racks|ck_racks_dims|([rows]>(0) AND [cols]>(0))
H|master.shortage_reasons|CK_shortage_reasons_dept|([department]=N'FA' OR [department]=N'OQC')
H|master.users|CK_users_department|([department]='SCS' OR [department]='FA' OR [department]='OQC' OR [department]='SEC' OR [department]='IT')
H|master.warehouse_areas|ck_warehouse_areas_map_type|([map_type]=N'vanning' OR [map_type]=N'receiving' OR [map_type]=N'storing')
H|wms.balance_docs|ck_balance_status|([doc_status]=N'pending' OR [doc_status]=N'processing' OR [doc_status]=N'issued')
H|wms.box_lines|CK_box_lines_carton_qty|([carton_qty] IS NULL OR [carton_qty]>(0))
H|wms.box_lines|CK_box_lines_qty|([qty]>(0))
H|wms.box_lines|CK_box_lines_serial_qty|([serial_no] IS NULL OR [qty]=(1))
H|wms.inventory_count_lines|ck_icl_resolution|([resolution] IS NULL OR ([resolution]=N'count' OR [resolution]=N'system'))
H|wms.pallets|CK_lots_box_count|([detail_level]='box_count' AND [box_count]>=(1) OR [detail_level]<>'box_count')
H|wms.pallets|CK_lots_detail_level|([detail_level]='box_count' OR [detail_level]='box_line' OR [detail_level]='serial')
H|wms.pallets|CK_lots_inspection|([inspection_status]='inspection_exempt' OR [inspection_status]='ng' OR [inspection_status]='pass' OR [inspection_status]='pending_result' OR [inspection_status]='under_inspection' OR [inspection_status]='not_inspected')
H|wms.pallets|CK_lots_lot_no_fmt|([pallet_id] like '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]')
H|wms.pallets|ck_lots_stocky_code|([lot_type]='stocky' AND [stocky_code] IS NOT NULL OR [lot_type]<>'stocky' AND [stocky_code] IS NULL)
H|wms.pallets|CK_lots_type|([lot_type]='stocky' OR [lot_type]='pallet')
H|wms.pallets|CK_pallets_sap_status|([sap_status]>=(0) AND [sap_status]<=(4))
H|wms.part_card_lineage|CK_part_card_lineage_action|([action]='merge' OR [action]='split' OR [action]='edit')
H|wms.production_plans|CK_production_plans_status|([status]=N'planned' OR [status]=N'released' OR [status]=N'producing' OR [status]=N'done')
H|wms.return_back_deliveries|ck_rbd_kind|([kind]=N'pickup' OR [kind]=N'handover')
H|wms.return_back_lines|ck_rbl_qty|([req_qty]>(0))
H|wms.return_back_rounds|ck_rbr_round|([round]>(0))
H|wms.return_instruction_lines|ck_ri_lines_qty|([qty]>(0))
H|wms.return_instruction_serials|ck_ris_status|([status]=N'ng' OR [status]=N'shipped' OR [status]=N'returned' OR [status]=N'at_fa' OR [status]=N'received')
H|wms.return_instructions|ck_return_instructions_goods_type|([goods_type]=N'refurbish' OR [goods_type]=N'rework')
H|wms.return_instructions|ck_return_instructions_status|([doc_status]=N'cancelled' OR [doc_status]=N'completed' OR [doc_status]=N'open')
H|wms.return_instructions|ck_ri_back_status|([back_status] IS NULL OR ([back_status]=N'cancelled' OR [back_status]=N'delivered' OR [back_status]=N'scs_approved' OR [back_status]=N'fa_approved' OR [back_status]=N'fa_requested'))
H|wms.return_serial_mismatches|ck_rsm_reason|([reason]=N'other_doc' OR [reason]=N'wrong_status' OR [reason]=N'not_in_doc')
H|wms.shipment_instruction_boxes|CK_si_boxes_match|([match_status]=N'pending' OR [match_status]=N'matched' OR [match_status]=N'not_found' OR [match_status]=N'ambiguous' OR [match_status]=N'taken')
H|wms.shipment_instruction_boxes|CK_si_boxes_picked|([picked_at] IS NULL OR [box_id] IS NOT NULL AND [match_status]=N'matched' AND [picked_by] IS NOT NULL)
H|wms.shipment_instruction_boxes|CK_si_boxes_src|([assign_source]=N'designated' OR [assign_source]=N'fifo')
H|wms.shipment_instruction_lines|CK_si_lines_cut|([qty_cut] IS NULL AND [cut_at] IS NULL AND [cut_by] IS NULL OR [qty_cut]>(0) AND [qty_cut]<=[qty_required] AND [cut_at] IS NOT NULL AND [cut_by] IS NOT NULL)
H|wms.shipment_instruction_lines|CK_si_lines_qty|([qty_required]>=(0))
H|wms.shipment_instruction_pallets|CK_si_pallets_done|([shipment_status]=N'pending' AND [picked_at] IS NULL AND [skip_reason] IS NULL OR [shipment_status]=N'picked' AND [picked_at] IS NOT NULL AND [skip_reason] IS NULL OR [shipment_status]=N'skipped' AND [
H|wms.shipment_instruction_pallets|CK_si_pallets_fifo|([is_fifo]=(1) OR [approved_at] IS NOT NULL OR [shipment_status]<>N'picked')
H|wms.shipment_instruction_pallets|CK_si_pallets_mode_fifo|([pick_mode]<>N'designated' OR [is_fifo]=(0))
H|wms.shipment_instruction_pallets|CK_si_pallets_mode|([pick_mode]=N'pallet' OR [pick_mode]=N'fifo' OR [pick_mode]=N'designated')
H|wms.shipment_instruction_pallets|CK_si_pallets_qty|([box_planned]>(0) AND [qty_planned]>(0))
H|wms.shipment_instruction_pallets|CK_si_pallets_status|([shipment_status]=N'pending' OR [shipment_status]=N'picked' OR [shipment_status]=N'skipped')
H|wms.shipment_instruction_pallets|CK_si_pallets_unit|([unit_type]=N'pallet' OR [unit_type]=N'box')
H|wms.shipment_instruction_shortages|CK_si_shortages_qty|([qty_short]>(0))
H|wms.shipment_instructions|CK_si_note|([header_note] IS NULL OR isjson([header_note])=(1))
H|wms.shipment_instructions|CK_si_status|([doc_status]=N'cancelled' OR [doc_status]=N'completed' OR [doc_status]=N'picking' OR [doc_status]=N'released')
H|wms.shipment_trip_columns|CK_trip_columns_diff|([top_pallet_id] IS NULL OR [top_pallet_id]<>[bottom_pallet_id])
H|wms.shipment_trip_inspections|CK_trip_inspections_result|([result]=N'fail' OR [result]=N'pass')
H|wms.shipment_trip_photos|CK_trip_photos_slot|([slot_no]>=(1))
H|wms.shipment_trip_photos|CK_trip_photos_unit|([unit_no] IS NULL OR [unit_no]>=(1))
H|wms.shipment_trip_sis|CK_trip_sis_plt|([plt_planned] IS NULL OR [plt_planned]>(0))
H|wms.shipment_trip_stacks|CK_trip_stacks_coc|([coc_no]>=(1))
H|wms.shipment_trip_stacks|CK_trip_stacks_diff|([bottom_pallet_id]<>[top_pallet_id])
H|wms.shipment_trips|CK_trips_driver_id_type|([driver_id_type] IS NULL OR ([driver_id_type]=N'gplx' OR [driver_id_type]=N'cccd'))
H|wms.shipment_trips|CK_trips_sealed_data|([vehicle_type]<>N'container' OR NOT ([status]=N'departed' OR [status]=N'sealed') OR [container_no] IS NOT NULL AND [seal_no] IS NOT NULL)
H|wms.shipment_trips|CK_trips_status|([status]=N'cancelled' OR [status]=N'departed' OR [status]=N'sealed' OR [status]=N'arrived' OR [status]=N'planned')
H|wms.shipment_trips|CK_trips_truck_no_container|([vehicle_type]=N'container' OR [container_no] IS NULL AND [container_size] IS NULL AND [seal_no] IS NULL AND [sealed_at] IS NULL)
H|wms.shipment_trips|CK_trips_vehicle_type|([vehicle_type]=N'motorbike' OR [vehicle_type]=N'truck' OR [vehicle_type]=N'container')
H|wms.stock_events|CK_stock_events_payload|([payload] IS NULL OR isjson([payload])=(1))
H|wms.stock_events|CK_stock_events_subject|(([subject_type]='box' OR [subject_type]='pallet') AND ([subject_type]<>'box' OR [box_id] IS NOT NULL) AND ([subject_type]<>'pallet' OR [pallet_id] IS NOT NULL))
H|wms.stowage_columns|CK_stw_columns_place|([container_index] IS NULL AND [row_no] IS NULL AND [lane_no] IS NULL OR [container_index]>=(0) AND [row_no]>=(0) AND [lane_no] IS NOT NULL)
H|wms.stowage_pallet_boxes|CK_stw_boxes_source|([si_box_id] IS NOT NULL AND [si_line_id] IS NULL AND [carton_seq] IS NULL OR [si_box_id] IS NULL AND [si_line_id] IS NOT NULL AND [carton_seq]>=(1))
H|wms.stowage_pallets|CK_stw_pallets_dims|([length_cm]>(0) AND [width_cm]>(0))
H|wms.stowage_pallets|CK_stw_pallets_tier|([tier]=(2) OR [tier]=(1))
H|wms.stowage_plan_containers|CK_stw_containers_index|([container_index]>=(0))
H|wms.stowage_plan_sis|CK_stw_plan_sis_color|([color] IS NULL OR [color] like '#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]')
H|wms.stowage_plans|CK_stw_plans_base|([base_type]=N'loose' OR [base_type]=N'no_base' OR [base_type]=N'paper' OR [base_type]=N'plastic' OR [base_type]=N'wood')
H|wms.stowage_plans|CK_stw_plans_counts|([placed_columns]>=(0) AND [placed_columns]<=[total_columns])
H|wms.stowage_plans|CK_stw_plans_kind|([unit_kind]=N'LOT' OR [unit_kind]=N'ULD' OR [unit_kind]=N'CONT')
H|wms.stowage_plans|CK_stw_plans_mode|([ship_mode]=N'AIR' OR [ship_mode]=N'LCL' OR [ship_mode]=N'FCL')
H|wms.stowage_plans|CK_stw_plans_saved|([status]<>N'saved' OR [saved_at] IS NOT NULL)
H|wms.stowage_plans|CK_stw_plans_status|([status]=N'saved' OR [status]=N'draft' OR [status]=N'not_started')

line
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
G|wms.trg_shipment_instruction_lines_sync_dev|wms.shipment_instruction_lines|dong=13
G|wms.trg_shipment_instructions_sync_dev|wms.shipment_instructions|dong=14
N|master.fn_email_recipients|TABLE|dong=45
N|wms.fn_stowage_si_boxes|TABLE|dong=276
P|master.usp_stock_event_types_get|dong=51
P|wms.usp_box_history_get|dong=109
P|wms.usp_oqc_get_locations|dong=58
P|wms.usp_oqc_return|dong=111
P|wms.usp_oqc_sample|dong=67
P|wms.usp_oqc_update_status_fg|dong=74
P|wms.usp_oqc_update_status_sp|dong=77
P|wms.usp_pallet_events_brief|dong=36
P|wms.usp_pallet_history_get|dong=74
P|wms.usp_partcard_insert|dong=32
P|wms.usp_partcard_mark_printed|dong=14
P|wms.usp_si_trace_by_serial|dong=97
P|wms.usp_stock_event_add|dong=63
P|wms.usp_stocktake_create_morning|dong=120
P|wms.usp_sync_shipment_to_dev|dong=125
V|wms.v_stowage_plan_boxes|dong=18

line
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
R|master.api_keys|2
R|master.categories|20
R|master.configs|1
R|master.email_config|0
R|master.email_event_subtypes|29
R|master.email_events|10
R|master.locator_map|1016
R|master.locators|2026
R|master.models_bak_20261012|1170
R|master.models|1176
R|master.pda_app_versions|36
R|master.permission_modules|7
R|master.permission_screens|34
R|master.permissions|158
R|master.racks|43
R|master.role_permissions|407
R|master.roles|7
R|master.shortage_reasons|5
R|master.stock_event_types|42
R|master.user_roles|64
R|master.users|64
R|master.warehouse_areas|11
R|master.warehouses|4
R|wms.balance_docs|0
R|wms.box_lines|166636
R|wms.boxes|44124
R|wms.inventory_count_lines|20414
R|wms.inventory_counts|11
R|wms.inventory_move_lines|0
R|wms.inventory_moves|0
R|wms.pallets|3743
R|wms.part_card_lineage|175
R|wms.part_card_rows|3210
R|wms.part_cards|7072
R|wms.production_plans|0
R|wms.return_back_deliveries|0
R|wms.return_back_lines|0
R|wms.return_back_rounds|0
R|wms.return_instruction_lines|0
R|wms.return_instruction_serials|0
R|wms.return_instructions|0
R|wms.return_serial_mismatches|0
R|wms.sap_import_error_log|0
R|wms.sap_inbound_logs|266
R|wms.shipment_instruction_boxes|0
R|wms.shipment_instruction_lines|1300
R|wms.shipment_instruction_pallets|0
R|wms.shipment_instruction_shortages|0
R|wms.shipment_instructions|155
R|wms.shipment_trip_columns|0
R|wms.shipment_trip_inspections|0
R|wms.shipment_trip_pallets|0
R|wms.shipment_trip_photos|0
R|wms.shipment_trip_sis|41
R|wms.shipment_trip_stacks|0
R|wms.shipment_trips|41
R|wms.stock_events|63526
R|wms.stowage_columns|16
R|wms.stowage_pallet_boxes|108
R|wms.stowage_pallets|32
R|wms.stowage_plan_containers|1
R|wms.stowage_plan_sis|1
R|wms.stowage_plans|1
R|wms.sync_queue_dev|39

 
### HET. Neu ban can them than cua view/function/procedure thi
### chay export_schema_swms.sql (xuat nguyen van dinh nghia).

Completion time: 2026-11-18T13:46:59.9797582+07:00
