import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Extract only the published document, never the registration form, scripts,
/// modal controls or a copied (and potentially outdated) mobile version.
dom.Element parseLegalDocument(String source, {required bool contract}) {
  final document = html.parse(source);
  final content = document.querySelector(
    contract ? '#contract-modal .modal-content' : 'main.page',
  );
  if (content == null) {
    throw const FormatException('Yayınlanan metin bulunamadı.');
  }
  for (final control in content.querySelectorAll(
    'script, style, .modal-close, .back',
  )) {
    control.remove();
  }
  if (content.text.trim().isEmpty) {
    throw const FormatException('Yayınlanan metin boş.');
  }
  return content;
}

class LegalDocumentPage extends StatefulWidget {
  final Uri source;
  final bool contract;
  final http.Client? client;

  const LegalDocumentPage({
    super.key,
    required this.source,
    required this.contract,
    this.client,
  });

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  late final http.Client _client = widget.client ?? http.Client();
  late Future<dom.Element> _document = _load();
  final Map<Uri, TapGestureRecognizer> _links = {};

  Future<dom.Element> _load() async {
    final response =
        await _client.get(widget.source).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const FormatException('Metin yüklenemedi.');
    }
    // Nginx may return text/html without charset. These shared web sources are
    // UTF-8, so response.body's ISO-8859-1 fallback would corrupt Turkish text.
    return parseLegalDocument(
      utf8.decode(response.bodyBytes),
      contract: widget.contract,
    );
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    for (final recognizer in _links.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer? _link(dom.Element element) {
    final href = element.attributes['href'];
    if (element.localName != 'a' || href == null) return null;
    final target = widget.source.resolve(href);
    if (!const ['http', 'https', 'mailto'].contains(target.scheme)) return null;
    return _links.putIfAbsent(
      target,
      () => TapGestureRecognizer()
        ..onTap = () async {
          try {
            await launchUrl(target, mode: LaunchMode.externalApplication);
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bağlantı açılamadı.')),
            );
          }
        },
    );
  }

  Future<void> _openWeb() async {
    try {
      if (await launchUrl(widget.source,
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Keep the page usable if no external browser is available.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Web sayfası açılamadı. Lütfen tekrar deneyin.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff1e293b),
        title: Text(
          widget.contract ? 'Üyelik Taahhüt Metni' : 'KVKK Aydınlatma Metni',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Webde aç',
            onPressed: _openWeb,
            icon: const Icon(Icons.open_in_new, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<dom.Element>(
          future: _document,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.description_outlined, size: 36),
                      const SizedBox(height: 16),
                      const Text(
                        'Metin yüklenemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {
                          _document = _load();
                        }),
                        child: const Text('Tekrar dene'),
                      ),
                      TextButton(
                        onPressed: _openWeb,
                        child: const Text('Web sayfasında aç'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return Scrollbar(
              child: SingleChildScrollView(
                key: const ValueKey('legal-document-scroll'),
                padding: const EdgeInsets.only(bottom: 24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 920),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 24,
                    ),
                    color: Colors.white,
                    child: SelectionArea(
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          height: 1.7,
                          color: Color(0xff1e293b),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _blocks(snapshot.data!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _blocks(dom.Element parent) => [
        for (final element in parent.children) _block(element),
      ];

  Widget _block(dom.Element element) {
    final tag = element.localName ?? '';
    if (RegExp(r'^h[1-6]$').hasMatch(tag)) {
      final major = tag == 'h1' || tag == 'h3';
      return Padding(
        padding: EdgeInsets.only(top: major ? 0 : 24, bottom: 12),
        child: Text.rich(
          TextSpan(children: _spans(element.nodes)),
          style: TextStyle(
            fontSize: major ? (widget.contract ? 21 : 27) : 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: major ? const Color(0xff1e293b) : const Color(0xff0f3f8c),
          ),
        ),
      );
    }
    if (tag == 'ul' || tag == 'ol') {
      final items = element.children.where((child) => child.localName == 'li');
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, item) in items.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 22,
                        child: Text(tag == 'ol' ? '${index + 1}.' : '•')),
                    Expanded(
                        child:
                            Text.rich(TextSpan(children: _spans(item.nodes)))),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    if (tag == 'table') {
      final rows = element.querySelectorAll('tr');
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        child: Table(
          border: TableBorder.all(color: const Color(0xffcbd5e1)),
          columnWidths: const {
            0: FlexColumnWidth(1.1),
            1: FlexColumnWidth(2),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            for (final row in rows)
              TableRow(
                decoration: row.querySelector('th') == null
                    ? null
                    : const BoxDecoration(color: Color(0xffeff6ff)),
                children: [
                  for (final cell in row.children)
                    Padding(
                      padding: const EdgeInsets.all(9),
                      child: Text.rich(
                        TextSpan(children: _spans(cell.nodes)),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          fontWeight: cell.localName == 'th'
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    }
    if (tag == 'div' || tag == 'section') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _blocks(element),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text.rich(
        TextSpan(children: _spans(element.nodes)),
        style: element.classes.contains('meta')
            ? const TextStyle(color: Color(0xff64748b))
            : null,
      ),
    );
  }

  List<InlineSpan> _spans(List<dom.Node> nodes) => [
        for (final node in nodes)
          if (node is dom.Text)
            TextSpan(text: node.data.replaceAll(RegExp(r'\s+'), ' '))
          else if (node is dom.Element)
            if (node.localName == 'br')
              const TextSpan(text: '\n')
            else
              TextSpan(
                children: _spans(node.nodes),
                recognizer: _link(node),
                style: TextStyle(
                  fontWeight: const ['b', 'strong'].contains(node.localName)
                      ? FontWeight.w700
                      : null,
                  fontStyle: const ['i', 'em'].contains(node.localName)
                      ? FontStyle.italic
                      : null,
                  color: node.localName == 'a' ? const Color(0xff2563eb) : null,
                  decoration:
                      node.localName == 'a' ? TextDecoration.underline : null,
                ),
              ),
      ];
}
