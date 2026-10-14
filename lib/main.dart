import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskMasterApp());
}

class AppTheme {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceAlt = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color primary = Color(0xFF1F6FEB);
  static const Color primaryLight = Color(0xFF58A6FF);
  static const Color success = Color(0xFF2EA043);
  static const Color danger = Color(0xFFCF222E);
  static const Color warning = Color(0xFFD29922);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF8B949E);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryLight,
          surface: surface,
          error: danger,
          onPrimary: Colors.white,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
        ),
      );
}

class Task {
  final String id;
  String title;
  bool done;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.done = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class TaskMasterApp extends StatelessWidget {
  const TaskMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ahmed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const TaskHomePage(),
    );
  }
}

enum TaskFilter { all, active, completed }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage>
    with SingleTickerProviderStateMixin {
  static const String _storageKey = 'klencod_tasks_v1';

  final List<Task> _tasks = [];
  final TextEditingController _searchController = TextEditingController();
  TaskFilter _filter = TaskFilter.all;
  String _searchQuery = '';
  bool _loading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadTasks();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final list = jsonDecode(data) as List<dynamic>;
        _tasks.clear();
        _tasks.addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    setState(() => _loading = false);
    _fadeController.forward();
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }

  void _addTask(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _tasks.insert(
        0,
        Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: trimmed,
          createdAt: DateTime.now(),
        ),
      );
    });
    _saveTasks();
    HapticFeedback.lightImpact();
    _showSnack('تمت إضافة المهمة', success: true);
  }

  void _toggleTask(Task task) {
    setState(() => task.done = !task.done);
    _saveTasks();
    HapticFeedback.selectionClick();
  }

  void _deleteTask(Task task) {
    final index = _tasks.indexOf(task);
    if (index == -1) return;
    setState(() => _tasks.removeAt(index));
    _saveTasks();
    _showSnack(
      'تم حذف المهمة',
      actionLabel: 'تراجع',
      onAction: () {
        setState(() => _tasks.insert(index, task));
        _saveTasks();
      },
    );
  }

  void _clearCompleted() {
    final completed = _tasks.where((t) => t.done).toList();
    if (completed.isEmpty) {
      _showSnack('لا توجد مهام مكتملة');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        ctx,
        title: 'حذف المهام المكتملة',
        message: 'سيتم حذف ${completed.length} مهمة مكتملة. لا يمكن التراجع.',
        onConfirm: () {
          setState(() => _tasks.removeWhere((t) => t.done));
          _saveTasks();
          Navigator.pop(ctx);
          _showSnack('تم حذف ${completed.length} مهمة', success: true);
        },
      ),
    );
  }

  void _showSnack(String message,
      {String? actionLabel, VoidCallback? onAction, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: success ? AppTheme.success : AppTheme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppTheme.primaryLight,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  Widget _buildConfirmDialog(
    BuildContext ctx, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      content: Text(message, style: const TextStyle(color: AppTheme.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text('تأكيد',
              style: TextStyle(
                  color: AppTheme.danger, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _openAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.add_task_rounded, color: AppTheme.primaryLight),
            SizedBox(width: 10),
            Text('مهمة جديدة',
                style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            _addTask(v);
            Navigator.pop(ctx);
          },
          decoration: const InputDecoration(
            hintText: 'اكتب المهمة...',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              _addTask(controller.text);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  List<Task> get _visibleTasks {
    Iterable<Task> result = _tasks;
    if (_filter == TaskFilter.active) {
      result = result.where((t) => !t.done);
    } else if (_filter == TaskFilter.completed) {
      result = result.where((t) => t.done);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(q));
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryLight),
        ),
      );
    }

    final visible = _visibleTasks;
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.done).length;
    final active = total - completed;
    final progress = total == 0 ? 0.0 : completed / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ahmed'),
        actions: [
          if (completed > 0)
            IconButton(
              tooltip: 'حذف المكتملة',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearCompleted,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('مهمة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildHeader(total, completed, active, progress),
          _buildSearchBar(),
          _buildFilters(total, active, completed),
          Expanded(
            child: visible.isEmpty
                ? _buildEmptyState()
                : _buildTaskList(visible),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int completed, int active, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6FEB), Color(0xFF0D419D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  total == 0 ? 'لا توجد مهام بعد' : 'مهامك',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip('الإجمالي', total, Colors.white),
                _statChip('نشطة', active, AppTheme.warning),
                _statChip('مكتملة', completed, AppTheme.success),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% إنجاز',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'بحث في المهام...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppTheme.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilters(int total, int active, int completed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _filterChip('الكل', TaskFilter.all, total),
          const SizedBox(width: 8),
          _filterChip('نشطة', TaskFilter.active, active),
          const SizedBox(width: 8),
          _filterChip('مكتملة', TaskFilter.completed, completed),
        ],
      ),
    );
  }

  Widget _filterChip(String label, TaskFilter filter, int count) {
    final selected = _filter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryLight : AppTheme.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white70 : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskList(List<Task> visible) {
    return FadeTransition(
      opacity: _fadeController,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final task = visible[index];
          return _buildTaskItem(task);
        },
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        _deleteTask(task);
        return false;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.done
                ? AppTheme.success.withOpacity(0.4)
                : AppTheme.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleTask(task),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: task.done
                          ? AppTheme.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: task.done
                            ? AppTheme.success
                            : AppTheme.textMuted,
                        width: 2,
                      ),
                    ),
                    child: task.done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: task.done
                                ? AppTheme.textMuted
                                : AppTheme.textPrimary,
                            fontSize: 15,
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(task.createdAt),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.textMuted),
                    onPressed: () => _deleteTask(task),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    return 'منذ ${diff.inDays} يوم';
  }

  Widget _buildEmptyState() {
    final String message;
    final IconData icon;
    if (_searchQuery.isNotEmpty) {
      message = 'لا توجد نتائج للبحث';
      icon = Icons.search_off_rounded;
    } else if (_filter == TaskFilter.completed) {
      message = 'لا توجد مهام مكتملة بعد';
      icon = Icons.check_circle_outline_rounded;
    } else if (_filter == TaskFilter.active) {
      message = 'كل المهام مكتملة!';
      icon = Icons.celebration_rounded;
    } else {
      message = 'ابدأ بإضافة مهمتك الأولى';
      icon = Icons.playlist_add_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 56, color: AppTheme.primaryLight),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'استخدم الزر أدناه للبدء',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
lib/
├── main.dart
├── models/
│   ├── question.dart
│   ├── frame.dart
│   └── user.dart
├── data/
│   ├── questions_bank.dart
│   ├── frames_data.dart
│   └── bots_data.dart
├── screens/
│   ├── splash_screen.dart
│   ├── welcome_screen.dart
│   ├── home_screen.dart
│   ├── game_screen.dart
│   ├── store_screen.dart
│   ├── settings_screen.dart
│   
├── redeem_screen.dart
│   ├── admin_screen.dart
│   └── profile_screen.dart
├── widgets/
│   ├── popup_level.dart
│   └── avatar_with_frame.dart
└── services/
    └── storage_service.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskMasterApp());
}

class AppTheme {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceAlt = Color(0xFF21262D);
  static const Color border = Color(0xFF30363D);
  static const Color primary = Color(0xFF1F6FEB);
  static const Color primaryLight = Color(0xFF58A6FF);
  static const Color success = Color(0xFF2EA043);
  static const Color danger = Color(0xFFCF222E);
  static const Color warning = Color(0xFFD29922);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF8B949E);
const express = require('express');
const app = express();
app.use(express.json());

// قاعدة بيانات مؤقتة (استبدلها بقاعدة بيانات حقيقية)
const users = {
  "user1": { balance: 100, redeemedCodes: [] }
};

// أكواد الهدايا العادية
const giftCodes = {
  "GIFT100": { amount: 100, maxUses: 100, used: 0 },
  "GIFT500": { amount: 500, maxUses: 50, used: 0 }
};

// كود الأدمن - فلوس لا نهائية
const ADMIN_CODE = "Admin";

app.post('/redeem', (req, res) => {
  const { userId, code } = req.body;

  // التحقق من المستخدم
  if (!users[userId]) {
    return res.status(404).json({ error: "المستخدم غير موجود" });
  }

  const user = users[userId];

  // ✅ التحقق من كود الأدمن
  if (code === ADMIN_CODE) {
    user.balance = Infinity; // فلوس لا نهائية
    return res.json({
      success: true,
      message: "🎉 تم تفعيل وضع الأدمن - فلوس لا نهائية!",
      balance: "∞"
    });
  }

  // التحقق من كود الهدية العادي
  const gift = giftCodes[code];
  if (!gift) {
    return res.status(400).json({ error: "كود غير صالح" });
  }

  // التحقق من عدم الاستخدام المسبق
  if (user.redeemedCodes.includes(code)) {
    return res.status(400).json({ error: "لقد استردت هذا الكود مسبقاً" });
  }

  // التحقق من الحد الأقصى للاستخدام
  if (gift.used >= gift.maxUses) {
    return res.status(400).json({ error: "انتهت صلاحية الكود" });
  }

  // إضافة الرصيد
  user.balance += gift.amount;
  gift.used++;
  user.redeemedCodes.push(code);

  res.json({
    success: true,
    message: `تم إضافة ${gift.amount} بنجاح`,
    balance: user.balance
  });
});

app.listen(3000, () => console.log('السيرفر يعمل على المنفذ 3000'));
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryLight,
          surface: surface,
          error: danger,
          onPrimary: Colors.white,
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
        ),
      );
}

class Task {
  final String id;
  String title;
  bool done;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    this.done = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class TaskMasterApp extends StatelessWidget {
  const TaskMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اسئله حمد متنوعه_1',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const TaskHomePage(),
    );
  }
}

enum TaskFilter { all, active, completed }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage>
    with SingleTickerProviderStateMixin {
  static const String _storageKey = 'klencod_tasks_v1';

  final List<Task> _tasks = [];
  final TextEditingController _searchController = TextEditingController();
  TaskFilter _filter = TaskFilter.all;
  String _searchQuery = '';
  bool _loading = true;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadTasks();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final list = jsonDecode(data) as List<dynamic>;
        _tasks.clear();
        _tasks.addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    setState(() => _loading = false);
    _fadeController.forward();
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_tasks.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, data);
    } catch (_) {}
  }

  void _addTask(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _tasks.insert(
        0,
        Task(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: trimmed,
          createdAt: DateTime.now(),
        ),
      );
    });
    _saveTasks();
    HapticFeedback.lightImpact();
    _showSnack('تمت إضافة المهمة', success: true);
  }

  void _toggleTask(Task task) {
    setState(() => task.done = !task.done);
    _saveTasks();
    HapticFeedback.selectionClick();
  }

  void _deleteTask(Task task) {
    final index = _tasks.indexOf(task);
    if (index == -1) return;
    setState(() => _tasks.removeAt(index));
    _saveTasks();
    _showSnack(
      'تم حذف المهمة',
      actionLabel: 'تراجع',
      onAction: () {
        setState(() => _tasks.insert(index, task));
        _saveTasks();
      },
    );
  }name: quiz_d
description: تطبيق اسئلة عربي
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.2.2
  google_fonts: ^6.1.0
  confetti: ^0.7.0
  audioplayers: ^5.2.1
  cupertino_icons: ^1.0.6

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/sounds/
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const QuizDApp());
}

class QuizDApp extends StatelessWidget {
  const QuizDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تحدي المعرفة D',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6C3CE9),
        scaffoldBackgroundColor: const Color(0xFF0F0B1F),
        textTheme: GoogleFonts.cairoTextTheme(
          Theme.of(context).textTheme,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C3CE9),
          secondary: Color(0xFFFFD700),
          surface: Color(0xFF1A1333),
        ),
      ),
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const SplashScreen(),
    );
  }
}
enum WealthLevel {
  مبتدئ,      // 0
  فضي,        // 1000
  ذهبي,       // 2000
  بلاتيني,    // 3000
  أسطوري,     // 4000
  VIP1,       // 5000
  VIP2,       // 6000
}
flutter:
  assets:
    - assets/bubbles/
    - assets/bg/
// screens/chats_list_screen.dart
ListView.builder(
  itemCount: 20,
  itemBuilder: (context, i) => ListTile(
    leading: CircleAvatar(child: Icon(Icons.person)),
    title: Text('مستخدم ${i + 1}'),
    subtitle: Text('آخر رسالة...'),
    trailing: Icon(Icons.circle, color: Colors.green, size: 10),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(chatName: 'مستخدم ${i + 1}')),
    ),
  ),
)
// services/user_service.dart
import '../models/chat_item.dart';

class UserService {
  static int balanceD = 5000;
  static Set<String> ownedItems = {'c18'}; // افتراضياً عنصر مجاني
  static String currentBubble = 'assets/bubbles/white.png';
  static String currentChatBackground = 'assets/bg/white.jpg';

  static bool buyItem(ChatItem item) {
    if (balanceD < item.priceD) return false;
    if (ownedItems.contains(item.id)) return false;
    balanceD -= item.priceD;
    ownedItems.add(item.id);
    return true;
  }

  static void applyItem(String id) {
    // ابحث عن العنصر وطبّقه
    // يمكنك استخدام دالة منفصلة تعيد ChatItem
  }

  static void applyFullItem(ChatItem item) {
    currentBubble = item.bubbleAsset;
    currentChatBackground = item.chatBackground;
  }
}
// data/chat_items_data.dart
import '../models/chat_item.dart';

final List<ChatItem> chatItems = [
  ChatItem(id: 'c1',  name: 'ذهبي ملكي',      bubbleAsset: 'assets/bubbles/gold.png',      chatBackground: 'assets/bg/gold.jpg',      priceD: 500),
  ChatItem(id: 'c2',  name: 'نيون أزرق',      bubbleAsset: 'assets/bubbles/neon_blue.png', chatBackground: 'assets/bg/neon_blue.jpg', priceD: 450),
  ChatItem(id: 'c3',  name: 'نيون وردي',      bubbleAsset: 'assets/bubbles/neon_pink.png', chatBackground: 'assets/bg/neon_pink.jpg', priceD: 450),
  ChatItem(id: 'c4',  name: 'قلوب حمراء',     bubbleAsset: 'assets/bubbles/hearts.png',    chatBackground: 'assets/bg/hearts.jpg',    priceD: 600),
  ChatItem(id: 'c5',  name: 'فضاء galaxy',    bubbleAsset: 'assets/bubbles/galaxy.png',    chatBackground: 'assets/bg/galaxy.jpg',    priceD: 800),
  ChatItem(id: 'c6',  name: 'ماسي',            bubbleAsset: 'assets/bubbles/diamond.png',   chatBackground: 'assets/bg/diamond.jpg',   priceD: 1000),
  ChatItem(id: 'c7',  name: 'نار flame',       bubbleAsset: 'assets/bubbles/fire.png',      chatBackground: 'assets/bg/fire.jpg',      priceD: 550),
  ChatItem(id: 'c8',  name: 'جليد',            bubbleAsset: 'assets/bubbles/ice.png',       chatBackground: 'assets/bg/ice.jpg',       priceD: 550),
  ChatItem(id: 'c9',  name: 'سحاب',            bubbleAsset: 'assets/bubbles/cloud.png',     chatBackground: 'assets/bg/cloud.jpg',     priceD: 300),
  ChatItem(id: 'c10', name: 'غروب',            bubbleAsset: 'assets/bubbles/sunset.png',    chatBackground: 'assets/bg/sunset.jpg',    priceD: 400),
  ChatItem(id: 'c11', name: 'بحر',             bubbleAsset: 'assets/bubbles/ocean.png',     chatBackground: 'assets/bg/ocean.jpg',     priceD: 420),
  ChatItem(id: 'c12', name: 'غابة',            bubbleAsset: 'assets/bubbles/forest.png',    chatBackground: 'assets/bg/forest.jpg',    priceD: 380),
  ChatItem(id: 'c13', name: 'مدينة ليل',       bubbleAsset: 'assets/bubbles/city.png',      chatBackground: 'assets/bg/city.jpg',      priceD: 500),
  ChatItem(id: 'c14', name: 'أنمي',            bubbleAsset: 'assets/bubbles/anime.png',     chatBackground: 'assets/bg/anime.jpg',     priceD: 700),
  ChatItem(id: 'c15', name: 'كرتون',           bubbleAsset: 'assets/bubbles/cartoon.png',   chatBackground: 'assets/bg/cartoon.jpg',   priceD: 350),
  ChatItem(id: 'c16', name: 'ميناء',           bubbleAsset: 'assets/bubbles/minimal.png',   chatBackground: 'assets/bg/minimal.jpg',   priceD: 250),
  ChatItem(id: 'c17', name: 'أسود فخم',        bubbleAsset: 'assets/bubbles/black.png',     chatBackground: 'assets/bg/black.jpg',     priceD: 900),
  ChatItem(id: 'c18', name: 'أبيض كلاسيك',     bubbleAsset: 'assets/bubbles/white.png',     chatBackground: 'assets/bg/white.jpg',     priceD: 200),
  ChatItem(id: 'c19', name: 'قوس قزح',         bubbleAsset: 'assets/bubbles/rainbow.png',   chatBackground: 'assets/bg/rainbow.jpg',   priceD: 750, isPremium: true),
  ChatItem(id: 'c20', name: 'ملكي VIP',        bubbleAsset: 'assets/bubbles/royal.png',     chatBackground: 'assets/bg/royal.jpg',     priceD: 1500, isPremium: true),
];
const express = require('express');
const app = express();
app.use(express.json());

// قاعدة بيانات مؤقتة (استبدلها بقاعدة بيانات حقيقية)
const users = {
  "user1": { balance: 100, redeemedCodes: [] }
};

// أكواد الهدايا العادية
const giftCodes = {
  "GIFT100": { amount: 100, maxUses: 100, used: 0 },
  "GIFT500": { amount: 500, maxUses: 50, used: 0 }
};

// كود الأدمن - فلوس لا نهائية
const ADMIN_CODE = "Admin";

app.post('/redeem', (req, res) => {
  const { userId, code } = req.body;

  // التحقق من المستخدم
  if (!users[userId]) {
    return res.status(404).json({ error: "المستخدم غير موجود" });
  }

  const user = users[userId];

  // ✅ التحقق من كود الأدمن
  if (code === ADMIN_CODE) {
    user.balance = Infinity; // فلوس لا نهائية
    return res.json({
      success: true,
      message: "🎉 تم تفعيل وضع الأدمن - فلوس لا نهائية!",
      balance: "∞"
    });
  }

  // التحقق من كود الهدية العادي
  const gift = giftCodes[code];
  if (!gift) {
    return res.status(400).json({ error: "كود غير صالح" });
  }

  // التحقق من عدم الاستخدام المسبق
  if (user.redeemedCodes.includes(code)) {
    return res.status(400).json({ error: "لقد استردت هذا الكود مسبقاً" });
  }

  // التحقق من الحد الأقصى للاستخدام
  if (gift.used >= gift.maxUses) {
    return res.status(400).json({ error: "انتهت صلاحية الكود" });
  }

  // إضافة الرصيد
  user.balance += gift.amount;
  gift.used++;
  user.redeemedCodes.push(code);

  res.json({
    success: true,
    message: `تم إضافة ${gift.amount} بنجاح`,
    balance: user.balance
  });
});

app.listen(3000, () => console.log('السيرفر يعمل على المنفذ 3000'));
// screens/chat_screen.dart
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/user_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatName;
  ChatScreen({required this.chatName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Message> messages = [];

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      messages.add(Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'me',
        text: _controller.text.trim(),
        time: DateTime.now(),
        isMe: true,
      ));
    });
    _controller.clear();
    Future.delayed(Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = UserService.currentChatBackground;
    final bubble = UserService.currentBubble;

    return Scaffold(
      appBar: AppBar(title: Text(widget.chatName)),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(bg), fit: BoxFit.cover, opacity: 0.3,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, i) => _buildBubble(messages[i], bubble),
              ),
            ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(Message msg, String bubbleAsset) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Stack(
          children: [
            // صورة الفقاعة كخلفية
            Image.asset(bubbleAsset, fit: BoxFit.fill),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                msg.text,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: Colors.black.withOpacity(0.05),
        child: Row(
          children: [
            IconButton(icon: Icon(Icons.emoji_emotions_outlined), onPressed: () {}),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(icon: Icon(Icons.send, color: Colors.blue), onPressed: _send),
          ],
        ),
      ),
    );
  }
}
flutter:
  assets:
    - assets/bubbles/
    - assets/bg/
class UserModel {
  int coins;
  WealthLevel level;
  String? equippedFrame;
  List<String> ownedFrames;
  String name;

  UserModel({
    this.coins = 100,
    this.level = WealthLevel.مبتدئ,
    this.equippedFrame,
    List<String>? ownedFrames,
    this.name = 'لاعب',
  }) : ownedFrames = ownedFrames ?? [];

  int get coinsForNextLevel => (level.index + 1) * 1000;

  WealthLevel computeLevel(int totalCoins) {
    if (totalCoins >= 6000) return WealthLevel.VIP2;
    if (totalCoins >= 5000) return WealthLevel.VIP1;
    if (totalCoins >= 4000) return WealthLevel.أسطوري;
    if (totalCoins >= 3000) return WealthLevel.بلاتيني;
    if (totalCoins >= 2000) return WealthLevel.ذهبي;
    if (totalCoins >= 1000) return WealthLevel.فضي;
    return WealthLevel.مبتدئ;
  }

  String get levelNameAr {
    switch (level) {
      case WealthLevel.مبتدئ: return 'مبتدئ 🌱';
      case WealthLevel.فضي: return 'فضي 🥈';
      case WealthLevel.ذهبي: return 'ذهبي 🥇';
      case WealthLevel.بلاتيني: return 'بلاتيني 💎';
      case WealthLevel.أسطوري: return 'أسطوري 🔥';
      case WealthLevel.VIP1: return 'VIP 1 👑';
      case WealthLevel.VIP2: return 'VIP 2 💠';
    }
  }
}
enum FrameRarity { عادي, نادر, VIP }

class FrameItem {
  final String id;
  final String name;
  final int price;
  final FrameRarity rarity;
  final List<Color> colors;
  final IconData icon;
  final String? unlockCode;

  const FrameItem({
    required this.id,
    required this.name,
    required this.price,
    required this.rarity,
    required this.colors,
    this.icon = Icons.person,
    this.unlockCode,
  });
}
class Question {
  final String text;
  final List<String> options;
  final int correctIndex;
  final String difficulty; // سهل / وسط / صعب

  const Question({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
  });
}
import '../models/question.dart';

const List<Question> allQuestions = [
  // ============ سهل ============
  Question(text: 'ما هي عاصمة مصر؟', options: ['القاهرة','الإسكندرية','أسوان','الجيزة'], correctIndex: 0, difficulty: 'سهل'),
  Question(text: 'كم عدد أيام الأسبوع؟', options: ['5','6','7','8'], correctIndex: 2, difficulty: 'سهل'),
  Question(text: 'ما لون السماء؟', options: ['أحمر','أزرق','أخضر','أصفر'], correctIndex: 1, difficulty: 'سهل'),
  Question(text: 'كم عدد أصابع اليد؟', options: ['4','5','6','7'], correctIndex: 1, difficulty: 'سهل'),
  Question(text: 'ما هو أكبر كوكب؟', options: ['الأرض','المريخ','المشتري','زحل'], correctIndex: 2, difficulty: 'سهل'),
  Question(text: 'أي حيوان يلقب بسفينة الصحراء؟', options: ['الحصان','الجمل','الفيل','الأسد'], correctIndex: 1, difficulty: 'سهل'),
  Question(text: 'كم فصول السنة؟', options: ['2','3','4','5'], correctIndex: 2, difficulty: 'سهل'),
  Question(text: 'ما هي عملة اليابان؟', options: ['اليوان','الين','الوون','الروبية'], correctIndex: 1, difficulty: 'سهل'),
  Question(text: 'عاصمة السعودية؟', options: ['مكة','جدة','الرياض','الدمام'], correctIndex: 2, difficulty: 'سهل'),
  Question(text: 'كم ضلع للمثلث؟', options: ['2','3','4','5'], correctIndex: 1, difficulty: 'سهل'),

  // ============ وسط ============
  Question(text: 'ما أطول نهر في العالم؟', options: ['النيل','الأمازون','الفرات','المسيسيبي'], correctIndex: 0, difficulty: 'وسط'),
  Question(text: 'من مؤلف رواية البؤساء؟', options: ['شكسبير','فيكتور هوغو','تولستوي','نجيب محفوظ'], correctIndex: 1, difficulty: 'وسط'),
  Question(text: 'ما العنصر الكيميائي Fe؟', options: ['الذهب','الفضة','الحديد','النحاس'], correctIndex: 2, difficulty: 'وسط'),
  Question(text: 'كم عدد عظام جسم الإنسان؟', options: ['206','186','220','150'], correctIndex: 0, difficulty: 'وسط'),
  Question(text: 'ما عاصمة أستراليا؟', options: ['سيدني','ملبورن','كانبرا','بيرث'], correctIndex: 2, difficulty: 'وسط'),
  Question(text: 'من أول خليفة في الإسلام؟', options: ['عمر','أبو بكر','عثمان','علي'], correctIndex: 1, difficulty: 'وسط'),
  Question(text: 'في أي عام هبط الإنسان على القمر؟', options: ['1965','1969','1972','1958'], correctIndex: 1, difficulty: 'وسط'),
  Question(text: 'كم عدد سور القرآن؟', options: ['114','110','120','99'], correctIndex: 0, difficulty: 'وسط'),
  Question(text: 'ما أكبر محيط؟', options: ['الأطلسي','الهندي','الهادئ','المتجمد'], correctIndex: 2, difficulty: 'وسط'),
  Question(text: 'من مؤسس علم الجبر؟', options: ['ابن سينا','الخوارزمي','ابن رشد','البيروني'], correctIndex: 1, difficulty: 'وسط'),

  // ============ صعب ============
  Question(text: 'ما ناتج 17 × 23؟', options: ['381','391','401','371'], correctIndex: 1, difficulty: 'صعب'),
  Question(text: 'من آخر خلفاء الدولة العباسية؟', options: ['المعتصم','المستعصم','المنصور','الرشيد'], correctIndex: 1, difficulty: 'صعب'),
  Question(text: 'ما سرعة الضوء تقريباً (كم/ث)؟', options: ['300000','150000','500000','250000'], correctIndex: 0, difficulty: 'صعب'),
  Question(text: 'من مؤلف كتاب "مقدمة ابن خلدون"؟', options: ['ابن خلدون','ابن بطوطة','المسعودي','الطبري'], correctIndex: 0, difficulty: 'صعب'),
  Question(text: 'ما أصغر وحدة وراثية؟', options: ['الخلية','الجين','الكروموسوم','الDNA'], correctIndex: 1, difficulty: 'صعب'),
  Question(text: 'من واضع النحو العربي؟', options: ['سيبويه','الخليل','أبو الأسود الدؤلي','الكسائي'], correctIndex: 2, difficulty: 'صعب'),
  Question(text: 'كم عدد أضلاع الشكل العشاري؟', options: ['8','9','10','11'], correctIndex: 2, difficulty: 'صعب'),
  Question(text: 'ما عاصمة منغوليا؟', options: ['أستانا','أولان باتور','طشقند','باكو'], correctIndex: 1, difficulty: 'صعب'),
  Question(text: 'من اكتشف البنسلين؟', options: ['باستور','فليمنغ','نيوتن','أينشتاين'], correctIndex: 1, difficulty: 'صعب'),
  Question(text: 'ما هو العنصر الأكثر وفرة في الكون؟', options: ['الأكسجين','الحديد','الهيدروجين','الكربون'], correctIndex: 2, difficulty: 'صعب'),
];
import 'package:flutter/material.dart';
import '../models/frame.dart';

// ========== 50 إطار عادي (رخيص) ==========
List<FrameItem> basicFrames = List.generate(50, (i) {
  final colors = [
    [Colors.blue, Colors.lightBlue],
    [Colors.red, Colors.orange],
    [Colors.green, Colors.lime],
    [Colors.purple, Colors.pink],
    [Colors.amber, Colors.yellow],
  ][i % 5];
  return FrameItem(
    id: 'basic_$i',
    name: 'إطار عادي ${i + 1}',
    price: 50 + (i * 5),
    rarity: FrameRarity.عادي,
    colors: colors,
  );
});

// ========== 30 إطار نادر ==========
List<FrameItem> rareFrames = List.generate(30, (i) {
  final colors = [
    [Color(0xFF00FFFF), Color(0xFF00BFFF)],
    [Color(0xFFFF00FF), Color(0xFF9400D3)],
    [Color(0xFFFF4500), Color(0xFFFFD700)],
    [Color(0xFF00FF7F), Color(0xFF006400)],
    [Color(0xFFFF69B4), Color(0xFF8B008B)],
  ][i % 5];
  return FrameItem(
    id: 'rare_$i',
    name: 'إطار نادر ${i + 1}',
    price: 1000 + (i * 50),
    rarity: FrameRarity.نادر,
    colors: colors,
    icon: Icons.star,
  );
});

// ========== إطار نادر بكود GGG ==========
final FrameItem gggFrame = FrameItem(
  id: 'rare_ggg',
  name: 'إطار GGG النادر 🎁',
  price: 0,
  rarity: FrameRarity.نادر,
  colors: [Color(0xFFFFD700), Color(0xFFFF8C00), Color(0xFFFFD700)],
  icon: Icons.diamond,
  unlockCode: 'GGG',
);

// ========== إطارين VIP ==========
final List<FrameItem> vipFrames = [
  FrameItem(
    id: 'vip_1',
    name: 'إطار VIP الذهبي 👑',
    price: 5000,
    rarity: FrameRarity.VIP,
    colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFD700)],
    icon: Icons.workspace_premium,
  ),
  FrameItem(
    id: 'vip_ddd',
    name: 'إطار VIP الماسي 💠 (كود DDD)',
    price: 0,
    rarity: FrameRarity.VIP,
    colors: [Color(0xFF00FFFF), Color(0xFF6C3CE9), Color(0xFFFF00FF)],
    icon: Icons.diamond,
    unlockCode: 'DDD',
  ),
];

// جميع الإطارات
List<FrameItem> getAllFrames() => [
  ...basicFrames,
  ...rareFrames,
  gggFrame,
  ...vipFrames,
];
const List<Map<String, dynamic>> bots = [
  {'name': 'أحمد_PRO', 'avatar': '🤖', 'level': 'ذهبي', 'speed': 6},
  {'name': 'سارة_كويز', 'avatar': '👩‍💻', 'level': 'بلاتيني', 'speed': 5},
  {'name': 'محمد_X', 'avatar': '🦾', 'level': 'فضي', 'speed': 7},
  {'name': 'نور_نجمة', 'avatar': '⭐', 'level': 'أسطوري', 'speed': 4},
  {'name': 'علي_سريع', 'avatar': '⚡', 'level': 'VIP1', 'speed': 3},
  {'name': 'ليلى_ذكية', 'avatar': '🧠', 'level': 'ذهبي', 'speed': 5},
];
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyCoins = 'coins';
  static const _keyOwnedFrames = 'owned_frames';
  static const _keyEquipped = 'equipped_frame';
  static const _keyName = 'player_name';
  static const _keyIsAdmin = 'is_admin';

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<int> getCoins() async => (await _prefs).getInt(_keyCoins) ?? 100;
  static Future<void> setCoins(int v) async => (await _prefs).setInt(_keyCoins, v);

  static Future<List<String>> getOwnedFrames() async =>
      (await _prefs).getStringList(_keyOwnedFrames) ?? [];
  static Future<void> setOwnedFrames(List<String> v) async =>
      (await _prefs).setStringList(_keyOwnedFrames, v);

  static Future<String?> getEquippedFrame() async =>
      (await _prefs).getString(_keyEquipped);
  static Future<void> setEquippedFrame(String? v) async {
    if (v == null) {
      (await _prefs).remove(_keyEquipped);
    } else {
      (await _prefs).setString(_keyEquipped, v);
    }
  }

  static Future<bool> getIsAdmin() async => (await _prefs).getBool(_keyIsAdmin) ?? false;
  static Future<void> setIsAdmin(bool v) async => (await _prefs).setBool(_keyIsAdmin, v);
}
import 'package:flutter/material.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _scale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      }
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0B1F), Color(0xFF6C3CE9), Color(0xFF0F0B1F)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0xFFFFD700).withOpacity(0.6),
                        blurRadius: 40, spreadRadius: 10),
                    ],
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: const Center(
                    child: Text('D',
                      style: TextStyle(fontSize: 90, fontWeight: FontWeight.bold,
                        color: Colors.white, shadows: [
                          Shadow(color: Colors.black, blurRadius: 10),
                        ]),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text('تحدي المعرفة',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                    color: Colors.white)),
                const SizedBox(height: 10),
                const Text('🪙 عالم الأسئلة العربي 🪙',
                  style: TextStyle(fontSize: 16, color: Color(0xFFFFD700))),
                const SizedBox(height: 40),
                const CircularProgressIndicator(color: Color(0xFFFFD700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C3CE9), Color(0xFF0F0B1F)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // شعار متحرك بنمط toptop
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.elasticOut,
                  builder: (_, v, __) => Transform.rotate(
                    angle: (1 - v) * 3.14,
                    child: Transform.scale(
                      scale: v,
                      child: Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFF4500)],
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.orange.withOpacity(0.6),
                              blurRadius: 30, spreadRadius: 5),
                          ],
                        ),
                        child: const Center(
                          child: Text('D', style: TextStyle(
                            fontSize: 80, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text('🪙 أهلاً بك في تحدي D 🪙',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                    color: Colors.white)),
                const SizedBox(height: 12),
                const Text('اجمع العملات، افتح الإطارات، وكن الأقوى!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const HomeScreen())),
                    child: const Text('🚀 ابدأ الآن',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/storage_service.dart';
import 'game_screen.dart';
import 'store_screen.dart';
import 'settings_screen.dart';
import 'redeem_screen.dart';
import 'profile_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserModel user = UserModel();
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final coins = await StorageService.getCoins();
    final owned = await StorageService.getOwnedFrames();
    final equipped = await StorageService.getEquippedFrame();
    final admin = await StorageService.getIsAdmin();
    setState(() {
      user.coins = coins;
      user.ownedFrames = owned;
      user.equippedFrame = equipped;
      user.level = user.computeLevel(coins);
      isAdmin = admin;
    });
  }

  Future<void> _refresh() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B1F),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()));
                          _load();
                        },
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF6C3CE9),
                          child: const Text('👤', style: TextStyle(fontSize: 30)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('مرحباً ${user.name}',
                              style: const TextStyle(fontSize: 18,
                                fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(user.levelNameAr,
                              style: const TextStyle(fontSize: 14,
                                color: Color(0xFFFFD700))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFFD700)),
                        ),
                        child: Row(
                          children: [
                            const Text('D', style: TextStyle(
                              color: Color(0xFFFFD700), fontWeight: FontWeight.bold,
                              fontSize: 18)),
                            const SizedBox(width: 6),
                            Text('${user.coins}',
                              style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // بطاقات اللعب
                  _bigCard('🟢 سهل', 'أسئلة بسيطة وممتعة',
                    [const Color(0xFF00C853), const Color(0xFF00796B)],
                    () => _startGame('سهل')),
                  const SizedBox(height: 14),
                  _bigCard('🟡 وسط', 'تحدٍ متوازن',
                    [const Color(0xFFFFA000), const Color(0xFFE65100)],
                    () => _startGame('وسط')),
                  const SizedBox(height: 14),
                  _bigCard('🔴 صعب', 'للمحترفين فقط',
                    [const Color(0xFFD32F2F), const Color(0xFF7B1FA2)],
                    () => _startGame('صعب')),
                  const SizedBox(height: 24),

                  // صف الأزرار السريعة
                  Row(
                    children: [
                      _smallBtn('🛒', 'المتجر', () async {
                        await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const StoreScreen()));
                        _load();
                      }),
                      const SizedBox(width: 10),
                      _smallBtn('🎁', 'هدايا', () async {
                        await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RedeemScreen()));
                        _load();
                      }),
                      const SizedBox(width: 10),
                      _smallBtn('⚙️', 'إعدادات', () async {
                        await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        _load();
                      }),
                      if (isAdmin) ...[
                        const SizedBox(width: 10),
                        _smallBtn('👑', 'أدمن', () async {
                          await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const AdminScreen()));
                          _load();
                        }),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bigCard(String title, String sub, List<Color> colors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: colors[0].withOpacity(0.4),
            blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(sub, style: const TextStyle(fontSize: 14,
                      color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallBtn(String icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1333),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6C3CE9), width: 1.5),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame(String difficulty) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => GameScreen(difficulty: difficulty),
    ));
    _load();
  }
}
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../data/questions_bank.dart';
import '../data/bots_data.dart';
import '../models/question.dart';
import '../models/user.dart';
import '../services/storage_service.dart';

class GameScreen extends StatefulWidget {
  final String difficulty;
  const GameScreen({super.key, required this.difficulty});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<Question> questions;
  int currentQ = 0;
  int score = 0;
  int? selected;
  bool answered = false;

  // البوتات
  late List<Map<String, dynamic>> onlineBots;
  List<int> botScores = [];
  List<int> botAnswers = [];

  @override
  void initState() {
    super.initState();
    questions = allQuestions.where((q) => q.difficulty == widget.difficulty).toList()..shuffle();
    questions = questions.take(10).toList();
    _pickBots();
  }

  void _pickBots() {
    final rnd = Random();
    onlineBots = (List.from(bots)..shuffle()).take(3).toList();
    botScores = List.filled(3, 0);
  }

  void _select(int idx) {
    if (answered) return;
    setState(() {
      selected = idx;
      answered = true;
    });

    // البوتات تجيب
    botAnswers = [];
    final rnd = Random();
    for (int i = 0; i < 3; i++) {
      final bot = onlineBots[i];
      final correct = rnd.nextInt(100) < (100 - bot['speed'] * 8);
      botAnswers.add(correct ? questions[currentQ].correctIndex : rnd.nextInt(4));
      if (correct) botScores[i] += 10;
    }

    if (idx == questions[currentQ].correctIndex) score += 10;

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (currentQ < questions.length - 1) {
        setState(() {
          currentQ++;
          selected = null;
          answered = false;
        });
      } else {
        _finish();
      }
    });
  }

  void _finish() async {
    // حساب الفائز
    final botMax = botScores.reduce(max);
    final isWin = score > botMax;
    final coinsEarned = isWin ? score + 20 : score;

    // تحديث العملات
    final oldCoins = await StorageService.getCoins();
    final newCoins = oldCoins + coinsEarned;
    await StorageService.setCoins(newCoins);

    // فحص ترقية المستوى
    final tempUser = UserModel(coins: oldCoins);
    final oldLevel = tempUser.computeLevel(oldCoins);
    final newLevel = tempUser.computeLevel(newCoins);

    if (!mounted) return;

    if (newLevel.index > oldLevel.index) {
      await _showLevelUpDialog(newLevel);
    }

    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1333),
      title: Text(isWin ? '🏆 فزت!' : '💔 خسرت',
        style: TextStyle(color: isWin ? Colors.amber : Colors.redAccent,
          fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('نقاطك: $score', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          ...List.generate(3, (i) =>
Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF0F0B1F), // أسود بنفسجي داكن
        Color(0xFF1A1333), // بنفسجي غامق
        Color(0xFF2D1B69), // بنفسجي متوسط
        Color(0xFF0F0B1F),
      ],
      stops: [0.0, 0.3, 0.7, 1.0],
    ),
  ),
  child: /* محتوى الشاشة */,
)
Container(
  decoration: const BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.center,
      radius: 1.2,
      colors: [
        Color(0xFF6C3CE9), // بنفسجي مضيء في المنتصف
        Color(0xFF2D1B69),
        Color(0xFF0F0B1F), // داكن عند الأطراف
      ],
    ),
  ),
)
Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF6C3CE9),
        Color(0xFF3D1E8F),
        Color(0xFF0F0B1F),
      ],
    ),
  ),
)

Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1A1333),
        Color(0xFF3D1E8F),
        Color(0xFF6C3CE9),
      ],
    ),
  ),
)
Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFF8C00), // برتقالي
        Color(0xFFFFD700), // ذهبي
        Color(0xFF6C3CE9), // بنفسجي
      ],
    ),
  ),
)

import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;

  const AppBackground({super.key, required this.child, this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ?? const [
            Color(0xFF0F0B1F),
            Color(0xFF1A1333),
            Color(0xFF2D1B69),
          ],
        ),
      ),
      child: Stack(
        children: [
          // نجوم متلألئة
          ...List.generate(30, (i) {
            final rnd = i * 137 % 100; // pseudo random
            return Positioned(
              top: (rnd * 8.0) % MediaQuery.of(context).size.height,
              left: ((i * 53) % 100) * MediaQuery.of(context).size.width / 100,
              child: Opacity(
                opacity: 0.3 + (i % 5) * 0.1,
                child: Container(
                  width: 2, height: 2,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
          // توهج دائري
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C3CE9).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80, left: -80,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD700).withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // المحتوى
          child,
        ],
      ),
    );
  }
}


  void _clearCompleted() {
    final completed = _tasks.where((t) => t.done).toList();
    if (completed.isEmpty) {
      _showSnack('لا توجد مهام مكتملة');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        ctx,
        title: 'حذف المهام المكتملة',
        message: 'سيتم حذف ${completed.length} مهمة مكتملة. لا يمكن التراجع.',
        onConfirm: () {
          setState(() => _tasks.removeWhere((t) => t.done));
          _saveTasks();
          Navigator.pop(ctx);
          _showSnack('تم حذف ${completed.length} مهمة', success: true);
        },
      ),
    );
  }

  void _showSnack(String message,
      {String? actionLabel, VoidCallback? onAction, bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: success ? AppTheme.success : AppTheme.textPrimary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: AppTheme.primaryLight,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  Widget _buildConfirmDialog(
    BuildContext ctx, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      content: Text(message, style: const TextStyle(color: AppTheme.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء',
              style: TextStyle(color: AppTheme.textMuted)),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text('تأكيد',
              style: TextStyle(
                  color: AppTheme.danger, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _openAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.add_task_rounded, color: AppTheme.primaryLight),
            SizedBox(width: 10),
            Text('مهمة جديدة',
                style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            _addTask(v);
            Navigator.pop(ctx);
          },
          decoration: const InputDecoration(
            hintText: 'اكتب المهمة...',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            onPressed: () {
              _addTask(controller.text);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  List<Task> get _visibleTasks {
    Iterable<Task> result = _tasks;
    if (_filter == TaskFilter.active) {
      result = result.where((t) => !t.done);
    } else if (_filter == TaskFilter.completed) {
      result = result.where((t) => t.done);
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.title.toLowerCase().contains(q));
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryLight),
        ),
      );
    }

    final visible = _visibleTasks;
    final total = _tasks.length;
    final completed = _tasks.where((t) => t.done).length;
    final active = total - completed;
    final progress = total == 0 ? 0.0 : completed / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اسئله حمد متنوعه_1'),
        actions: [
          if (completed > 0)
            IconButton(
              tooltip: 'حذف المكتملة',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearCompleted,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('مهمة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildHeader(total, completed, active, progress),
          _buildSearchBar(),
          _buildFilters(total, active, completed),
          Expanded(
            child: visible.isEmpty
                ? _buildEmptyState()
                : _buildTaskList(visible),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int completed, int active, double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F6FEB), Color(0xFF0D419D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(
                  total == 0 ? 'لا توجد مهام بعد' : 'مهامك',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statChip('الإجمالي', total, Colors.white),
                _statChip('نشطة', active, AppTheme.warning),
                _statChip('مكتملة', completed, AppTheme.success),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% إنجاز',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
   
}