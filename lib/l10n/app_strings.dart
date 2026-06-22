/// Simple static string lookup for app-wide UI text.
///
/// Usage: AppStrings.get('home', languageCode)
/// where languageCode comes from LanguageProvider.languageCode ('en'/'hi').
///
/// This is a lightweight first pass — no code generation, no .arb files.
/// It's easy to migrate to flutter's full intl/.arb pipeline later once
/// the switching mechanism itself is proven to work end-to-end.
///
/// Keys are grouped by screen/feature for easier navigation as this
/// file grows. Add new keys here as more screens get translated —
/// nothing else in the app needs to change to support a new key.
class AppStrings {
  static const Map<String, Map<String, String>> _strings = {
    // ── Bottom Navigation (used on every screen) ──────────
    'nav_home':            {'en': 'Home',            'hi': 'होम'},
    'nav_jobs':            {'en': 'Jobs',             'hi': 'नौकरियां'},
    'nav_news':            {'en': 'News',             'hi': 'समाचार'},
    'nav_saved':           {'en': 'Saved',            'hi': 'सेव किया'},
    'nav_profile':         {'en': 'Profile',          'hi': 'प्रोफाइल'},

    // ── Home Screen: Quick Tools ───────────────────────────
    'quick_tools_title':   {'en': 'Quick Tools',      'hi': 'त्वरित उपकरण'},
    'mock_test':           {'en': 'Mock Test',        'hi': 'मॉक टेस्ट'},
    'mock_test_sub':       {'en': 'Take a full-length test', 'hi': 'पूरी लंबाई का टेस्ट लें'},
    'quick_quiz':          {'en': 'Quick Quiz',       'hi': 'क्विक क्विज़'},
    'quick_quiz_sub':      {'en': 'Daily current affairs quiz', 'hi': 'दैनिक करंट अफेयर्स क्विज़'},
    'memory_box':          {'en': 'Memory Box',       'hi': 'मेमोरी बॉक्स'},
    'memory_box_sub':      {'en': 'Revise what you got wrong', 'hi': 'गलत उत्तरों को दोहराएं'},
    'study_material':      {'en': 'Study Material',   'hi': 'अध्ययन सामग्री'},
    'study_material_sub':  {'en': 'Notes, PYQ & Mock Tests', 'hi': 'नोट्स, पुराने प्रश्न और मॉक टेस्ट'},
    'results':             {'en': 'Results',          'hi': 'परिणाम'},
    'results_sub':         {'en': 'Check exam results', 'hi': 'परीक्षा परिणाम देखें'},
    'job_tracker':         {'en': 'Job Tracker',      'hi': 'जॉब ट्रैकर'},
    'job_tracker_sub':     {'en': 'Track applications', 'hi': 'आवेदन ट्रैक करें'},
    'admit_cards':         {'en': 'Admit Cards',      'hi': 'एडमिट कार्ड'},
    'admit_cards_sub':     {'en': 'Download hall tickets', 'hi': 'हॉल टिकट डाउनलोड करें'},
    'eligibility':         {'en': 'Eligibility',      'hi': 'पात्रता'},
    'eligibility_sub':     {'en': 'Which exams suit you', 'hi': 'आपके लिए कौन सी परीक्षा उचित है'},
    'age_calculator':      {'en': 'Age Calculator',   'hi': 'आयु कैलकुलेटर'},
    'age_calculator_sub':  {'en': 'Check age eligibility', 'hi': 'आयु पात्रता जांचें'},
    'exam_calendar':       {'en': 'Exam Calendar',    'hi': 'परीक्षा कैलेंडर'},
    'exam_calendar_sub':   {'en': 'Upcoming exam dates', 'hi': 'आगामी परीक्षा तिथियां'},
    'current_affairs':     {'en': 'Current Affairs',  'hi': 'करंट अफेयर्स'},
    'current_affairs_sub': {'en': 'Daily news & quiz', 'hi': 'दैनिक समाचार और क्विज़'},

    // ── Home Screen: Other sections ────────────────────────
    'latest_jobs':         {'en': 'Latest Jobs',      'hi': 'नवीनतम नौकरियां'},
    'upcoming_exams':      {'en': 'Upcoming Exams',   'hi': 'आगामी परीक्षाएं'},
    'see_all':             {'en': 'See All',          'hi': 'सभी देखें'},
    'search_placeholder':  {'en': 'Search jobs, departments...', 'hi': 'नौकरी, विभाग खोजें...'},
    'filter':              {'en': 'Filter',           'hi': 'फ़िल्टर'},
    'hello_greeting':      {'en': 'Hello!',           'hi': 'नमस्ते!'},
    'dream_big':           {'en': 'Dream Big,',       'hi': 'बड़ा सपना देखें,'},
    'work_hard':           {'en': 'Work Hard!',       'hi': 'कड़ी मेहनत करें!'},
    'no_jobs_available':   {'en': 'No jobs available', 'hi': 'कोई नौकरी उपलब्ध नहीं'},
    'posts_label':         {'en': 'Posts',            'hi': 'पद'},
    'exam_date_label':     {'en': 'Exam Date:',       'hi': 'परीक्षा तिथि:'},
    'new_badge':           {'en': 'NEW',              'hi': 'नया'},
    'no_internet_banner':  {'en': 'No internet connection. Please check your network.', 'hi': 'इंटरनेट कनेक्शन नहीं है। कृपया अपना नेटवर्क जांचें।'},
    'retry':               {'en': 'Retry',            'hi': 'पुनः प्रयास करें'},
    'choose_exam_title':   {'en': 'Choose Your Exam', 'hi': 'अपनी परीक्षा चुनें'},
    'choose_exam_sub':     {'en': 'Select an exam to start a mock test', 'hi': 'मॉक टेस्ट शुरू करने के लिए एक परीक्षा चुनें'},
    'states_stat':         {'en': 'States',           'hi': 'राज्य'},
    'daily_stat':          {'en': 'Daily',            'hi': 'दैनिक'},
    'updates_stat':        {'en': 'Updates',          'hi': 'अपडेट'},

    // ── Home Screen: Category filter chips ─────────────────
    'cat_railway':         {'en': 'Railway',          'hi': 'रेलवे'},
    'cat_police':          {'en': 'Police',           'hi': 'पुलिस'},
    'cat_banking':         {'en': 'Banking',          'hi': 'बैंकिंग'},
    'cat_ssc':             {'en': 'SSC',              'hi': 'एसएससी'},
    'cat_army':            {'en': 'Army',             'hi': 'सेना'},
    'cat_teaching':        {'en': 'Teaching',         'hi': 'शिक्षण'},
    'cat_health':          {'en': 'Health',           'hi': 'स्वास्थ्य'},
    'cat_more':            {'en': 'More',             'hi': 'और'},
    'cat_all':             {'en': 'All',              'hi': 'सभी'},
    'cat_upsc':            {'en': 'UPSC',             'hi': 'यूपीएससी'},

    // ── Jobs Listing Screen ─────────────────────────────────
    'all_jobs_title':      {'en': 'All Jobs',         'hi': 'सभी नौकरियां'},
    'total_jobs_label':    {'en': 'total jobs',       'hi': 'कुल नौकरियां'},
    'new_label':           {'en': 'New',              'hi': 'नई'},
    'closing_soon_label':  {'en': 'Closing Soon',     'hi': 'जल्द बंद हो रही'},
    'personalised_label':  {'en': 'Personalised',     'hi': 'व्यक्तिगत'},
    'search_jobs_hint':    {'en': 'Search jobs...',   'hi': 'नौकरी खोजें...'},
    'all_states_label':    {'en': 'All',              'hi': 'सभी'},

    // ── Saved Jobs Screen ────────────────────────────────────
    'saved_tab_label':     {'en': 'Saved',            'hi': 'सेव किया'},
    'applied_tab_label':   {'en': 'Applied',          'hi': 'आवेदन किया'},
    'my_jobs_title':       {'en': 'My Jobs',          'hi': 'मेरी नौकरियां'},
    'my_jobs_subtitle':    {'en': 'Saved and applied jobs', 'hi': 'सेव और आवेदन की गई नौकरियां'},
    'no_saved_jobs_title': {'en': 'No saved jobs yet!', 'hi': 'अभी तक कोई सेव की गई नौकरी नहीं!'},
    'no_saved_jobs_sub':   {'en': 'Browse jobs and tap Save Job to add them here', 'hi': 'नौकरियां देखें और सेव जॉब पर टैप करें'},
    'no_applied_jobs_title': {'en': 'No applied jobs yet!', 'hi': 'अभी तक कोई आवेदन नहीं!'},
    'no_applied_jobs_sub':   {'en': 'Jobs you apply for will appear here', 'hi': 'आपके द्वारा आवेदन की गई नौकरियां यहां दिखेंगी'},

    // ── Job Detail Screen: Tabs ──────────────────────────────
    'tab_overview':        {'en': 'Overview',         'hi': 'विवरण'},
    'tab_selection':       {'en': 'Selection',        'hi': 'चयन'},
    'tab_syllabus':        {'en': 'Syllabus',         'hi': 'पाठ्यक्रम'},
    'tab_papers':          {'en': 'Papers',           'hi': 'पुराने प्रश्न पत्र'},

    // ── Job Detail Screen: Overview tab ──────────────────────
    'total_vacancies':     {'en': 'Total Vacancies',  'hi': 'कुल रिक्तियां'},
    'last_date_label':     {'en': 'Last Date',        'hi': 'अंतिम तिथि'},
    'salary_label':        {'en': 'Salary',           'hi': 'वेतन'},
    'qualification_label': {'en': 'Qualification',    'hi': 'योग्यता'},
    'age_limit_section':   {'en': 'Age Limit',        'hi': 'आयु सीमा'},
    'minimum_age':         {'en': 'Minimum Age',      'hi': 'न्यूनतम आयु'},
    'maximum_age':         {'en': 'Maximum Age',      'hi': 'अधिकतम आयु'},
    'years_suffix':        {'en': 'Years',            'hi': 'वर्ष'},
    'obc_relaxation':      {'en': 'OBC Relaxation',   'hi': 'ओबीसी छूट'},
    'scst_relaxation':     {'en': 'SC/ST Relaxation', 'hi': 'एससी/एसटी छूट'},
    'application_fee_section': {'en': 'Application Fee', 'hi': 'आवेदन शुल्क'},
    'fee_details':         {'en': 'Fee Details',      'hi': 'शुल्क विवरण'},
    'general_obc_label':   {'en': 'General/OBC',      'hi': 'जनरल/ओबीसी'},
    'scst_pwd_female':     {'en': 'SC/ST/PWD/Female', 'hi': 'एससी/एसटी/पीडब्ल्यूडी/महिला'},
    'no_fee':              {'en': 'No Fee',           'hi': 'कोई शुल्क नहीं'},
    'approx_suffix':       {'en': 'approx',           'hi': 'लगभग'},
    'payment_mode':        {'en': 'Payment Mode',     'hi': 'भुगतान विधि'},
    'online_only':         {'en': 'Online Only',      'hi': 'केवल ऑनलाइन'},
    'important_dates_section': {'en': 'Important Dates', 'hi': 'महत्वपूर्ण तिथियां'},
    'last_date_to_apply':  {'en': 'Last Date to Apply', 'hi': 'आवेदन की अंतिम तिथि'},
    'exam_date_section':   {'en': 'Exam Date',        'hi': 'परीक्षा तिथि'},
    'not_announced_yet':  {'en': 'Not Announced Yet', 'hi': 'अभी घोषित नहीं हुआ'},
    'exam_pattern_section': {'en': 'Exam Pattern',    'hi': 'परीक्षा पैटर्न'},
    'pattern_label':       {'en': 'Pattern',          'hi': 'पैटर्न'},
    'important_notes_section': {'en': 'Important Notes', 'hi': 'महत्वपूर्ण सूचना'},
    'note_label':          {'en': 'Note',             'hi': 'सूचना'},
    'not_announced':       {'en': 'Not Announced',    'hi': 'घोषित नहीं'},

    // ── Job Detail Screen: Selection tab ──────────────────────
    'selection_empty_title': {'en': 'Selection process will be updated soon!', 'hi': 'चयन प्रक्रिया जल्द ही अपडेट की जाएगी!'},
    'selection_empty_sub':   {'en': 'Check official notification for details', 'hi': 'विवरण के लिए आधिकारिक सूचना देखें'},
    'selection_stages_info': {'en': 'Complete selection process has', 'hi': 'पूरी चयन प्रक्रिया में'},
    'stages_clear_info':     {'en': 'stages. Clear each stage to proceed.', 'hi': 'चरण हैं। आगे बढ़ने के लिए हर चरण पास करें।'},

    // ── Job Detail Screen: Syllabus tab ──────────────────────
    'find_syllabus_official': {'en': 'Find Syllabus on Official Website', 'hi': 'आधिकारिक वेबसाइट पर पाठ्यक्रम खोजें'},
    'syllabus_not_available': {'en': 'Syllabus not available yet', 'hi': 'पाठ्यक्रम अभी उपलब्ध नहीं है'},
    'syllabus_tap_hint':      {'en': 'Tap the button above to find the official syllabus on the government website.', 'hi': 'सरकारी वेबसाइट पर आधिकारिक पाठ्यक्रम खोजने के लिए ऊपर बटन दबाएं।'},
    'syllabus_disclaimer':    {'en': 'Always verify syllabus from official notification before starting preparation.', 'hi': 'तैयारी शुरू करने से पहले आधिकारिक सूचना से पाठ्यक्रम सत्यापित करें।'},
    'tap_to_expand':          {'en': 'Tap to expand',    'hi': 'विस्तार के लिए टैप करें'},
    'topics_suffix':          {'en': 'topics',           'hi': 'विषय'},

    // ── Job Detail Screen: Papers tab ─────────────────────────
    'papers_tap_hint':       {'en': 'Tap any source below to view & download official previous year papers.', 'hi': 'आधिकारिक पुराने प्रश्न पत्र देखने और डाउनलोड करने के लिए नीचे किसी स्रोत पर टैप करें।'},

    // ── Job Detail Screen: Buttons & toasts ───────────────────
    'mark_applied':          {'en': 'Mark Applied',     'hi': 'आवेदन किया चिह्नित करें'},
    'applied_check':         {'en': 'Applied ✅',        'hi': 'आवेदन किया ✅'},
    'apply_now_btn':         {'en': 'Apply Now →',      'hi': 'अभी आवेदन करें →'},
    'could_not_open_link':   {'en': 'Could not open link!', 'hi': 'लिंक नहीं खोल सका!'},
    'login_to_save':         {'en': 'Please login to save jobs!', 'hi': 'नौकरी सेव करने के लिए लॉगिन करें!'},
    'job_saved_toast':       {'en': 'saved! ✅',         'hi': 'सेव किया गया! ✅'},
    'save_error_toast':      {'en': 'Error saving job. Try again!', 'hi': 'नौकरी सेव करने में त्रुटि। फिर से कोशिश करें!'},
    'marked_applied_toast':  {'en': 'Marked as Applied! ✅', 'hi': 'आवेदन किया गया चिह्नित! ✅'},
    'generic_error_toast':   {'en': 'Error. Try again!', 'hi': 'त्रुटि। फिर से कोशिश करें!'},

    // ── Job Detail Screen: Mark Applied sheet ─────────────────
    'mark_as_applied_title': {'en': 'Mark as Applied',  'hi': 'आवेदन किया चिह्नित करें'},
    'reg_no_hint':           {'en': 'Registration Number (optional)', 'hi': 'पंजीकरण संख्या (वैकल्पिक)'},
    'your_category_label':  {'en': 'Your Category',    'hi': 'आपकी श्रेणी'},
    'notes_hint':            {'en': 'Notes (optional)', 'hi': 'टिप्पणी (वैकल्पिक)'},
    'confirm_applied_btn':   {'en': 'Confirm — I Applied!', 'hi': 'पुष्टि करें — मैंने आवेदन किया!'},

    // ── Study Material Screen ─────────────────────────────────
    'study_material_title': {'en': 'Study Material',  'hi': 'अध्ययन सामग्री'},
    'tab_notes':             {'en': 'Notes',           'hi': 'नोट्स'},
    'tab_pyq':               {'en': 'PYQ',             'hi': 'पुराने प्रश्न'},
    'tab_mock_test':         {'en': 'Mock Test',       'hi': 'मॉक टेस्ट'},
    'tab_quick_rev':         {'en': 'Quick Rev',       'hi': 'त्वरित रिवीजन'},
    'tab_resources':         {'en': 'Resources',       'hi': 'संसाधन'},
    'notes_suffix':          {'en': 'Notes',           'hi': 'नोट्स'},
    'topics_exam_level':     {'en': 'topics • Exam level content', 'hi': 'विषय • परीक्षा स्तर की सामग्री'},
    'previous_year_questions': {'en': 'Previous Year Questions', 'hi': 'पुराने वर्षों के प्रश्न'},
    'questions_exam_explanations': {'en': 'questions', 'hi': 'प्रश्न'},
    'with_explanations':     {'en': 'With explanations', 'hi': 'व्याख्या के साथ'},
    'questions_badge':       {'en': 'Questions',       'hi': 'प्रश्न'},
    'latest_badge':          {'en': 'Latest',          'hi': 'नवीनतम'},
    'start_practice_btn':    {'en': 'Start Practice',  'hi': 'अभ्यास शुरू करें'},
    'q_label':               {'en': 'Q',               'hi': 'प्र'},
    'score_label':           {'en': 'Score:',          'hi': 'स्कोर:'},
    'explanation_label':     {'en': 'Explanation',     'hi': 'व्याख्या'},
    'next_question_btn':     {'en': 'Next Question →', 'hi': 'अगला प्रश्न →'},
    'see_results_btn':       {'en': 'See Results',     'hi': 'परिणाम देखें'},
    'see_results_arrow_btn': {'en': 'See Results →',   'hi': 'परिणाम देखें →'},
    'practice_btn':          {'en': 'Practice',        'hi': 'अभ्यास'},
    'timed_btn':             {'en': 'Timed',           'hi': 'समय सीमा'},
    'no_mock_tests_yet':     {'en': 'No mock tests yet for', 'hi': 'अभी कोई मॉक टेस्ट नहीं है'},
    'adding_tests_soon':     {'en': "We're adding more tests soon — check back later!", 'hi': 'हम जल्द ही और टेस्ट जोड़ रहे हैं — बाद में देखें!'},
    'could_not_load_mocks':  {'en': 'Could not load mock tests', 'hi': 'मॉक टेस्ट लोड नहीं हो सका'},
    'check_connection_retry': {'en': 'Check your internet connection and try again.', 'hi': 'अपना इंटरनेट कनेक्शन जांचें और फिर कोशिश करें।'},
    'could_not_load_test':   {'en': 'Could not load this test. Please try again.', 'hi': 'यह टेस्ट लोड नहीं हो सका। फिर कोशिश करें।'},
    'excellent_result':      {'en': 'Excellent! 🎉',    'hi': 'बहुत बढ़िया! 🎉'},
    'good_effort_result':    {'en': 'Good Effort! 👍',  'hi': 'अच्छा प्रयास! 👍'},
    'keep_practicing_result':{'en': 'Keep Practicing! 💪', 'hi': 'अभ्यास जारी रखें! 💪'},
    'out_of_correct':        {'en': 'out of',           'hi': 'में से'},
    'correct_suffix':        {'en': 'correct',          'hi': 'सही'},
    'outstanding_performance': {'en': 'Outstanding Performance!', 'hi': 'उत्कृष्ट प्रदर्शन!'},
    'on_right_track':         {'en': 'You are on the right track!', 'hi': 'आप सही रास्ते पर हैं!'},
    'dont_give_up':           {'en': "Don't give up — practice more!", 'hi': 'हार न मानें — और अभ्यास करें!'},
    'exam_ready_msg':         {'en': 'You are exam ready. Keep this pace!', 'hi': 'आप परीक्षा के लिए तैयार हैं। यह गति बनाए रखें!'},
    'focus_weak_areas':       {'en': 'Focus on weak areas to score 70%+', 'hi': '70%+ स्कोर के लिए कमजोर क्षेत्रों पर ध्यान दें'},
    'revise_attempt_again':   {'en': 'Revise notes and attempt again', 'hi': 'नोट्स दोहराएं और फिर प्रयास करें'},
    'topic_wise_analysis':    {'en': '📊 Topic-wise Analysis', 'hi': '📊 विषय-वार विश्लेषण'},
    'recommendations_title':  {'en': '💡 Recommendations', 'hi': '💡 सुझाव'},
    'strong_label':           {'en': '✅ Strong',         'hi': '✅ मजबूत'},
    'average_label':          {'en': '⚠️ Average',       'hi': '⚠️ औसत'},
    'weak_label':             {'en': '❌ Weak',           'hi': '❌ कमजोर'},
    'accuracy_suffix':        {'en': 'accuracy',          'hi': 'सटीकता'},
    'try_again_btn':          {'en': 'Try Again',         'hi': 'फिर कोशिश करें'},
    'back_to_tests_btn':      {'en': 'Back to Tests',     'hi': 'टेस्ट पर वापस जाएं'},
    'free_resources_for':     {'en': 'Free Resources —',  'hi': 'मुफ्त संसाधन —'},
    'official_govt_sites_only': {'en': 'Official government websites only', 'hi': 'केवल आधिकारिक सरकारी वेबसाइटें'},
    'resources_disclaimer':   {'en': 'All links open official government websites only. Internet connection required.', 'hi': 'सभी लिंक केवल आधिकारिक सरकारी वेबसाइटें खोलते हैं। इंटरनेट कनेक्शन आवश्यक है।'},

    // ── Current Affairs Screen ────────────────────────────────
    'current_affairs_title':  {'en': 'Current Affairs',  'hi': 'करंट अफेयर्स'},
    'stay_updated_subtitle':  {'en': 'Stay updated for your exams!', 'hi': 'अपनी परीक्षाओं के लिए अपडेट रहें!'},
    'tab_todays_news':        {'en': "Today's News",     'hi': 'आज की खबरें'},
    'tab_daily_quiz':         {'en': 'Daily Quiz',        'hi': 'दैनिक क्विज़'},
    'tab_monthly_pdf':        {'en': 'Monthly PDF',       'hi': 'मासिक पीडीएफ'},
    'todays_articles_stat':   {'en': "Today's\nArticles", 'hi': 'आज के\nलेख'},
    'quiz_questions_stat':    {'en': 'Quiz\nQuestions',   'hi': 'क्विज़\nप्रश्न'},
    'news_sources_stat':      {'en': 'News\nSources',     'hi': 'समाचार\nस्रोत'},
    'loading_news':           {'en': 'Loading latest news...', 'hi': 'नवीनतम समाचार लोड हो रहे हैं...'},
    'could_not_load_news':    {'en': 'Could not load news', 'hi': 'समाचार लोड नहीं हो सका'},
    'check_internet_connection': {'en': 'Please check your internet connection', 'hi': 'कृपया अपना इंटरनेट कनेक्शन जांचें'},
    'no_articles_found':      {'en': 'No articles found', 'hi': 'कोई लेख नहीं मिला'},
    'show_all_btn':           {'en': 'Show All',          'hi': 'सभी दिखाएं'},
    'read_more_btn':          {'en': 'Read More →',       'hi': 'और पढ़ें →'},
    'link_not_available':     {'en': 'Link not available', 'hi': 'लिंक उपलब्ध नहीं है'},
    'unable_to_open_link':    {'en': 'Unable to open link', 'hi': 'लिंक नहीं खुल सका'},
    'no_questions_available': {'en': 'No questions available', 'hi': 'कोई प्रश्न उपलब्ध नहीं'},
    'question_label':         {'en': 'Question',          'hi': 'प्रश्न'},
    'quiz_complete_title':     {'en': 'Quiz Complete!',    'hi': 'क्विज़ पूरा हुआ!'},
    'play_again_btn':          {'en': 'Play Again',        'hi': 'फिर से खेलें'},
    'correct_score_label':     {'en': 'Correct',           'hi': 'सही'},
    'wrong_score_label':       {'en': 'Wrong',             'hi': 'गलत'},
    'score_label_pdf':         {'en': 'Score',             'hi': 'स्कोर'},
    'current_affairs_pdf_prefix': {'en': 'Current Affairs', 'hi': 'करंट अफेयर्स'},
    'download_btn':            {'en': 'Download',          'hi': 'डाउनलोड'},
    'feature_coming_soon':     {'en': 'This feature is coming soon', 'hi': 'यह सुविधा जल्द आ रही है'},

    // ── Profile Screen ──────────────────────────────────────
    'my_profile':          {'en': 'My Profile',       'hi': 'मेरी प्रोफाइल'},
    'edit':                {'en': 'Edit',             'hi': 'संपादित करें'},
    'saved_stat':          {'en': 'Saved',            'hi': 'सेव किया'},
    'applied_stat':        {'en': 'Applied',          'hi': 'आवेदन किया'},
    'selected_stat':       {'en': 'Selected',         'hi': 'चयनित'},
    'tracked_stat':        {'en': 'Tracked',          'hi': 'ट्रैक किया'},
    'quick_access':        {'en': 'Quick Access',     'hi': 'त्वरित प्रवेश'},
    'notifications':       {'en': 'Notifications',    'hi': 'सूचनाएं'},
    'app_settings':        {'en': 'App Settings',     'hi': 'ऐप सेटिंग्स'},
    'language':            {'en': 'Language',         'hi': 'भाषा'},
    'privacy_policy':      {'en': 'Privacy Policy',   'hi': 'गोपनीयता नीति'},
    'terms_of_service':    {'en': 'Terms of Service', 'hi': 'सेवा की शर्तें'},
    'rate_the_app':        {'en': 'Rate the App',     'hi': 'ऐप को रेट करें'},
    'share_with_friends':  {'en': 'Share with Friends', 'hi': 'मित्रों के साथ साझा करें'},
    'logout':              {'en': 'Logout',           'hi': 'लॉग आउट'},
    'logout_confirm':      {'en': 'Are you sure you want to logout?', 'hi': 'क्या आप वाकई लॉग आउट करना चाहते हैं?'},
    'cancel':              {'en': 'Cancel',           'hi': 'रद्द करें'},
  };

  /// Returns the string for [key] in the given [languageCode] ('en'/'hi').
  /// Falls back to English if the key or language is missing, and to the
  /// key itself (visibly obvious placeholder) if even English is missing —
  /// this makes any translation gap easy to spot during testing rather
  /// than crashing or showing a blank label.
  static String get(String key, String languageCode) {
    final entry = _strings[key];
    if (entry == null) return key;
    return entry[languageCode] ?? entry['en'] ?? key;
  }
}
