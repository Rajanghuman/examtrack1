import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class RssArticle {
  final String title;
  final String description;
  final String link;
  final String pubDate;
  final String source;
  final String category;

  RssArticle({
    required this.title,
    required this.description,
    required this.link,
    required this.pubDate,
    required this.source,
    required this.category,
  });
}

class RssService {
  // ── Verified working RSS feeds (June 2026) ─────────────
  static const List<Map<String, String>> _feeds = [
    {
      'url': 'https://www.thehindu.com/news/national/feeder/default.rss',
      'source': 'The Hindu',
      'category': 'National',
    },
    {
      'url': 'https://feeds.feedburner.com/ndtvnews-india-news',
      'source': 'NDTV India',
      'category': 'Current Affairs',
    },
    {
      'url': 'https://www.indiatoday.in/rss/home',
      'source': 'India Today',
      'category': 'Current Affairs',
    },
    {
      'url': 'https://economictimes.indiatimes.com/news/economy/rssfeeds/1373380680.cms',
      'source': 'Economic Times',
      'category': 'Economy',
    },
    {
      'url': 'https://gktoday.in/feed',
      'source': 'GK Today',
      'category': 'GK & Current Affairs',
    },
  ];

  static Future<List<RssArticle>> fetchAllArticles() async {
    List<RssArticle> allArticles = [];
    for (final feed in _feeds) {
      try {
        final articles = await _fetchFeed(
          url: feed['url']!,
          source: feed['source']!,
          category: feed['category']!,
        );
        allArticles.addAll(articles);
      } catch (e) {
        print('Error fetching ${feed['source']}: $e');
      }
    }

    // Sort by pubDate descending — keep as string sort if parsing fails
    allArticles.sort((a, b) {
      try {
        final da = _parseDate(a.pubDate);
        final db = _parseDate(b.pubDate);
        if (da != null && db != null) return db.compareTo(da);
      } catch (_) {}
      return b.pubDate.compareTo(a.pubDate);
    });

    return allArticles;
  }

  static DateTime? _parseDate(String raw) {
    try {
      // RFC 822 format: "Mon, 02 Jun 2026 10:30:00 +0000"
      // Try standard ISO first
      return DateTime.parse(raw);
    } catch (_) {
      try {
        // Strip timezone name suffix if present e.g. " IST"
        final cleaned = raw
            .replaceAll(RegExp(r'\s+[A-Z]{2,4}$'), '')
            .trim();
        // Parse common RSS date format manually
        final months = {
          'Jan': '01', 'Feb': '02', 'Mar': '03', 'Apr': '04',
          'May': '05', 'Jun': '06', 'Jul': '07', 'Aug': '08',
          'Sep': '09', 'Oct': '10', 'Nov': '11', 'Dec': '12',
        };
        // "02 Jun 2026 10:30:00 +0000" or "Mon, 02 Jun 2026 ..."
        final parts = cleaned.split(' ');
        if (parts.length >= 4) {
          // skip weekday if present
          int offset = parts[0].contains(',') ? 1 : 0;
          final day  = parts[offset].padLeft(2, '0');
          final mon  = months[parts[offset + 1]] ?? '01';
          final year = parts[offset + 2];
          final time = parts.length > offset + 3
              ? parts[offset + 3]
              : '00:00:00';
          return DateTime.parse('$year-$mon-${day}T$time');
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<List<RssArticle>> _fetchFeed({
    required String url,
    required String source,
    required String category,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) ExamTrack/1.0',
          'Accept':
          'application/rss+xml, application/xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        print('Feed $source returned ${response.statusCode}');
        return [];
      }

      final body = response.body;
      if (body.isEmpty) return [];

      final document = XmlDocument.parse(body);

      // Support both RSS <item> and Atom <entry>
      final items = document.findAllElements('item').isNotEmpty
          ? document.findAllElements('item').toList()
          : document.findAllElements('entry').toList();

      return items.take(15).map((item) {
        // Title
        final title = _getElementText(item, 'title');

        // Description — try multiple tag names
        String description = _getElementText(item, 'description');
        if (description.isEmpty) {
          description = _getElementText(item, 'summary');
        }
        if (description.isEmpty) {
          description = _getElementText(item, 'content');
        }

        // Link — handle both <link> text and href attribute
        String link = '';
        final linkEl = item.findElements('link');
        if (linkEl.isNotEmpty) {
          final href = linkEl.first.getAttribute('href');
          link = href ?? linkEl.first.innerText.trim();
        }
        if (link.isEmpty) {
          final guidEl = item.findElements('guid');
          if (guidEl.isNotEmpty) {
            link = guidEl.first.innerText.trim();
          }
        }

        // Date
        String pubDate = _getElementText(item, 'pubDate');
        if (pubDate.isEmpty) {
          pubDate = _getElementText(item, 'published');
        }
        if (pubDate.isEmpty) {
          pubDate = _getElementText(item, 'updated');
        }

        final cleanDesc = _cleanText(description);

        return RssArticle(
          title: title.isNotEmpty ? title : 'No Title',
          description: cleanDesc.length > 220
              ? '${cleanDesc.substring(0, 220)}...'
              : cleanDesc,
          link: link,
          pubDate: pubDate,
          source: source,
          category: category,
        );
      }).where((a) => a.title != 'No Title' || a.link.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error parsing feed $url: $e');
      return [];
    }
  }

  static String _getElementText(XmlElement item, String tag) {
    try {
      final els = item.findElements(tag);
      if (els.isEmpty) return '';
      // Prefer innerText, fall back to text content
      final text = els.first.innerText.trim();
      return _cleanText(text);
    } catch (_) {
      return '';
    }
  }

  static String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')   // strip HTML tags
        .replaceAll(RegExp(r'\!\[CDATA\['), '') // strip CDATA
        .replaceAll(RegExp(r'\]\]>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}