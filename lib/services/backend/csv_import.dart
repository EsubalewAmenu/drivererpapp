/// Parses CSV including quoted separators, escaped quotes and multiline cells.
List<List<String>> parseCsv(String input) {
  final text = input.startsWith('\uFEFF') ? input.substring(1) : input;
  final rows = <List<String>>[];
  var row = <String>[];
  final value = StringBuffer();
  var quoted = false;
  var closedQuote = false;
  void finishCell() {
    row.add(value.toString());
    value.clear();
    closedQuote = false;
  }

  void finishRow() {
    finishCell();
    rows.add(row);
    row = [];
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          value.write('"');
          i++;
        } else {
          quoted = false;
          closedQuote = true;
        }
      } else {
        value.write(char);
      }
    } else if (char == ',') {
      finishCell();
    } else if (char == '\n' || char == '\r') {
      finishRow();
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
    } else if (char == '"' && value.isEmpty && !closedQuote) {
      quoted = true;
    } else {
      if (closedQuote || char == '"') {
        throw const FormatException('Invalid CSV quoting');
      }
      value.write(char);
    }
  }
  if (quoted) throw const FormatException('Unclosed CSV quotation');
  if (value.isNotEmpty || row.isNotEmpty || closedQuote) finishRow();
  while (rows.isNotEmpty && rows.last.every((cell) => cell.isEmpty)) {
    rows.removeLast();
  }
  if (rows.isEmpty) throw const FormatException('The CSV file is empty');
  final seen = <String>{};
  rows[0] = rows[0].asMap().entries.map((entry) {
    final raw = entry.value.trim();
    final base = raw.isEmpty ? 'column_${entry.key + 1}' : raw;
    var key = base;
    var suffix = 2;
    while (!seen.add(key)) {
      key = '${base}_${suffix++}';
    }
    return key;
  }).toList();
  return rows;
}
