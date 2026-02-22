// lib/presentation/pages/home/tabs/areas/areas_model_assets.dart
enum UserSex { male, female }

class AreasModelAssets {
  static String baseImage(UserSex sex) {
    return sex == UserSex.male
        ? 'assets/models/male/man.png'
        : 'assets/models/female/woman.png';
  }

  static String hitmapSvg(UserSex sex) {
    return sex == UserSex.male
        ? 'assets/models/male/man_svg.svg'
        : 'assets/models/female/woman_svg.svg';
  }
}
