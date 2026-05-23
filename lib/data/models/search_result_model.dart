List<Map<String, dynamic>> searchEngineApis() => [
      {
        'name': 'Bing Search',
        'url': 'https://api.bing.microsoft.com/v7.0/search',
        'key': '',
      },
      {
        'name': 'SerpAPI',
        'url': 'https://serpapi.com/search',
        'key': '',
      },
    ];

class SearchResult {
  final String title;
  final String url;
  final String snippet;

  SearchResult({required this.title, required this.url, required this.snippet});

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        title: json['title'] ?? json['name'] ?? '',
        url: json['url'] ?? json['link'] ?? '',
        snippet: json['snippet'] ?? json['snippet_highlighted_words']?.join(' ') ?? '',
      );
}
