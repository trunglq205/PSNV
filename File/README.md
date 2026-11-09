Launching lib\main.dart on TC21 in debug mode...
Running Gradle task 'assembleDevDebug'...
lib/features/return_instruction/presentation/return_receive_page.dart:136:62: Error: The argument type 'ReturnGoodsType' can't be assigned to the parameter type 'String?'.
 - 'ReturnGoodsType' is from 'package:swms_finish_goods/features/return_instruction/domain/entities/return_instruction_entities.dart' ('lib/features/return_instruction/domain/entities/return_instruction_entities.dart').
    final badge = QrLabelData.badgeForDisposition(result.doc.goodsType);
                                                             ^
lib/features/return_instruction/presentation/return_back_deliver_page.dart:312:55: Error: The getter 'valueOrNull' isn't defined for the type 'AsyncValue<List<BackRemainModel>>'.
 - 'AsyncValue' is from 'package:riverpod/src/framework.dart' ('/C:/Users/70R2895/AppData/Local/Pub/Cache/hosted/pub.dev/riverpod-3.3.2/lib/src/framework.dart').
 - 'List' is from 'dart:core'.
 - 'BackRemainModel' is from 'package:swms_finish_goods/features/return_instruction/domain/entities/return_back_entities.dart' ('lib/features/return_instruction/domain/entities/return_back_entities.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'valueOrNull'.
    final rows = ref.watch(backRemainProvider(docId)).valueOrNull ??
                                                      ^^^^^^^^^^^
lib/features/return_instruction/presentation/return_back_deliver_page.dart:489:59: Error: The getter 'valueOrNull' isn't defined for the type 'AsyncValue<List<BackDelivery>>'.
 - 'AsyncValue' is from 'package:riverpod/src/framework.dart' ('/C:/Users/70R2895/AppData/Local/Pub/Cache/hosted/pub.dev/riverpod-3.3.2/lib/src/framework.dart').
 - 'List' is from 'dart:core'.
 - 'BackDelivery' is from 'package:swms_finish_goods/features/return_instruction/domain/entities/return_back_entities.dart' ('lib/features/return_instruction/domain/entities/return_back_entities.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'valueOrNull'.
    final rows = ref.watch(backDeliveriesProvider(docId)).valueOrNull ??
                                                          ^^^^^^^^^^^
Target kernel_snapshot_program failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildDevDebug'.
> Process 'command 'D:\0.TrungLQ\flutter\flutter_windows_3.22.0-stable\flutter\bin\flutter.bat'' finished with non-zero exit value 1

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.

BUILD FAILED in 26s
Error: Gradle task assembleDevDebug failed with exit code 1
