import 'package:flutter_test/flutter_test.dart';
import 'package:carnet_vol/services/photos_link.dart';

void main() {
  test('searchQuery formats the date as dd-mm-yyyy', () {
    expect(PhotosLink.searchQuery(DateTime(2026, 9, 22)), '22-09-2026');
    expect(PhotosLink.searchQuery(DateTime(2025, 3, 7)), '07-03-2025');
  });
}
