import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;

String? metadataText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

Uri? metadataHttpsUrl(Object? value) {
  final text = metadataText(value);
  final uri = text == null ? null : Uri.tryParse(text);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

String? metadataPlainText(Object? value) {
  final text = metadataText(value);
  if (text == null) return null;
  final fragment = html.parseFragment(text);
  for (final element in fragment.querySelectorAll('script,style')) {
    element.remove();
  }
  for (final element in fragment.querySelectorAll('p,br,div,li')) {
    element.nodes.add(dom.Text('\n'));
  }
  return metadataText(fragment.text);
}

String? metadataList(Object? value) {
  if (value is! List) return metadataText(value);
  final values = value.map(metadataText).whereType<String>().toSet();
  return values.isEmpty ? null : values.join('; ');
}
