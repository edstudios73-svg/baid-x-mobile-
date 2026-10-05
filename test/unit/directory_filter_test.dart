import 'package:flutter_test/flutter_test.dart';

import 'package:baid_x_mobile/features/account_type/domain/role_categories.dart';
import 'package:baid_x_mobile/features/directory/data/directory_repository.dart';
import 'package:baid_x_mobile/features/directory/presentation/directory_filters.dart';

DirectoryMember _m(String group, String name, {String? cat, String? region}) =>
    DirectoryMember(group: group, kind: 'worker', id: name, name: name, tag: '', place: '', desc: '', stats: const [], catId: cat, region: region);

void main() {
  final all = [
    _m('professionals', 'Kwame', cat: jobCategories.first.id, region: 'Greater Accra'),
    _m('professionals', 'Esi', cat: jobCategories[1].id, region: 'Ashanti Region'),
    _m('companies', 'Ama Builders', cat: 'construction', region: 'Greater Accra'),
  ];

  test('the filter type wins over the chip, then category and region narrow it', () {
    expect(applyDirFilter(all, 'all', const DirFilter(), '').length, 3);
    expect(applyDirFilter(all, 'companies', const DirFilter(type: 'professionals'), '').map((m) => m.name), ['Kwame', 'Esi']);
    expect(applyDirFilter(all, 'all', DirFilter(type: 'professionals', cat: jobCategories.first), '').map((m) => m.name), ['Kwame']);
    expect(applyDirFilter(all, 'all', const DirFilter(region: 'Ashanti'), '').map((m) => m.name), ['Esi']); // "Region" suffix ignored
    expect(applyDirFilter(all, 'all', const DirFilter(), 'ama').map((m) => m.name), ['Ama Builders']);
  });

  test('categories follow the chosen type', () {
    expect(DirFilter.categoriesFor('companies'), industries);
    expect(DirFilter.categoriesFor('all'), isEmpty);
    expect(const DirFilter(region: 'Volta').active, isTrue);
  });
}
