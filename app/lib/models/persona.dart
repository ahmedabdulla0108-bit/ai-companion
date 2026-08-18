class Persona {
  final String id, name, description, greeting;
  const Persona({required this.id, required this.name, required this.description, required this.greeting});
  factory Persona.fromJson(Map<String, dynamic> j) => Persona(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        greeting: j['greeting'] as String? ?? '',
      );
}
