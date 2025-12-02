class UserModel {
  final String id;
  final String name;
  final String email;
  final String nickname;
  final String profileImage;
  final String? birthday;
  final String? age;
  final String? gender;
  final String? mobile;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.nickname,
    required this.profileImage,
    this.birthday,
    this.age,
    this.gender,
    this.mobile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      nickname: json['nickname'] ?? '',
      profileImage: json['profileImage'] ?? '',
      birthday: json['birthday'],
      age: json['age'],
      gender: json['gender'],
      mobile: json['mobile'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'nickname': nickname,
      'profileImage': profileImage,
      'birthday': birthday,
      'age': age,
      'gender': gender,
      'mobile': mobile,
    };
  }

  // 사용자 정보 업데이트를 위한 copyWith 메서드
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? nickname,
    String? profileImage,
    String? birthday,
    String? age,
    String? gender,
    String? mobile,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      profileImage: profileImage ?? this.profileImage,
      birthday: birthday ?? this.birthday,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      mobile: mobile ?? this.mobile,
    );
  }
}