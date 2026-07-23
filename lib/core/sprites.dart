/// Catalogue of every sliced sprite used by the game.
///
/// Indices map to the reading order produced by `tool/slice_sprites.dart`
/// (row-major, left→right, top→bottom).
class Sprites {
  Sprites._();

  static const String _chickens = 'assets/sprites/chickens';
  static const String _eggs = 'assets/sprites/eggs';
  static const String _baskets = 'assets/sprites/baskets';
  static const String _coins = 'assets/sprites/coins';
  static const String _collectibles = 'assets/sprites/collectibles';
  static const String _decorative = 'assets/sprites/decorative';
  static const String _fences = 'assets/sprites/fences';
  static const String _obstacles = 'assets/sprites/obstacles';

  static String chicken(int i) => '$_chickens/$i.png';
  static String egg(int i) => '$_eggs/$i.png';
  static String basket(int i) => '$_baskets/$i.png';
  static String coin(int i) => '$_coins/$i.png';
  static String collectible(int i) => '$_collectibles/$i.png';
  static String decorative(int i) => '$_decorative/$i.png';
  static String fence(int i) => '$_fences/$i.png';
  static String obstacle(int i) => '$_obstacles/$i.png';

  /// The 8 chicken skins, in slice order.
  static const List<ChickenSkin> skins = [
    ChickenSkin(0, 'Snowy', 'White farmhouse hen', 0),
    ChickenSkin(1, 'Cocoa', 'Warm brown hen', 120),
    ChickenSkin(2, 'Sunny', 'Golden feathered hen', 260),
    ChickenSkin(3, 'Onyx', 'Sleek midnight hen', 320),
    ChickenSkin(4, 'Speckle', 'Playful spotted hen', 380),
    ChickenSkin(5, 'Fluffy', 'Soft beige hen', 450),
    ChickenSkin(6, 'Chick', 'Tiny golden chick', 520),
    ChickenSkin(7, 'Royal', 'Festive ribboned hen', 700),
  ];

  /// Small egg icons carried by chickens.
  static const int eggWhite = 0;
  static const int eggGold = 4;
  static const int eggBlue = 7;

  /// A big open basket (with handles) used as the level goal.
  static const int goalBasket = 10;

  /// Front-facing coin for pickups / HUD.
  static const int coinFace = 0;
  static const int coinEgg = 3;

  /// Obstacles selected for gameplay (clean, readable silhouettes).
  static const List<int> obstacleSet = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 15, 24, 25];

  /// Roadside decorations.
  static const List<int> decorSet = [0, 1, 2, 3, 12, 13, 20, 21, 22, 39, 40, 41];

  /// Gate sprites (fences with a clear frame) used for requirement gates.
  static const List<int> gateSet = [0, 1, 4, 5];
}

class ChickenSkin {
  final int index;
  final String name;
  final String description;
  final int price;
  const ChickenSkin(this.index, this.name, this.description, this.price);
}
