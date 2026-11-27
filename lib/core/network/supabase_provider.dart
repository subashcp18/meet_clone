import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';

part 'supabase_provider.g.dart';

@Riverpod(keepAlive: true)
bool useMockApi(Ref ref) => AppEnv.useMockApi;

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;
