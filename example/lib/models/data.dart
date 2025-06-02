import 'models.dart';

final User user_0 = User(
  name: const Name(first: 'Yo', last: ''),
  avatarUrl: 'assets/avatar_1.png',
  lastActive: DateTime.now(),
);
final User user_1 = User(
  name: const Name(first: 'To', last: 'Fu'),
  avatarUrl: 'assets/avatar_2.png',
  lastActive: DateTime.now().subtract(const Duration(minutes: 10)),
);
final User user_2 = User(
  name: const Name(first: 'So', last: 'Duri'),
  avatarUrl: 'assets/avatar_3.png',
  lastActive: DateTime.now().subtract(const Duration(minutes: 20)),
);
final User user_3 = User(
  name: const Name(first: 'Lily', last: 'MacDonald'),
  avatarUrl: 'assets/avatar_4.png',
  lastActive: DateTime.now().subtract(const Duration(hours: 2)),
);
final User user_4 = User(
  name: const Name(first: 'Ziad', last: 'Aouad'),
  avatarUrl: 'assets/avatar_5.png',
  lastActive: DateTime.now().subtract(const Duration(hours: 6)),
);

final List<Email> emails = [
  Email(
    sender: user_1,
    recipients: [],
    subject: 'Pescado tofu',
    content: '¿Has estado ocupado últimamente? Anoche fui a tu restaurante favorito y pedí su especialidad de pescado tofu. Mientras lo comía, pensé en ti.',
  ),
  Email(
    sender: user_2,
    recipients: [],
    subject: 'Club de cena',
    content:
    'Creo que ya es hora de que probemos ese nuevo restaurante de fideos en el centro que no usa menús. ¿Alguien tiene otras sugerencias para el club de cena esta semana? Me intriga mucho esta idea de un restaurante donde nadie puede pedir por sí mismo — podría ser divertido, o terrible, o ambas cosas :)\n\nSo',
  ),
  Email(
    sender: user_3,
    recipients: [],
    subject: 'Este programa de comida es para ti',
    content:
    'Ping— te encantaría este nuevo programa de comida que empecé a ver. Está producido por una baterista tailandesa que empezó a hacerse conocida por la increíble comida vegana que siempre llevaba a los conciertos.',
    attachments: [const Attachment(url: 'assets/thumbnail_1.png')],
  ),
  Email(
    sender: user_4,
    recipients: [],
    subject: '¿Voluntario como EMT conmigo?',
    content:
    '¿Qué piensas sobre entrenar para ser técnicos de emergencias médicas voluntarios? Podríamos hacerlo juntos como apoyo moral. ¿Lo piensas?',
  ),
];

final List<Email> replies = [
  Email(
    sender: user_2,
    recipients: [user_3, user_2],
    subject: 'Club de cena',
    content:
    'Creo que ya es hora de que probemos ese nuevo restaurante de fideos en el centro que no usa menús. ¿Alguien tiene otras sugerencias para el club de cena esta semana? Me intriga mucho esta idea de un restaurante donde nadie puede pedir por sí mismo — podría ser divertido, o terrible, o ambas cosas :)\n\nSo',
  ),
  Email(
    sender: user_0,
    recipients: [user_3, user_2],
    subject: 'Club de cena',
    content:
    '¡Sí! ¡Había olvidado ese lugar! Definitivamente estoy dispuesto a arriesgarme esta semana y ceder el control a este misterioso chef de fideos. Aunque me pregunto qué pasa si tienes alergias. Por suerte ninguno de nosotros tiene, si no estaría algo preocupado.\n\nEsto va a estar genial. ¿Nos vemos todos a la hora de siempre?',
  ),
];
