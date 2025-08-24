import 'package:mobx/mobx.dart';
part 'bottom_navigation_bar_store.g.dart';

class BottomNavigationBarStore = _BottomNavigationBarStore
    with _$BottomNavigationBarStore;

abstract class _BottomNavigationBarStore with Store {
  @observable
  int _currentIndex = 0;

  get currentIndex => _currentIndex;

  @action
  setCurrentIndex(int index) {
    _currentIndex = index;
  }
}
