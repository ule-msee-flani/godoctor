import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/utils/app_assets.dart';

void main() {
  setUp(
    () => AppAssets.debugSetBundled([
      'assets/images/banners/banner_doctor.jpg',
      'assets/images/specialties/ent.PNG',
      'assets/video/splash.mp4',
    ]),
  );

  test('finds an image whatever extension it was saved with', () {
    expect(
      AppAssets.find('assets/images/banners/banner_doctor'),
      'assets/images/banners/banner_doctor.jpg',
    );
  });

  test('accepts a path that already has an extension', () {
    expect(
      AppAssets.find('assets/images/banners/banner_doctor.png'),
      'assets/images/banners/banner_doctor.jpg',
    );
  });

  test('is case-insensitive and returns the real path', () {
    expect(
      AppAssets.find('assets/images/specialties/ent'),
      'assets/images/specialties/ent.PNG',
    );
  });

  test('returns null when nothing was supplied', () {
    expect(AppAssets.find('assets/images/specialties/heart'), isNull);
  });

  test('findFirst picks the first candidate that exists', () {
    expect(
      AppAssets.findFirst([
        'assets/images/specialties/ent_hero',
        'assets/images/specialties/ent',
      ]),
      'assets/images/specialties/ent.PNG',
    );
  });

  test('video lookup uses video extensions', () {
    expect(
      AppAssets.findVideo('assets/video/splash'),
      'assets/video/splash.mp4',
    );
    expect(AppAssets.find('assets/video/splash'), isNull);
  });
}
