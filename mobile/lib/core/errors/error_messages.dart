class ErrorMessages {
  static String getKyrgyzMessage(String? errorCode, [String? fallback]) {
    switch (errorCode) {
      case 'LOCATION_OUTSIDE_SCHOOL':
        return 'Сиз мектептин аймагынан тышкарысыз. Мектепке жакындап кайра аракет кылыңыз.';
      case 'LOCATION_ACCURACY_TOO_LOW':
        return 'GPS тактыгы жетишсиз. Ачык жерге чыгып же геопозицияны кайра күйгүзүңүз.';
      case 'LOCATION_REQUIRED':
        return 'Келүү-кетүүнү каттоо үчүн геолокацияга уруксат керек.';
      case 'QR_INVALID':
        return 'Туура эмес QR-код сканерленди. Мектептин расмий QR-кодун сканерлеңиз.';
      case 'QR_EXPIRED':
        return 'Бул QR-коддун мөөнөтү бүткөн. Мектеп администрациясына кайрылыңыз.';
      case 'QR_DISABLED':
        return 'Бул QR-код убактылуу өчүрүлгөн.';
      case 'QR_WRONG_SCHOOL':
        return 'Бул QR-код башка мектепке таандык.';
      case 'ALREADY_CHECKED_IN':
        return 'Сиз бүгүн келүүңүздү каттагансыз.';
      case 'ALREADY_CHECKED_OUT':
        return 'Сиз бүгүн кетүүңүздү каттагансыз.';
      case 'NO_CHECK_IN_FOUND':
        return 'Кетүүнү каттоо үчүн адегенде келүүнү (Check-in) каттоо керек.';
      case 'NO_SCHEDULE':
        return 'Бүгүнкү күнгө иш графиги табылган жок.';
      case 'DAY_OFF':
        return 'Бүгүн сизде дем алыш күн.';
      case 'INVALID_CREDENTIALS':
        return 'Логин же сырсөз туура эмес.';
      case 'USER_INACTIVE':
      case 'TEACHER_INACTIVE':
        return 'Сиздин аккаунтуңуз активдүү эмес. Администраторго кайрылыңыз.';
      case 'TOKEN_EXPIRED':
        return 'Сессиянын мөөнөтү бүттү. Кайра кириңиз.';
      case 'PERMISSION_DENIED':
        return 'Бул аракетти аткарууга уруксат жок.';
      case 'NETWORK_ERROR':
        return 'Интернет байланышы жок же сервер жеткиликсиз.';
      default:
        return fallback ?? 'Күтүлбөгөн ката кетти. Кайра аракет кылыңыз.';
    }
  }
}
