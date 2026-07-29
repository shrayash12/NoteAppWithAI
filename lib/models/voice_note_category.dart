import 'package:flutter/material.dart';

/// A voice note category used by Smart Voice Note's offline classifier to
/// route transcribed recordings into the right folder. Keyword lists cover
/// all 11 languages the app supports (see AppLocalizations.supportedLocales)
/// so classification works no matter which language you record in.
class VoiceNoteCategory {
  final String id;
  final String displayName;
  final IconData icon;
  final Color color;
  final String folderId;
  final List<String> keywords;

  const VoiceNoteCategory({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.color,
    required this.folderId,
    required this.keywords,
  });

  static const meeting = VoiceNoteCategory(
    id: 'meeting',
    displayName: 'Meeting',
    icon: Icons.groups_outlined,
    color: Color(0xFF3B82F6),
    folderId: 'meeting',
    keywords: [
      'meeting', 'agenda', 'attendees', 'minutes', 'discussed', 'action item', 'follow up', 'standup', 'sync up',
      'मीटिंग', 'बैठक', 'एजेंडा',
      'reunión', 'asistentes',
      'réunion', "ordre du jour", 'participants',
      'besprechung', 'sitzung', 'tagesordnung',
      'اجتماع', 'جدول الأعمال',
      '会议', '议程',
      '会議', '議題',
      'reunião', 'pauta',
      'riunione', "ordine del giorno",
      '회의', '안건',
    ],
  );

  static const todo = VoiceNoteCategory(
    id: 'todo',
    displayName: 'To-Do',
    icon: Icons.check_circle_outline,
    color: Color(0xFF10B981),
    folderId: 'todo',
    keywords: [
      'to-do', 'todo', 'need to', 'remember to', "don't forget", 'must do', 'task list', 'reminder to',
      'करना है', 'याद रखना', 'टू डू',
      'tarea pendiente', 'recordar que',
      'à faire', 'ne pas oublier',
      'zu erledigen', 'nicht vergessen',
      'يجب أن أفعل', 'لا تنسى',
      '待办', '记得要',
      'やること', '忘れずに',
      'tarefa pendente', 'lembrar de',
      'da fare', 'ricordare di',
      '할 일', '잊지 말고',
    ],
  );

  static const grocery = VoiceNoteCategory(
    id: 'grocery',
    displayName: 'Grocery',
    icon: Icons.local_grocery_store_outlined,
    color: Color(0xFF84CC16),
    folderId: 'grocery',
    keywords: [
      'grocery', 'groceries', 'supermarket', 'grocery store', 'grocery list', 'milk', 'eggs', 'bread', 'vegetables', 'fruits', 'produce',
      'किराना', 'राशन', 'सब्जी',
      'supermercado', 'comestibles',
      'épicerie', 'courses',
      'lebensmittel', 'supermarkt', 'einkaufsliste',
      'بقالة', 'سوبر ماركت',
      '杂货', '超市',
      '食料品', 'スーパー',
      'mercearia', 'supermercado',
      'alimentari', 'supermercato',
      '식료품', '마트',
    ],
  );

  static const shopping = VoiceNoteCategory(
    id: 'shopping',
    displayName: 'Shopping',
    icon: Icons.shopping_cart_outlined,
    color: Color(0xFFF59E0B),
    folderId: 'shopping',
    keywords: [
      'buy', 'shopping', 'purchase', 'clothes', 'shirt', 'shoes', 'toy', 'toys', 'book', 'order online', 'mall', 'gift', 'amazon',
      'खरीदारी', 'खरीदना', 'शॉपिंग',
      'comprar', 'compras', 'ropa',
      'acheter', 'achats', 'vêtements',
      'kaufen', 'einkaufen', 'kleidung',
      'شراء', 'تسوق', 'ملابس',
      '购买', '购物', '衣服',
      '買う', '買い物', '服',
      'comprar roupas',
      'comprare', 'shopping', 'vestiti',
      '구매', '쇼핑', '옷',
    ],
  );

  static const health = VoiceNoteCategory(
    id: 'health',
    displayName: 'Health',
    icon: Icons.favorite_outline,
    color: Color(0xFFEF4444),
    folderId: 'health',
    keywords: [
      'doctor', 'appointment', 'medication', 'symptom', 'prescription', 'hospital', 'clinic', 'dose', 'diagnosis',
      'डॉक्टर', 'दवा', 'अस्पताल',
      'médico', 'hospital',
      'médecin', 'hôpital',
      'arzt', 'krankenhaus', 'medikament',
      'طبيب', 'مستشفى', 'دواء',
      '医生', '医院',
      '医者', '病院', '薬',
      'médico', 'remédio',
      'medico', 'ospedale', 'farmaco',
      '의사', '병원', '약',
    ],
  );

  static const travel = VoiceNoteCategory(
    id: 'travel',
    displayName: 'Travel',
    icon: Icons.flight_outlined,
    color: Color(0xFF06B6D4),
    folderId: 'travel',
    keywords: [
      'flight', 'trip', 'travel', 'hotel', 'itinerary', 'vacation', 'booking', 'passport', 'airport',
      'यात्रा', 'फ्लाइट', 'ट्रिप',
      'vuelo', 'viaje',
      'vol', 'voyage',
      'flug', 'reise',
      'رحلة', 'طيران', 'فندق',
      '航班', '旅行',
      'フライト', '旅行', 'ホテル',
      'voo', 'viagem',
      'volo', 'viaggio',
      '비행기', '여행', '호텔',
    ],
  );

  static const study = VoiceNoteCategory(
    id: 'study',
    displayName: 'Study',
    icon: Icons.school_outlined,
    color: Color(0xFF8B5CF6),
    folderId: 'study',
    keywords: [
      'study', 'exam', 'lecture', 'homework', 'assignment', 'chapter', 'professor', 'quiz', 'syllabus',
      'पढ़ाई', 'परीक्षा', 'क्लास',
      'estudiar', 'examen',
      'étudier', 'cours',
      'lernen', 'prüfung', 'vorlesung',
      'دراسة', 'امتحان', 'محاضرة',
      '学习', '考试',
      '勉強', '試験', '講義',
      'estudar', 'aula',
      'studiare', 'esame', 'lezione',
      '공부', '시험', '강의',
    ],
  );

  static const work = VoiceNoteCategory(
    id: 'work',
    displayName: 'Work',
    icon: Icons.work_outline,
    color: Color(0xFF3B82F6),
    folderId: 'work',
    keywords: [
      'deadline', 'client', 'boss', 'office', 'colleague', 'report', 'presentation', 'quarterly',
      'काम', 'ऑफिस', 'डेडलाइन',
      'trabajo', 'oficina', 'jefe',
      'travail', 'bureau', 'patron',
      'arbeit', 'büro', 'chef',
      'عمل', 'مكتب', 'رئيس',
      '工作', '办公室',
      '仕事', 'オフィス', '上司',
      'trabalho', 'escritório', 'chefe',
      'lavoro', 'ufficio', 'capo',
      '업무', '사무실', '상사',
    ],
  );

  static const finance = VoiceNoteCategory(
    id: 'finance',
    displayName: 'Finance',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF059669),
    folderId: 'finance',
    keywords: [
      'budget', 'expense', 'payment', 'invoice', 'bank', 'salary', 'bill', 'tax', 'investment',
      'पैसा', 'बजट', 'बैंक',
      'presupuesto', 'banco', 'dinero',
      'budget', 'banque', 'argent',
      'budget', 'bank', 'geld',
      'ميزانية', 'بنك', 'مال',
      '预算', '银行',
      '予算', '銀行', 'お金',
      'orçamento', 'banco', 'dinheiro',
      'budget', 'banca', 'soldi',
      '예산', '은행', '돈',
    ],
  );

  static const journal = VoiceNoteCategory(
    id: 'journal',
    displayName: 'Journal',
    icon: Icons.book_outlined,
    color: Color(0xFFD946EF),
    folderId: 'journal',
    keywords: [
      'today i', 'feeling', 'diary', 'journal', 'grateful', 'reflect', 'my mood', 'i felt',
      'आज मैंने', 'डायरी', 'महसूस',
      'hoy yo', 'diario',
      "aujourd'hui je", 'journal intime',
      'heute habe ich', 'tagebuch',
      'اليوم أنا', 'يوميات',
      '今天我', '日记',
      '今日私は', '日記',
      'hoje eu', 'diário',
      'oggi io', 'diario',
      '오늘 나는', '일기',
    ],
  );

  static const ideas = VoiceNoteCategory(
    id: 'ideas',
    displayName: 'Ideas',
    icon: Icons.lightbulb_outline,
    color: Color(0xFFEAB308),
    folderId: 'ideas',
    keywords: [
      'idea', 'what if', 'concept', 'brainstorm', 'innovation', 'occurred to me',
      'आइडिया', 'विचार', 'सोचा',
      'idea', 'qué tal si',
      'idée', 'et si',
      'idee', 'was wäre wenn',
      'فكرة', 'ماذا لو',
      '想法', '如果',
      'アイデア', 'もし',
      'ideia', 'e se',
      'idea', 'e se',
      '아이디어', '만약',
    ],
  );

  static const recipe = VoiceNoteCategory(
    id: 'recipe',
    displayName: 'Recipe',
    icon: Icons.restaurant_outlined,
    color: Color(0xFFF97316),
    folderId: 'recipe',
    keywords: [
      'recipe', 'ingredients', 'cook', 'bake', 'cup of', 'tablespoon', 'teaspoon', 'oven', 'preheat',
      'रेसिपी', 'बनाना', 'पकाना',
      'receta', 'ingredientes', 'cocinar',
      'recette', 'ingrédients', 'cuisiner',
      'rezept', 'zutaten', 'kochen',
      'وصفة', 'مكونات', 'طبخ',
      '食谱', '烹饪',
      'レシピ', '材料', '料理',
      'receita', 'ingredientes', 'cozinhar',
      'ricetta', 'ingredienti', 'cucinare',
      '레시피', '재료', '요리',
    ],
  );

  static const fitness = VoiceNoteCategory(
    id: 'fitness',
    displayName: 'Fitness',
    icon: Icons.fitness_center_outlined,
    color: Color(0xFFDC2626),
    folderId: 'fitness',
    keywords: [
      'workout', 'gym', 'exercise', 'reps', 'sets', 'cardio', 'training', 'muscle', 'run today',
      'वर्कआउट', 'जिम', 'एक्सरसाइज',
      'entrenamiento', 'gimnasio', 'ejercicio',
      'entraînement', 'gym', 'exercice',
      'training', 'fitnessstudio', 'übung',
      'تمرين', 'صالة رياضية',
      '锻炼', '健身房',
      'ワークアウト', 'ジム', '運動',
      'treino', 'academia', 'exercício',
      'allenamento', 'palestra', 'esercizio',
      '운동', '헬스장', '훈련',
    ],
  );

  static const personal = VoiceNoteCategory(
    id: 'personal',
    displayName: 'Personal',
    icon: Icons.person_outline,
    color: Color(0xFFEC4899),
    folderId: 'personal',
    keywords: [
      'my family', 'my friend', 'at home', 'relationship', 'personal life',
      'परिवार', 'दोस्त', 'घर पर',
      'mi familia', 'mi amigo', 'en casa',
      'ma famille', 'mon ami', "à la maison",
      'meine familie', 'mein freund', 'zuhause',
      'عائلتي', 'صديقي', 'في المنزل',
      '我的家人', '在家',
      '私の家族', '家で',
      'minha família', 'meu amigo', 'em casa',
      'la mia famiglia', 'il mio amico', 'a casa',
      '가족', '친구', '집에서',
    ],
  );

  static const project = VoiceNoteCategory(
    id: 'project',
    displayName: 'Project',
    icon: Icons.folder_special_outlined,
    color: Color(0xFF6366F1),
    folderId: 'project',
    keywords: [
      'project', 'milestone', 'sprint', 'deliverable', 'roadmap', 'project plan', 'kickoff',
      'प्रोजेक्ट', 'मील का पत्थर',
      'proyecto', 'hito', 'entregable',
      'projet', 'jalon', 'livrable',
      'projekt', 'meilenstein',
      'مشروع', 'معلم',
      '项目', '里程碑',
      'プロジェクト', 'マイルストーン',
      'projeto', 'marco', 'entrega',
      'progetto', 'traguardo', 'consegna',
      '프로젝트', '마일스톤',
    ],
  );

  static const quickNote = VoiceNoteCategory(
    id: 'quick_note',
    displayName: 'Quick Note',
    icon: Icons.mic_none_outlined,
    color: Color(0xFF6B7280),
    folderId: 'quick_note',
    keywords: [],
  );

  /// All categories considered during classification, in priority order.
  /// [quickNote] is intentionally excluded — it's the fallback when nothing
  /// else scores above threshold.
  static const List<VoiceNoteCategory> all = [
    meeting,
    todo,
    grocery,
    shopping,
    health,
    travel,
    study,
    work,
    finance,
    journal,
    ideas,
    recipe,
    fitness,
    personal,
    project,
  ];
}
