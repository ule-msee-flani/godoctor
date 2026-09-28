/// Reads a stock list exported from a pharmacy system (CSV) or copied out of
/// a spreadsheet (tab-separated) into rows of name, quantity and price.
/// Pure Dart, so it can be tested.
library;

/// One medicine line from the file.
class StockLine {
  const StockLine({
    required this.line,
    required this.name,
    required this.quantity,
    required this.price,
  });

  /// Line number in the file (1-based), for messages.
  final int line;
  final String name;
  final int quantity;
  final double price;
}

class StockTable {
  const StockTable({
    required this.lines,
    required this.skipped,
    required this.columns,
  });

  final List<StockLine> lines;

  /// Why some lines were left out ("Line 7: no price").
  final List<String> skipped;

  /// Which columns were read, for "We read: Item name · Qty · Selling price".
  final ({String name, String quantity, String price}) columns;
}

/// At most this many medicines in one import (the server's limit too).
const maxImportLines = 2000;

const _nameWords = [
  'name',
  'product',
  'item',
  'description',
  'drug',
  'medicine',
  'generic',
  'brand',
];
const _qtyWords = [
  'qty',
  'quantity',
  'stock',
  'balance',
  'on hand',
  'soh',
  'units',
  'count',
];
// Selling price first; what the pharmacy paid only if nothing else.
const _priceWords = [
  'selling',
  'retail',
  'sale price',
  'unit price',
  'price',
  'mrp',
  'sp',
];
const _costWords = ['cost', 'buying', 'purchase', 'bp'];

StockTable parseStockTable(String text) {
  final raw = text.replaceFirst('﻿', '');
  final rows = <(int, List<String>)>[];
  final allLines = raw.split(RegExp(r'\r\n|\n|\r'));
  if (allLines.every((l) => l.trim().isEmpty)) {
    return const StockTable(
      lines: [],
      skipped: [],
      columns: (name: '', quantity: '', price: ''),
    );
  }
  final delimiter = _delimiterOf(
    allLines.firstWhere((l) => l.trim().isNotEmpty),
  );
  for (var i = 0; i < allLines.length; i++) {
    if (allLines[i].trim().isEmpty) continue;
    rows.add((i + 1, _split(allLines[i], delimiter)));
  }

  // A header row names the columns; without one, assume name, qty, price.
  final header = rows.first.$2.map((c) => c.trim().toLowerCase()).toList();
  final first = rows.first.$2;
  // "Brand X syrup,10,50" is data even though it says "brand".
  final looksLikeData =
      first.length >= 3 &&
      _number(first[1].trim(), delimiter) != null &&
      _number(first[2].trim(), delimiter) != null;
  final hasHeader =
      !looksLikeData &&
      header.any(
        (c) =>
            _matches(c, _nameWords) ||
            _matches(c, _qtyWords) ||
            _matches(c, _priceWords),
      );
  int? find(List<String> words, {List<String> avoid = const []}) {
    for (final w in words) {
      for (var i = 0; i < header.length; i++) {
        final c = header[i];
        if (_matches(c, [w]) && !_matches(c, avoid)) return i;
      }
    }
    return null;
  }

  final nameCol = hasHeader
      ? find(_nameWords, avoid: [..._qtyWords, ..._priceWords]) ?? 0
      : 0;
  final qtyCol = hasHeader ? find(_qtyWords) ?? 1 : 1;
  final priceCol = hasHeader
      ? find(_priceWords, avoid: _costWords) ?? find(_costWords) ?? 2
      : 2;
  String label(int i, String fallback) =>
      hasHeader &&
          i < rows.first.$2.length &&
          rows.first.$2[i].trim().isNotEmpty
      ? rows.first.$2[i].trim()
      : fallback;

  final lines = <StockLine>[];
  final skipped = <String>[];
  for (final (lineNo, cells) in rows.skip(hasHeader ? 1 : 0)) {
    String cell(int i) => i < cells.length ? cells[i].trim() : '';
    final name = cell(nameCol).replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) {
      skipped.add('Line $lineNo: no medicine name');
      continue;
    }
    final qty = _number(cell(qtyCol), delimiter);
    final price = _number(cell(priceCol), delimiter);
    if (qty == null) {
      skipped.add('Line $lineNo ($name): no quantity');
      continue;
    }
    if (price == null) {
      skipped.add('Line $lineNo ($name): no price');
      continue;
    }
    if (lines.length >= maxImportLines) {
      skipped.add(
        'Only the first $maxImportLines medicines are imported at once',
      );
      break;
    }
    lines.add(
      StockLine(
        line: lineNo,
        name: name,
        quantity: qty.round().clamp(0, 100000),
        price: price.clamp(0, 1000000).toDouble(),
      ),
    );
  }
  return StockTable(
    lines: lines,
    skipped: skipped,
    columns: (
      name: label(nameCol, 'Column 1'),
      quantity: label(qtyCol, 'Column 2'),
      price: label(priceCol, 'Column 3'),
    ),
  );
}

bool _matches(String cell, List<String> words) => words.any(
  (w) => w.length <= 3
      ? RegExp('(^|[^a-z])${RegExp.escape(w)}([^a-z]|\$)').hasMatch(cell)
      : cell.contains(w),
);

String _delimiterOf(String firstLine) {
  var best = ',';
  var most = -1;
  for (final d in ['\t', ',', ';', '|']) {
    final n = d.allMatches(firstLine).length;
    if (n > most) {
      most = n;
      best = d;
    }
  }
  return best;
}

/// Splits one line, honouring "quoted, cells" and "" escapes.
List<String> _split(String line, String d) {
  final out = <String>[];
  final cur = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cur.write(ch);
      }
    } else if (ch == '"' && cur.toString().trim().isEmpty) {
      quoted = true;
      cur.clear();
    } else if (ch == d) {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(ch);
    }
  }
  out.add(cur.toString());
  return out;
}

/// "1,200", "KES 45.50", "Ksh 30", "12,5" (with ; files) -> number.
double? _number(String s, String delimiter) {
  var v = s.toLowerCase().replaceAll(RegExp(r'kes|ksh|kshs|/=|\s'), '');
  if (v.isEmpty) return null;
  if (delimiter == ';' && RegExp(r'^\d+,\d{1,2}$').hasMatch(v)) {
    v = v.replaceAll(',', '.');
  } else {
    v = v.replaceAll(',', '');
  }
  final n = double.tryParse(v);
  return n == null || n.isNaN || n < 0 ? null : n;
}
