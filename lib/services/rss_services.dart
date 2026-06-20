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
  static const List<Map<String, String>> _feeds = [
    {
      'url': 'https://pib.gov.in/rssfeed/rss.aspx',
      'source': 'PIB India',
      'category': 'Government',
    },
    {
      'url': 'https://www.jagranjosh.com/current-affairs/rss',
      'source': 'Jagran Josh',
      'category': 'Current Affairs',
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
      }
    }
    allArticles.sort((a, b) => b.pubDate.compareTo(a.pubDate));
    return allArticles;
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
          'User-Agent': 'ExamTrack/1.0',
          'Accept': 'application/rss+xml, application/xml',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final document = XmlDocument.parse(response.body);
      final items = document.findAllElements('item');

      return items.map((item) {
        final title = item.findElements('title').isNotEmpty
            ? _cleanText(
            item.findElements('title').first.innerText)
            : 'No Title';

        final description =
        item.findElements('description').isNotEmpty
            ? _cleanText(item
            .findElements('description')
            .first
            .innerText)
            : '';

        final link = item.findElements('link').isNotEmpty
            ? item.findElements('link').first.innerText.trim()
            : '';

        final pubDate =
        item.findElements('pubDate').isNotEmpty
            ? item
            .findElements('pubDate')
            .first
            .innerText
            .trim()
            : '';

        return RssArticle(
          title: title,
          description: description.length > 200
              ? '${description.substring(0, 200)}...'
              : description,
          link: link,
          pubDate: pubDate,
          source: source,
          category: category,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('\n', ' ')
        .trim();
  }
}
