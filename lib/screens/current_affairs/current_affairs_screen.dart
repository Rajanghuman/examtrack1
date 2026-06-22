import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/rss_service.dart';
import '../../l10n/language_provider.dart';
import '../../l10n/app_strings.dart';

class CurrentAffairsScreen extends StatefulWidget {
  final int initialTabIndex;

  const CurrentAffairsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CurrentAffairsScreen> createState() =>
      _CurrentAffairsScreenState();
}

class _CurrentAffairsScreenState extends State<CurrentAffairsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'All';

  // ── RSS News State ─────────────────────────────────────
  List<RssArticle> _articles = [];
  bool _isLoadingNews = true;
  String _newsError = '';

  // ── Quiz State ─────────────────────────────────────────
  List<Map<String, dynamic>> _quizQuestions = [];
  bool _isLoadingQuiz = true;
  int _currentQuizIndex = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _showExplanation = false;
  bool _quizComplete = false;

  final List<String> _categories = [
    'All', 'National', 'Current Affairs',
    'Economy', 'GK & Current Affairs',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadNews();
    _loadQuizQuestions();
  }

  // ── Load RSS News ──────────────────────────────────────
  Future<void> _loadNews() async {
    if (!mounted) return;
    setState(() {
      _isLoadingNews = true;
      _newsError = '';
    });
    try {
      final articles = await RssService.fetchAllArticles();
      if (!mounted) return;
      setState(() {
        _articles = articles;
        _isLoadingNews = false;
      });
    } catch (e) {
      if (!mounted) return;
      final lang = context.read<LanguageProvider>().languageCode;
      setState(() {
        _newsError = AppStrings.get('check_internet_connection', lang);
        _isLoadingNews = false;
      });
    }
  }

  // ── Load Quiz from Firestore ───────────────────────────
  Future<void> _loadQuizQuestions() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('quiz')
          .get();

      List<Map<String, dynamic>> questions =
      snapshot.docs.map((doc) {
        Map<String, dynamic> data =
        doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      questions.shuffle();
      final selected = questions.take(10).toList();

      if (!mounted) return;
      setState(() {
        _quizQuestions = selected;
        _isLoadingQuiz = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingQuiz = false);
    }
  }

  void _resetQuiz() {
    _loadQuizQuestions();
    setState(() {
      _currentQuizIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _showExplanation = false;
      _quizComplete = false;
    });
  }

  List<RssArticle> get _filteredArticles {
    if (_selectedCategory == 'All') return _articles;
    return _articles
        .where((a) => a.category == _selectedCategory)
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().languageCode;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(lang),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: AppStrings.get('tab_todays_news', lang)),
                Tab(text: AppStrings.get('tab_daily_quiz', lang)),
                Tab(text: AppStrings.get('tab_monthly_pdf', lang)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNewsTab(lang),
                _buildQuizTab(lang),
                _buildPDFTab(lang),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(lang),
    );
  }

  Widget _buildHeader(String lang) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20, right: 20, bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(
                    context, '/home'),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.get('current_affairs_title', lang),
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  Text(AppStrings.get('stay_updated_subtitle', lang),
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
              const Spacer(),
              // Refresh button
              GestureDetector(
                onTap: _loadNews,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHeaderStat(
                  _isLoadingNews
                      ? '...'
                      : '${_articles.length}',
                  AppStrings.get('todays_articles_stat', lang)),
              const SizedBox(width: 24),
              _buildHeaderStat(
                  _isLoadingQuiz
                      ? '...'
                      : '${_quizQuestions.length}',
                  AppStrings.get('quiz_questions_stat', lang)),
              const SizedBox(width: 24),
              _buildHeaderStat('3', AppStrings.get('news_sources_stat', lang)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  // ── News Tab ───────────────────────────────────────────
  // NOTE: category chip filter values (_categories list) stay in English
  // since they're matched against RssArticle.category data from the feed
  // itself — translating display-only would require the same name/key
  // split pattern used elsewhere, deferred for this pass since these are
  // mostly proper nouns (National, Economy) already short and recognizable.
  Widget _buildNewsTab(String lang) {
    return Column(
      children: [
        // Category chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
            const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade100,
                      borderRadius:
                      BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(cat,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // News list
        Expanded(
          child: _isLoadingNews
              ? Center(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                    color: Color(0xFF1565C0)),
                const SizedBox(height: 16),
                Text(AppStrings.get('loading_news', lang),
                    style: const TextStyle(
                        color: Color(0xFF6B7280))),
              ],
            ),
          )
              : _newsError.isNotEmpty
              ? _buildErrorState(lang)
              : _filteredArticles.isEmpty
              ? _buildEmptyState(lang)
              : RefreshIndicator(
            onRefresh: _loadNews,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount:
              _filteredArticles.length,
              itemBuilder: (context, index) =>
                  _buildArticleCard(
                      _filteredArticles[index], lang),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(AppStrings.get('could_not_load_news', lang),
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151))),
          const SizedBox(height: 8),
          Text(AppStrings.get('check_internet_connection', lang),
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF6B7280))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadNews,
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white),
            label: Text(AppStrings.get('try_again_btn', lang),
                style: GoogleFonts.poppins(
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.newspaper_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(AppStrings.get('no_articles_found', lang),
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: const Color(0xFF374151))),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                setState(() => _selectedCategory = 'All'),
            child: Text(AppStrings.get('show_all_btn', lang),
                style: GoogleFonts.poppins(
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // NOTE: article.title, article.description, article.source, and
  // article.category come from live RSS feeds — real news content,
  // not translated (same boundary as job/syllabus data elsewhere).
  Widget _buildArticleCard(RssArticle article, String lang) {
    Color categoryColor;
    IconData categoryIcon;

    switch (article.category) {
      case 'Government':
        categoryColor = const Color(0xFF1565C0);
        categoryIcon = Icons.account_balance_rounded;
        break;
      case 'Current Affairs':
        categoryColor = const Color(0xFF880E4F);
        categoryIcon = Icons.newspaper_rounded;
        break;
      default:
        categoryColor = const Color(0xFF10B981);
        categoryIcon = Icons.book_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(categoryIcon,
                      color: categoryColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(article.source,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: categoryColor,
                              fontWeight: FontWeight.w600)),
                      if (article.pubDate.isNotEmpty)
                        Text(
                            _formatDate(article.pubDate),
                            style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(article.category,
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: categoryColor,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(article.title,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A2E),
                    height: 1.4)),
            if (article.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(article.description,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.5)),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => _openURL(article.link, lang),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: categoryColor,
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                    child: Text(AppStrings.get('read_more_btn', lang),
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String pubDate) {
    try {
      final date = DateTime.parse(pubDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return pubDate.substring(0, 10);
    } catch (e) {
      return pubDate.length > 20
          ? pubDate.substring(0, 20)
          : pubDate;
    }
  }

  // ── Open URL in browser ────────────────────────────────
  Future<void> _openURL(String url, String lang) async {
    if (url.isEmpty) {
      _showToast(AppStrings.get('link_not_available', lang), success: false);
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri,
          mode: LaunchMode.externalApplication);
    } else {
      _showToast(AppStrings.get('unable_to_open_link', lang), success: false);
    }
  }

  // ── Custom Toast ───────────────────────────────────────
  void _showToast(String message, {bool success = true}) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 2),
                () { if (ctx.mounted) Navigator.pop(ctx); });
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 90),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: success
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFB00020),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      success
                          ? Icons.check_rounded
                          : Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(message,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              letterSpacing: 0.1,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Quiz Tab ───────────────────────────────────────────
  // NOTE: question['question'], question['category'], options text come
  // from Firestore quiz content — real data, not translated.
  Widget _buildQuizTab(String lang) {
    if (_isLoadingQuiz) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF1565C0)),
      );
    }

    if (_quizQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(AppStrings.get('no_questions_available', lang),
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: const Color(0xFF374151))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetQuiz,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: Text(AppStrings.get('try_again_btn', lang),
                  style: GoogleFonts.poppins(
                      color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_quizComplete) return _buildQuizComplete(lang);

    final question = _quizQuestions[_currentQuizIndex];
    final options = question['options'] as List<dynamic>;
    final correctAnswer = question['correct'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${AppStrings.get('question_label', lang)} ${_currentQuizIndex + 1}/${_quizQuestions.length}',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1A2E)),
              ),
              Text(
                '${AppStrings.get('score_label', lang)} $_score/${_quizQuestions.length}',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_currentQuizIndex + 1) /
                  _quizQuestions.length,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 24),

          // Question card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryLight
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question['category'] as String? ??
                        'General Knowledge',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(question['question'] as String,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Options
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value.toString();
            final isSelected = _selectedAnswer == index;
            final isCorrect = index == correctAnswer;
            final showResult = _selectedAnswer != null;

            Color bgColor = Colors.white;
            Color borderColor = Colors.grey.shade200;
            Color textColor = const Color(0xFF1A1A2E);

            if (showResult) {
              if (isCorrect) {
                bgColor = Colors.green.withOpacity(0.1);
                borderColor = Colors.green;
                textColor = Colors.green.shade700;
              } else if (isSelected && !isCorrect) {
                bgColor = Colors.red.withOpacity(0.1);
                borderColor = Colors.red;
                textColor = Colors.red.shade700;
              }
            } else if (isSelected) {
              bgColor = AppColors.primary.withOpacity(0.1);
              borderColor = AppColors.primary;
              textColor = AppColors.primary;
            }

            return GestureDetector(
              onTap: _selectedAnswer == null
                  ? () {
                setState(() {
                  _selectedAnswer = index;
                  if (index == correctAnswer) _score++;
                  _showExplanation = true;
                });
              }
                  : null,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border:
                  Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                            ['A', 'B', 'C', 'D'][index],
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(option,
                          style: TextStyle(
                              fontSize: 14,
                              color: textColor,
                              fontWeight:
                              isSelected ||
                                  (showResult && isCorrect)
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ),
                    if (showResult && isCorrect)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 20),
                    if (showResult &&
                        isSelected &&
                        !isCorrect)
                      const Icon(Icons.cancel_rounded,
                          color: Colors.red, size: 20),
                  ],
                ),
              ),
            );
          }),

          // Next button
          if (_showExplanation) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                if (_currentQuizIndex < (_quizQuestions.length - 1)) {
                  setState(() {
                    _currentQuizIndex++;
                    _selectedAnswer = null;
                    _showExplanation = false;
                  });
                } else {
                  setState(() => _quizComplete = true);
                }
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryLight
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _currentQuizIndex < (_quizQuestions.length - 1)
                        ? AppStrings.get('next_question_btn', lang)
                        : AppStrings.get('see_results_arrow_btn', lang),
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizComplete(String lang) {
    final percentage =
    (_score / _quizQuestions.length * 100).toInt();
    Color resultColor;
    String resultText;
    IconData resultIcon;

    if (percentage >= 80) {
      resultColor = const Color(0xFF10B981);
      resultText = AppStrings.get('excellent_result', lang);
      resultIcon = Icons.emoji_events_rounded;
    } else if (percentage >= 60) {
      resultColor = const Color(0xFFF59E0B);
      resultText = AppStrings.get('good_effort_result', lang);
      resultIcon = Icons.thumb_up_rounded;
    } else {
      resultColor = const Color(0xFFEF4444);
      resultText = AppStrings.get('keep_practicing_result', lang);
      resultIcon = Icons.fitness_center_rounded;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryLight
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(resultIcon,
                    color: Colors.white, size: 64),
                const SizedBox(height: 16),
                Text(resultText,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(AppStrings.get('quiz_complete_title', lang),
                    style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 16)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceAround,
                    children: [
                      _scoreItem('$_score', AppStrings.get('correct_score_label', lang),
                          const Color(0xFF10B981)),
                      _scoreItem(
                          '${_quizQuestions.length - _score}',
                          AppStrings.get('wrong_score_label', lang),
                          const Color(0xFFEF4444)),
                      _scoreItem(
                          '$percentage%', AppStrings.get('score_label_pdf', lang), Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _resetQuiz,
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white),
              label: Text(AppStrings.get('play_again_btn', lang),
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreItem(
      String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // ── PDF Tab ────────────────────────────────────────────
  // NOTE: month names (May 2026, etc.) intentionally left as-is — they're
  // calendar data, displayed alongside the translated "Current Affairs"
  // prefix and page/topic counts.
  Widget _buildPDFTab(String lang) {
    final pdfs = [
      {
        'month': 'May 2026',
        'pages': '45 Pages',
        'topics': '120 Topics',
        'size': '2.4 MB',
        'color': const Color(0xFF1565C0),
      },
      {
        'month': 'April 2026',
        'pages': '42 Pages',
        'topics': '115 Topics',
        'size': '2.1 MB',
        'color': const Color(0xFF10B981),
      },
      {
        'month': 'March 2026',
        'pages': '48 Pages',
        'topics': '130 Topics',
        'size': '2.6 MB',
        'color': const Color(0xFFE65100),
      },
      {
        'month': 'February 2026',
        'pages': '38 Pages',
        'topics': '105 Topics',
        'size': '1.9 MB',
        'color': const Color(0xFF6A1B9A),
      },
      {
        'month': 'January 2026',
        'pages': '44 Pages',
        'topics': '118 Topics',
        'size': '2.3 MB',
        'color': const Color(0xFF880E4F),
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pdfs.length,
      itemBuilder: (context, i) {
        final pdf = pdfs[i];
        final Color color = pdf['color'] as Color;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.picture_as_pdf_rounded,
                    color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${AppStrings.get('current_affairs_pdf_prefix', lang)} ${pdf['month']}',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                            const Color(0xFF1A1A2E))),
                    Text(
                        '${pdf['pages']} • ${pdf['topics']} • ${pdf['size']}',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade500)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _showToast(AppStrings.get('feature_coming_soon', lang));
                },
                icon: const Icon(Icons.download_rounded,
                    color: Colors.white, size: 16),
                label: Text(AppStrings.get('download_btn', lang),
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav(String lang) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF1565C0),
      unselectedItemColor: const Color(0xFF9CA3AF),
      selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11),
      onTap: (i) {
        switch (i) {
          case 0: Navigator.pushReplacementNamed(context, '/home'); break;
          case 1: Navigator.pushReplacementNamed(context, '/jobs'); break;
          case 2: Navigator.pushReplacementNamed(context, '/current-affairs'); break;
          case 3: Navigator.pushReplacementNamed(context, '/saved'); break;
          case 4: Navigator.pushReplacementNamed(context, '/profile'); break;
        }
      },
      items: [
        BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: AppStrings.get('nav_home', lang)),
        BottomNavigationBarItem(icon: const Icon(Icons.work_outline), activeIcon: const Icon(Icons.work), label: AppStrings.get('nav_jobs', lang)),
        BottomNavigationBarItem(icon: const Icon(Icons.newspaper_outlined), activeIcon: const Icon(Icons.newspaper), label: AppStrings.get('nav_news', lang)),
        BottomNavigationBarItem(icon: const Icon(Icons.bookmark_outline), activeIcon: const Icon(Icons.bookmark), label: AppStrings.get('nav_saved', lang)),
        BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: AppStrings.get('nav_profile', lang)),
      ],
    );
  }
}
