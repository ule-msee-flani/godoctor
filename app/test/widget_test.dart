// Smoke test: the app boots to the "Supabase isn't configured" guard screen
// when .env has placeholder credentials (the default checked-out state).
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:godoctor_app/main.dart';

void main() {
  testWidgets('renders without throwing', (WidgetTester tester) async {
    // main() normally loads this before runApp(); replicate that here since
    // the test drives GoDoctorApp directly.
    dotenv.testLoad(fileInput: 'SUPABASE_URL=\nSUPABASE_ANON_KEY=\n');

    await tester.pumpWidget(const GoDoctorApp());
    await tester.pump();
    expect(find.byType(GoDoctorApp), findsOneWidget);
  });
}
