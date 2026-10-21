// 유니코드로 적힌 수식(예: `lim(n→∞) (3n² + 1)/(n² + n)`)을 LaTeX로 바꿔 조판하기 위한 변환기.
//
// 문제 데이터는 수식을 `²`, `₁`, `√`, `1/2` 같은 유니코드·ASCII 텍스트로 적어 두었다.
// 데이터를 건드리지 않고(정답 채점은 원문 그대로) 화면에 그릴 때만 수식 구간을 찾아
// TeX로 변환한다. 변환이 불확실하거나 파싱에 실패하면 원문을 그대로 보여준다.

/// 텍스트 조각. [tex]가 null이면 일반 글자, 아니면 [text] 자리에 그릴 수식.
class MathSeg {
  final String text; // 원문
  final String? tex; // 수식이면 변환 결과
  const MathSeg(this.text, [this.tex]);
  bool get isMath => tex != null;
}

final _cache = <String, List<MathSeg>>{}; // 삽입 순서 유지(LinkedHashMap)

/// [source]를 글자/수식 조각으로 나눈다. `$...$`가 이미 있으면 호출하지 말 것.
/// [wholeIfMath]가 true이고 문자열 전체가 수식 문자로만 이뤄졌으면 숫자만 있어도 수식으로 본다
/// (보기 `2`, `16`, `1/2`가 섞여도 글꼴이 같게 보이도록).
List<MathSeg> splitMath(String source, {bool wholeIfMath = false}) {
  final key = wholeIfMath ? '1$source' : '0$source';
  final hit = _cache.remove(key);
  if (hit != null) {
    _cache[key] = hit;
    return hit;
  }
  final out = _split(source, wholeIfMath);
  _cache[key] = out;
  if (_cache.length > 800) _cache.remove(_cache.keys.first);
  return out;
}

// ───────────────────────── 문자 분류 ─────────────────────────

const _supMap = {
  '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4', '⁵': '5', '⁶': '6',
  '⁷': '7', '⁸': '8', '⁹': '9', '⁺': '+', '⁻': '-', '⁼': '=', '⁽': '(',
  '⁾': ')', 'ⁿ': 'n', 'ⁱ': 'i', 'ˣ': 'x', 'ʸ': 'y', 'ᵃ': 'a', 'ᵇ': 'b',
  'ᶜ': 'c', 'ᵈ': 'd', 'ᵉ': 'e', 'ᵏ': 'k', 'ᵐ': 'm', 'ᵗ': 't', 'ᵘ': 'u',
  'ʳ': 'r', 'ˢ': 's', 'ᵖ': 'p', 'ᵍ': 'g', 'ʰ': 'h', 'ʲ': 'j', 'ˡ': 'l',
  'ᵒ': 'o', 'ᵛ': 'v', 'ʷ': 'w', 'ᶠ': 'f', 'ᶻ': 'z', 'ᶿ': 'θ',
};
const _subMap = {
  '₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4', '₅': '5', '₆': '6',
  '₇': '7', '₈': '8', '₉': '9', '₊': '+', '₋': '-', '₌': '=', '₍': '(',
  '₎': ')', 'ₐ': 'a', 'ₑ': 'e', 'ₕ': 'h', 'ᵢ': 'i', 'ⱼ': 'j', 'ₖ': 'k',
  'ₗ': 'l', 'ₘ': 'm', 'ₙ': 'n', 'ₒ': 'o', 'ₚ': 'p', 'ᵣ': 'r', 'ₛ': 's',
  'ₜ': 't', 'ᵤ': 'u', 'ᵥ': 'v', 'ₓ': 'x',
};

/// 기호 → TeX. 값 앞뒤 공백은 TeX가 알아서 간격을 둔다.
const _symTex = {
  '−': '-', '–': '-', '×': r'\times ', '÷': r'\div ', '·': r'\cdot ',
  '∙': r'\cdot ', '±': r'\pm ', '∓': r'\mp ', '≤': r'\le ', '≥': r'\ge ',
  '≠': r'\ne ', '≈': r'\approx ', '≒': r'\approx ', '≡': r'\equiv ',
  '∞': r'\infty ', '→': r'\to ', '←': r'\leftarrow ', '↔': r'\leftrightarrow ',
  '⟹': r'\Rightarrow ', '⇒': r'\Rightarrow ', '⟺': r'\Leftrightarrow ',
  '⇔': r'\Leftrightarrow ', '∈': r'\in ', '∉': r'\notin ', '⊂': r'\subset ',
  '⊆': r'\subseteq ', '⊊': r'\subsetneq ', '⊄': r'\not\subset ',
  '⊃': r'\supset ', '∪': r'\cup ', '∩': r'\cap ', '∅': r'\emptyset ',
  '∠': r'\angle ', '△': r'\triangle ', '∥': r'\parallel ', '⊥': r'\perp ',
  '∽': r'\sim ', '∼': r'\sim ', '~': r'\sim ', 'ℓ': r'\ell ', '∘': r'\circ ',
  '∴': r'\therefore ', '⋯': r'\cdots ', '…': r'\cdots ', '°': r'^\circ ',
  '′': "'", '″': "''", '%': r'\% ', '∝': r'\propto ', '∀': r'\forall ',
  '∃': r'\exists ', '∂': r'\partial ', '∆': r'\Delta ', 'Δ': r'\Delta ',
  'Ω': r'\Omega ', 'Θ': r'\Theta ', 'Φ': r'\Phi ', 'Ψ': r'\Psi ',
  'π': r'\pi ', 'θ': r'\theta ', 'α': r'\alpha ', 'β': r'\beta ',
  'γ': r'\gamma ', 'δ': r'\delta ', 'ε': r'\varepsilon ', 'λ': r'\lambda ',
  'μ': r'\mu ', 'σ': r'\sigma ', 'ρ': r'\rho ', 'φ': r'\varphi ',
  'ω': r'\omega ', 'τ': r'\tau ', 'η': r'\eta ', 'ξ': r'\xi ', 'ζ': r'\zeta ',
  'κ': r'\kappa ', 'ν': r'\nu ', 'χ': r'\chi ', 'ψ': r'\psi ', 'ι': r'\iota ',
  '*': r'\ast ',
};

const _fracChars = {
  '½': ('1', '2'), '⅓': ('1', '3'), '⅔': ('2', '3'), '¼': ('1', '4'),
  '¾': ('3', '4'), '⅕': ('1', '5'), '⅖': ('2', '5'), '⅗': ('3', '5'),
  '⅘': ('4', '5'), '⅙': ('1', '6'), '⅚': ('5', '6'), '⅛': ('1', '8'),
  '⅜': ('3', '8'), '⅝': ('5', '8'), '⅞': ('7', '8'),
};

const _funcs = {
  'sin', 'cos', 'tan', 'cot', 'sec', 'csc', 'log', 'ln', 'lim', 'exp',
  'max', 'min', 'det', 'sup', 'inf', 'arcsin', 'arccos', 'arctan', 'sinh',
  'cosh', 'tanh', 'gcd', 'deg', 'dim',
};

/// 큰 연산자(위/아래 첨자를 받는 것).
const _bigTex = {'∑': r'\sum', 'Σ': r'\sum', '∫': r'\int', 'Π': r'\prod', '∮': r'\oint'};

const _combining = {'⃗', '̄', '̂', '̃', '̅'};

bool _isSup(String c) => _supMap.containsKey(c);
bool _isSub(String c) => _subMap.containsKey(c);
bool _isAsciiLetter(int u) => (u >= 65 && u <= 90) || (u >= 97 && u <= 122);
bool _isDigit(int u) => u >= 48 && u <= 57;

/// 수식 런(run)을 이룰 수 있는 문자인가(공백 제외).
bool _isMathChar(String c) {
  final u = c.codeUnitAt(0);
  if (_isAsciiLetter(u) || _isDigit(u)) return true;
  if ('+-*/=<>()[]{}|^_,.:;\'!?%~'.contains(c)) return true;
  if (_symTex.containsKey(c) ||
      _supMap.containsKey(c) ||
      _subMap.containsKey(c) ||
      _fracChars.containsKey(c) ||
      _bigTex.containsKey(c) ||
      _combining.contains(c)) {
    return true;
  }
  return c == '√' || c == '⁄';
}

// ───────────────────────── 구간 찾기 ─────────────────────────

List<MathSeg> _split(String s, bool wholeIfMath) {
  final segs = <MathSeg>[];
  final buf = StringBuffer();
  void flushText() {
    if (buf.isNotEmpty) {
      segs.add(MathSeg(buf.toString()));
      buf.clear();
    }
  }

  final n = s.length;
  var i = 0;
  while (i < n) {
    final c = s[i];
    if (!_isMathChar(c)) {
      buf.write(c);
      i++;
      continue;
    }
    // 런 확장: 수식 문자 + 사이사이 공백(다음 비공백이 수식 문자일 때만)
    var j = i;
    var end = i; // 마지막 수식 문자 다음 위치
    while (j < n) {
      final cj = s[j];
      if (_isMathChar(cj)) {
        j++;
        end = j;
      } else if (cj == ' ') {
        var k = j;
        while (k < n && s[k] == ' ') {
          k++;
        }
        if (k < n && _isMathChar(s[k])) {
          j = k;
        } else {
          break;
        }
      } else {
        break;
      }
    }
    final run = s.substring(i, end);
    final res = _processRun(run, wholeIfMath && i == 0 && end == n);
    if (res == null) {
      buf.write(run);
    } else {
      // 가장자리에서 잘라낸 부분은 일반 글자로 되돌린다.
      buf.write(res.$1);
      flushText();
      segs.add(MathSeg(res.$2, res.$3));
      buf.write(res.$4);
    }
    i = end;
  }
  flushText();
  return segs;
}

/// 런을 다듬고 수식이면 (앞 글자, 수식 원문, tex, 뒤 글자)를 돌려준다.
(String, String, String, String)? _processRun(String run, bool whole) {
  var a = 0;
  var b = run.length;
  bool trimCh(String c) => ' ,.;:?!\''.contains(c);
  // 앞쪽: 공백/문장부호 제거, 짝 없는 닫는 괄호 제거
  while (a < b && (trimCh(run[a]) || ')]}'.contains(run[a]))) {
    a++;
  }
  // 뒤쪽: 공백/문장부호 제거(단 ' 는 문자 뒤면 미분 기호라 유지), 짝 없는 여는 괄호 제거
  while (b > a) {
    final c = run[b - 1];
    if (c == '\'' && b - 2 >= a && _isLetterOrParen(run[b - 2])) break;
    if (trimCh(c) || '([{'.contains(c)) {
      b--;
    } else {
      break;
    }
  }
  if (a >= b) return null;
  var core = run.substring(a, b);
  // 짝이 안 맞는 괄호가 가장자리에 남으면 떼어낸다.
  core = _fixEdgeParens(core, (d) {
    a += d.$1;
    b -= d.$2;
  });
  if (core.isEmpty) return null;

  // 앞/뒤의 순수 숫자 단어(예: "E 5명"의 5)는 본문 숫자라 수식에서 제외
  final lead = RegExp(r'^\d+[ ]+(?=\S)').firstMatch(core);
  if (lead != null && _isAsciiLetter(core.codeUnitAt(lead.end))) {
    // "3 x" 처럼 숫자 뒤 변수: 곱셈일 수 있으므로 유지
  }
  final trail = RegExp(r'(?<=[A-Za-z\)])[ ]+\d+$').firstMatch(core);
  if (trail != null && !_hasOperatorBefore(core, trail.start)) {
    core = core.substring(0, trail.start);
    b = a + core.length;
  }

  if (!_hasOperand(core)) return null;
  // 한글 뒤에 남은 윗첨자 조각(예: "(빗변)²")은 일반 글자로 둔다. ₙCᵣ 같은 조합은 예외.
  if ((_isSup(core[0]) || _isSub(core[0])) &&
      !(core.length > 1 && RegExp(r'^[₀-₉ₐ-ₓᵢⱼᵣᵤᵥ]+[CPHΠ]').hasMatch(core)) &&
      !RegExp(r'^[⁰¹²³⁴-⁹]+⁄[₀-₉⁰¹²³⁴-⁹]+').hasMatch(core)) {
    return null;
  }
  if (!_hasTrigger(core) && !(whole && a == 0 && b == run.length && core.trim().isNotEmpty)) {
    return null;
  }
  final tex = _convert(core);
  if (tex == null || tex.trim().isEmpty) return null;
  return (run.substring(0, a), core, tex, run.substring(b));
}

/// 연산자·부호·공백만 있는 런(예: 한글 사이의 `·`)은 수식이 아니다.
bool _hasOperand(String s) {
  for (var i = 0; i < s.length; i++) {
    if (' ·×÷+-−=<>≤≥≠≈→←↔.,;:!?\'()[]{}|/~…⋯'.contains(s[i])) continue;
    return true;
  }
  return false;
}

bool _isLetterOrParen(String c) {
  final u = c.codeUnitAt(0);
  return _isAsciiLetter(u) || _isDigit(u) || c == ')' || c == ']';
}

bool _hasOperatorBefore(String s, int idx) {
  // 끝에서 "x + 3" 같이 연산자 뒤의 숫자면 수식의 일부
  for (var i = idx - 1; i >= 0; i--) {
    final c = s[i];
    if (c == ' ') continue;
    return '+-−×÷·=<>≤≥/^_'.contains(c);
  }
  return false;
}

String _fixEdgeParens(String core, void Function((int, int)) apply) {
  var s = core;
  var cut = (0, 0);
  // 앞쪽에 남은 짝 없는 '(' 제거 / 뒤쪽 짝 없는 ')' 제거를 한 번씩 시도
  int bal(String t) {
    var d = 0;
    for (final ch in t.split('')) {
      if ('([{'.contains(ch)) d++;
      if (')]}'.contains(ch)) d--;
    }
    return d;
  }

  var guard = 0;
  while (bal(s) != 0 && guard++ < 4 && s.isNotEmpty) {
    final d = bal(s);
    if (d > 0 && '([{'.contains(s[0])) {
      s = s.substring(1);
      cut = (cut.$1 + 1, cut.$2);
    } else if (d < 0 && ')]}'.contains(s[s.length - 1])) {
      s = s.substring(0, s.length - 1);
      cut = (cut.$1, cut.$2 + 1);
    } else {
      break;
    }
    // 새 가장자리의 공백/문장부호 정리
    while (s.isNotEmpty && ' ,.;:?!'.contains(s[s.length - 1])) {
      s = s.substring(0, s.length - 1);
      cut = (cut.$1, cut.$2 + 1);
    }
    while (s.isNotEmpty && ' ,.;:?!'.contains(s[0])) {
      s = s.substring(1);
      cut = (cut.$1 + 1, cut.$2);
    }
  }
  apply(cut);
  return s;
}

/// 수식 조판이 필요한 내용이 들어 있는가.
bool _hasTrigger(String s) {
  var letters = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    final u = c.codeUnitAt(0);
    if (_isAsciiLetter(u)) {
      letters++;
      continue;
    }
    if (_isDigit(u) || ' ,.;:?!\'()[]{}|-'.contains(c)) continue;
    if (c == '%') continue;
    return true; // 연산자·유니코드 수식 기호·첨자 등
  }
  if (letters == 0) {
    // 숫자와 괄호/쉼표뿐이면 일반 글자. 단 "3-2" 같은 뺄셈은 수식
    return RegExp(r'\d\s*-\s*\d').hasMatch(s) && !RegExp(r'^\(?\d+-\d+\)?$').hasMatch(s.trim());
  }
  // 영문자만 있는 경우: 단위(cm, kg…)·영단어는 제외, 변수/함수는 수식
  if (RegExp(r'^[A-Za-z]{4,}$').hasMatch(s) && !_funcs.contains(s)) return false;
  if (RegExp(r'^\d+(\.\d+)?\s?(cm|mm|km|m|kg|g|s|ml|L|mol)$').hasMatch(s)) return false;
  return true;
}

// ───────────────────────── 변환 ─────────────────────────

String? _convert(String src) {
  try {
    final p = _Parser(src);
    final tex = p.run();
    if (tex.contains(r'$')) return null;
    return tex;
  } catch (_) {
    return null;
  }
}

abstract class _N {}

class _Atom extends _N {
  String tex;
  final bool plainNum; // 숫자/문자 하나(분수 괄호 벗기기 등 판단용)
  final bool punct; // 쉼표·마침표 등 — 분수 피연산자가 될 수 없다
  final bool isFunc; // sin, log … (뒤에 인수가 따라온다)
  _Atom(this.tex, {this.plainNum = false, this.punct = false, this.isFunc = false});
}

class _Grp extends _N {
  final String open; // 소스 기호 ( [ {
  final String close;
  final List<_N> items;
  String? sup;
  String? sub;
  String prime = '';
  _Grp(this.open, this.close, this.items);
}

class _Op extends _N {
  final String tex;
  final String raw;
  _Op(this.tex, this.raw);
}

class _Sp extends _N {}

class _Slash extends _N {}

class _Sqrt extends _N {}

class _To extends _N {}

class _Big extends _N {
  final String tex;
  String? sub;
  String? sup;
  _Big(this.tex);
}

class _Parser {
  final String s;
  int i = 0;
  _Parser(this.s);

  String run() {
    final nodes = _parseSeq(null);
    return _emit(_reduce(nodes)).trim();
  }

  // 토큰화 + 괄호 묶기 ------------------------------------------------

  List<_N> _parseSeq(String? closer) {
    final out = <_N>[];
    while (i < s.length) {
      final c = s[i];
      if (closer != null && c == closer) {
        return out;
      }
      if (')]}'.contains(c)) {
        // 짝 없는 닫는 괄호
        out.add(_Atom(c == '}' ? r'\}' : c));
        i++;
        continue;
      }
      if ('([{'.contains(c)) {
        final close = c == '(' ? ')' : c == '[' ? ']' : '}';
        final save = i;
        i++;
        final inner = _parseSeq(close);
        if (i < s.length && s[i] == close) {
          i++;
          final g = _Grp(c, close, inner);
          _readPostfix(g, out);
          out.add(g);
        } else {
          // 닫는 괄호 없음 → 여는 괄호는 글자로
          i = save + 1;
          out.add(_Atom(c == '{' ? r'\{' : c));
        }
        continue;
      }
      if (c == '|') {
        // 절댓값 |…| 은 하나의 묶음으로 취급(분수 범위·첨자가 막대 밖으로 새지 않게)
        final save = i;
        i++;
        final inner = _parseSeq('|');
        if (i < s.length && s[i] == '|') {
          i++;
          final g = _Grp('|', '|', inner);
          _readPostfix(g, out);
          out.add(g);
        } else {
          i = save + 1;
          out.add(_Atom('|'));
        }
        continue;
      }
      _parseToken(out);
    }
    return out;
  }

  void _parseToken(List<_N> out) {
    final c = s[i];
    final u = c.codeUnitAt(0);

    if (c == ' ') {
      while (i < s.length && s[i] == ' ') {
        i++;
      }
      out.add(_Sp());
      return;
    }
    // 숫자
    if (_isDigit(u)) {
      final st = i;
      while (i < s.length && _isDigit(s.codeUnitAt(i))) {
        i++;
      }
      if (i + 1 < s.length && s[i] == '.' && _isDigit(s.codeUnitAt(i + 1))) {
        i++;
        while (i < s.length && _isDigit(s.codeUnitAt(i))) {
          i++;
        }
      }
      var numStr = s.substring(st, i);
      if (i < s.length && _combining.contains(s[i]) && numStr.length > 1) {
        // 1.2̄ 처럼 마지막 숫자 하나에만 붙는다
        i -= 1;
        numStr = s.substring(st, i);
        out.add(_Atom(numStr, plainNum: true));
        out.add(_Atom(s[i], plainNum: true));
        i++;
        _pushCombining(out);
        return;
      }
      final a = _Atom(numStr, plainNum: true);
      _readPostfix(a, out);
      _pushAtom(out, a);
      _pushCombining(out);
      return;
    }
    // 영문자 묶음
    if (_isAsciiLetter(u)) {
      final st = i;
      while (i < s.length && _isAsciiLetter(s.codeUnitAt(i))) {
        i++;
      }
      final word = s.substring(st, i);
      if (word == 'to' &&
          out.isNotEmpty &&
          out.last is _Sp &&
          i < s.length &&
          s[i] == ' ') {
        out.add(_To());
        return;
      }
      out.addAll(_wordAtoms(word));
      // 마지막 원자에 첨자
      final last = out.last;
      if (last is _Atom) {
        _readPostfix(last, out);
        _pushCombining(out);
      } else if (last is _Big) {
        _readPostfix(last, out);
      }
      return;
    }
    // 분수 문자
    if (_fracChars.containsKey(c)) {
      final f = _fracChars[c]!;
      i++;
      out.add(_Atom('\\frac{${f.$1}}{${f.$2}}'));
      return;
    }
    // 위첨자 + ⁄ + 아래첨자 (¹⁰⁄₃)
    if (_isSup(c)) {
      final st = i;
      var j = i;
      while (j < s.length && _isSup(s[j])) {
        j++;
      }
      if (j < s.length && s[j] == '⁄') {
        var k = j + 1;
        final ks = k;
        while (k < s.length && _isSub(s[k])) {
          k++;
        }
        if (k > ks) {
          final num = s.substring(st, j).split('').map((e) => _supMap[e]).join();
          final den = s.substring(ks, k).split('').map((e) => _subMap[e]).join();
          i = k;
          out.add(_Atom('\\frac{$num}{$den}'));
          return;
        }
      }
    }
    // 첨자가 앞 원자 없이 시작(예: ₙCᵣ)
    if (_isSub(c) || _isSup(c)) {
      final holder = _Atom('{}');
      _readPostfix(holder, out);
      out.add(holder);
      return;
    }
    if (c == '√') {
      i++;
      out.add(_Sqrt());
      return;
    }
    if (_bigTex.containsKey(c)) {
      i++;
      final b = _Big(_bigTex[c]!);
      _readPostfix(b, out);
      out.add(b);
      return;
    }
    if (c == '/') {
      i++;
      out.add(_Slash());
      return;
    }
    if (c == '⁄') {
      i++;
      out.add(_Slash());
      return;
    }
    if (c == '^' || c == '_') {
      // 앞 원자에 붙지 못한 첨자 기호는 해석 불가 → 이 구간은 원문 그대로 둔다.
      throw const FormatException('dangling script');
    }
    if (_combining.contains(c)) {
      i++;
      return; // 앞쪽에서 처리하지 못한 결합 문자는 무시
    }
    if (c == ',' || c == ';' || c == ':' || c == '.' || c == '!' || c == '?') {
      i++;
      out.add(_Atom(c, punct: true));
      return;
    }
    if (c == "'") {
      i++;
      final pr = _Atom("'");
      _readPostfix(pr, out);
      out.add(pr);
      return;
    }
    if (c == '|') {
      i++;
      out.add(_Atom('|'));
      return;
    }
    if (c == '-' || c == '−' || c == '–') {
      i++;
      out.add(_Op('-', '-'));
      return;
    }
    if (c == '+') {
      i++;
      out.add(_Op('+', '+'));
      return;
    }
    if (c == '=' || c == '<' || c == '>') {
      i++;
      out.add(_Op(c, c));
      return;
    }
    final sym = _symTex[c];
    if (sym != null) {
      i++;
      // 그리스 문자 등은 원자, 관계/연산 기호는 Op
      final isLetterLike = RegExp(r'^\\[A-Za-z]+ $').hasMatch(sym) &&
          const {
            'π', 'θ', 'α', 'β', 'γ', 'δ', 'ε', 'λ', 'μ', 'σ', 'ρ', 'φ', 'ω',
            'τ', 'η', 'ξ', 'ζ', 'κ', 'ν', 'χ', 'ψ', 'ι', 'Δ', '∆', 'Ω', 'Θ',
            'Φ', 'Ψ', '∞', '∅', 'ℓ', '∂', '∠', '△', '⋯', '…'
          }.contains(c);
      if (isLetterLike) {
        final a = _Atom(sym.trim());
        _readPostfix(a, out);
        _pushAtom(out, a);
        _pushCombining(out);
      } else if (c == '°' || c == '′' || c == '″' || c == '%') {
        out.add(_Atom(sym.trim()));
      } else {
        out.add(_Op(sym, c));
      }
      return;
    }
    // 알 수 없는 문자는 그대로 둔다(파싱 실패 시 원문 폴백)
    i++;
    out.add(_Atom(c));
  }

  /// 원자 뒤의 유니코드/ASCII 첨자를 읽어 붙인다.
  void _readPostfix(Object target, List<_N> out) {
    while (i < s.length) {
      final c = s[i];
      if (_isSup(c)) {
        // 3²⁄³ 처럼 윗첨자 사이의 ⁄ 는 분수 지수(3^{2/3})
        final sb = StringBuffer();
        var afterSlash = false;
        while (i < s.length) {
          final ch = s[i];
          if (_isSup(ch)) {
            sb.write(_supMap[ch]);
          } else if (ch == '⁄') {
            sb.write('/');
            afterSlash = true;
          } else if (afterSlash && _isSub(ch)) {
            sb.write(_subMap[ch]);
          } else {
            break;
          }
          i++;
        }
        _setScript(target, true, _scriptTex(sb.toString()));
      } else if (_isSub(c)) {
        final st = i;
        while (i < s.length && _isSub(s[i])) {
          i++;
        }
        final inner = s.substring(st, i).split('').map((e) => _subMap[e]).join();
        _setScript(target, false, _scriptTex(inner));
      } else if (c == '^' || c == '_') {
        final isSup = c == '^';
        final save = i;
        i++;
        final script = _readAsciiScript();
        if (script == null) {
          i = save;
          return;
        }
        _setScript(target, isSup, script);
      } else if (c == '′' || c == '″') {
        i++;
        _addPrime(target, c == '′' ? "'" : "''");
      } else {
        return;
      }
    }
  }

  String? _readAsciiScript() {
    if (i >= s.length) return null;
    var sign = '';
    if (s[i] == '-' || s[i] == '−') {
      sign = '-';
      i++;
    }
    if (i >= s.length) return null;
    final c = s[i];
    if (c == '(' || c == '{') {
      final close = c == '(' ? ')' : '}';
      var depth = 0;
      var j = i;
      for (; j < s.length; j++) {
        if (s[j] == c) depth++;
        if (s[j] == close) {
          depth--;
          if (depth == 0) break;
        }
      }
      if (j >= s.length) return null;
      final inner = s.substring(i + 1, j);
      i = j + 1;
      return sign + _scriptTex(inner);
    }
    final u = c.codeUnitAt(0);
    if (c == '√') {
      i++;
      if (i < s.length && s[i] == '(') {
        final inner = _readParenInner();
        return inner == null ? null : '$sign\\sqrt{${_scriptTex(inner)}}';
      }
      final st = i;
      while (i < s.length && _isDigit(s.codeUnitAt(i))) {
        i++;
      }
      if (i == st) {
        if (i < s.length && _isAsciiLetter(s.codeUnitAt(i))) {
          i++;
        } else {
          return null;
        }
      }
      return '$sign\\sqrt{${s.substring(st, i)}}';
    }
    if (c == '|') {
      final close = s.indexOf('|', i + 1);
      if (close < 0) return null;
      final inner = s.substring(i + 1, close);
      i = close + 1;
      return '$sign|${_scriptTex(inner)}|';
    }
    final sym = _symTex[c];
    if (sym != null && RegExp(r'^\\[A-Za-z]+ $').hasMatch(sym)) {
      i++;
      return sign + sym.trim();
    }
    if (_isDigit(u)) {
      final st = i;
      while (i < s.length && _isDigit(s.codeUnitAt(i))) {
        i++;
      }
      return sign + s.substring(st, i);
    }
    if (_isAsciiLetter(u)) {
      i++;
      return sign + c;
    }
    return null;
  }

  String? _readParenInner() {
    var depth = 0;
    var j = i;
    for (; j < s.length; j++) {
      if (s[j] == '(') depth++;
      if (s[j] == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    if (j >= s.length) return null;
    final inner = s.substring(i + 1, j);
    i = j + 1;
    return inner;
  }

  /// 첨자 내용(ASCII)을 TeX로.
  String _scriptTex(String inner) {
    final p = _Parser(inner);
    final r = p.run();
    return r.trim();
  }

  void _setScript(Object t, bool sup, String tex) {
    final wrapped = tex;
    if (t is _Atom) {
      t.tex = _withScript(t.tex, sup, wrapped);
    } else if (t is _Grp) {
      if (sup) {
        t.sup = wrapped;
      } else {
        t.sub = wrapped;
      }
    } else if (t is _Big) {
      if (sup) {
        t.sup = wrapped;
      } else {
        t.sub = wrapped;
      }
    }
  }

  void _addPrime(Object t, String p) {
    if (t is _Atom) {
      t.tex = '${t.tex}$p';
    } else if (t is _Grp) {
      t.prime += p;
    }
  }

  String _withScript(String base, bool sup, String script) {
    final mark = sup ? '^' : '_';
    // 같은 종류가 이미 있으면 새 중괄호 그룹으로 감싸 이중 첨자 오류 방지
    final hasSame = RegExp('(?<![\\\\])\\$mark\\{').hasMatch(base) &&
        _endsWithScript(base, mark);
    if (hasSame) return '{$base}$mark{$script}';
    return '$base$mark{$script}';
  }

  bool _endsWithScript(String t, String mark) =>
      RegExp('\\$mark\\{[^{}]*\\}\$').hasMatch(t);

  /// 문자 묶음 → 원자들(함수명 인식).
  List<_N> _wordAtoms(String w) {
    final out = <_N>[];
    if (w.length == 1) {
      out.add(_Atom(w, plainNum: true));
      return out;
    }
    const units = {'cm', 'mm', 'km', 'kg', 'mg', 'ml', 'dl', 'mol', 'Hz', 'ms', 'dot', 'rad'};
    if (units.contains(w)) {
      out.add(_Atom('\\mathrm{$w}'));
      return out;
    }
    // 함수명이 들어 있는 짧은 단어(xcos, limx, ysin…)는 함수 + 변수로 쪼갠다.
    final funcs = _funcs.toList()..sort((a, b) => b.length.compareTo(a.length));
    if (w.length <= 8) {
      final parts = <_N>[];
      var idx = 0;
      var found = false;
      while (idx < w.length) {
        String? hit;
        for (final f in funcs) {
          if (w.startsWith(f, idx)) {
            hit = f;
            break;
          }
        }
        if (hit != null) {
          parts.add(_Atom('\\$hit ', isFunc: true));
          idx += hit.length;
          found = true;
        } else {
          parts.add(_Atom(w[idx], plainNum: true));
          idx++;
        }
      }
      if (found && w == w.toLowerCase()) return parts;
    }
    if (w == w.toLowerCase() && w.length >= 4) {
      // 영어 용어(product, rectum …)는 로만체
      out.add(_Atom('\\mathrm{$w}'));
      return out;
    }
    // 점 이름(AB)·변수 연쇄(dx, mkp, nCr)
    for (final ch in w.split('')) {
      out.add(_Atom(ch, plainNum: true));
    }
    return out;
  }

  void _pushAtom(List<_N> out, _Atom a) => out.add(a);

  /// 방금 넣은 원자(들) 뒤의 결합 문자(⃗ ̄ ̂ ̃)를 적용한다.
  void _pushCombining(List<_N> out) {
    while (i < s.length && _combining.contains(s[i])) {
      final m = s[i];
      i++;
      if (out.isEmpty) return;
      // 앞쪽 연속 대문자 원자(PA⃗)를 모아 화살표 위첨자
      final tail = <_Atom>[];
      var k = out.length - 1;
      while (k >= 0 &&
          out[k] is _Atom &&
          (out[k] as _Atom).plainNum &&
          RegExp(r'^[A-Z]$').hasMatch((out[k] as _Atom).tex) &&
          tail.length < 3) {
        tail.insert(0, out[k] as _Atom);
        k--;
      }
      final multiUpper = m == '⃗' && tail.length > 1;
      if (!multiUpper) {
        tail.clear();
        if (out.last is _Atom) tail.add(out.last as _Atom);
      }
      if (tail.isEmpty) return;
      final used = tail;
      for (var r = 0; r < used.length; r++) {
        out.removeLast();
      }
      final inner = used.map((a) => a.tex).join();
      final cmd = switch (m) {
        '⃗' => multiUpper ? r'\overrightarrow' : r'\vec',
        '̄' || '̅' => r'\overline',
        '̂' => r'\hat',
        _ => r'\tilde',
      };
      out.add(_Atom('$cmd{$inner}', plainNum: true));
    }
  }

  // 구조 축약: √, ∑/lim 한계, 분수 ---------------------------------

  List<_N> _reduce(List<_N> nodes) {
    // 1) 재귀: 그룹 내부 먼저
    for (final n in nodes) {
      if (n is _Grp) {
        final r = _reduce(n.items);
        n.items
          ..clear()
          ..addAll(r);
      }
    }
    // 2) 큰 연산자 한계 / 루트
    var out = <_N>[];
    for (var k = 0; k < nodes.length; k++) {
      final n = nodes[k];
      if (n is _Big && k + 1 < nodes.length && nodes[k + 1] is _Grp) {
        final g = nodes[k + 1] as _Grp;
        if (_applyLimits(n, g)) {
          k++;
        }
      }
      out.add(n);
    }
    // lim 처리: _Atom('\lim ') 뒤 그룹(n→∞)
    final out2 = <_N>[];
    for (var k = 0; k < out.length; k++) {
      final n = out[k];
      if (n is _Atom && n.tex.trim() == r'\lim' && k + 1 < out.length && out[k + 1] is _Grp) {
        final g = out[k + 1] as _Grp;
        final body = _emit(g.items).trim();
        if (body.contains(r'\to')) {
          out2.add(_Atom('\\lim_{$body}'));
          k++;
          continue;
        }
      }
      out2.add(n);
    }
    out = out2;
    // 3) 루트
    final r = <_N>[];
    for (var k = 0; k < out.length; k++) {
      final n = out[k];
      if (n is _Sqrt) {
        if (k + 1 < out.length) {
          final nx = out[k + 1];
          if (nx is _Grp && (nx.open == '(' || nx.open == '{')) {
            final inner = _emitWithScripts(nx, stripParens: true);
            r.add(_Atom('\\sqrt{$inner}'));
            k++;
            continue;
          }
          if (nx is _Atom) {
            r.add(_Atom('\\sqrt{${nx.tex}}'));
            k++;
            continue;
          }
        }
        r.add(_Atom(r'\surd '));
        continue;
      }
      r.add(n);
    }
    // 4) 분수
    return _fractions(r);
  }

  bool _applyLimits(_Big b, _Grp g) {
    final items = g.items;
    final toIdx = items.indexWhere((e) => e is _To || (e is _Op && e.raw == '~') || (e is _Op && e.raw == '→' && b.tex != r'\sum' ));
    if (toIdx < 0) {
      // ∑(n=1)... 형태는 지원 안 함
      return false;
    }
    if (g.open == '(' || g.open == '[') {
      final lo = _emit(items.sublist(0, toIdx)).trim();
      final hi = _emit(items.sublist(toIdx + 1)).trim();
      if (lo.isEmpty || hi.isEmpty) return false;
      if (b.tex == r'\sum' && !lo.contains('=') ) {
        // ∑(n=1 to ∞)만 한계로 취급
        return false;
      }
      b.sub = lo;
      b.sup = hi;
      return true;
    }
    return false;
  }

  List<_N> _fractions(List<_N> nodes) {
    final out = <_N>[];
    var k = 0;
    bool isOperand(_N n) => (n is _Atom && !n.punct) || n is _Grp || n is _Big;
    while (k < nodes.length) {
      final n = nodes[k];
      if (n is _Slash) {
        // 좌변: out 끝쪽의 연속 피연산자 (공백 하나 허용)
        var li = out.length;
        var leftSpace = false;
        if (li > 0 && out[li - 1] is _Sp) {
          leftSpace = true;
          li--;
        }
        var ls = li;
        while (ls > 0 && isOperand(out[ls - 1])) {
          ls--;
        }
        // 우변
        var ri = k + 1;
        var rightSpace = false;
        if (ri < nodes.length && nodes[ri] is _Sp) {
          rightSpace = true;
          ri++;
        }
        var re = ri;
        while (re < nodes.length && isOperand(nodes[re])) {
          re++;
        }
        // 분모가 log·sin 같은 함수명으로 끝나면 뒤따르는 인수까지 분모에 포함(1/log x)
        while (re > ri &&
            nodes[re - 1] is _Atom &&
            (nodes[re - 1] as _Atom).isFunc &&
            re < nodes.length &&
            (nodes[re] is _Sp || isOperand(nodes[re]))) {
          var q = re;
          if (nodes[q] is _Sp) q++;
          if (q >= nodes.length || !isOperand(nodes[q])) break;
          while (q < nodes.length && isOperand(nodes[q])) {
            q++;
          }
          re = q;
        }
        final leftOk = ls < li;
        final rightOk = re > ri;
        // 공백이 낀 슬래시는 양쪽이 모두 있고 단순할 때만 분수로
        final spaced = leftSpace || rightSpace;
        if (leftOk && rightOk && (!spaced || (leftSpace == rightSpace))) {
          final left = out.sublist(ls, li);
          final right = nodes.sublist(ri, re);
          final numTex = _emitNode(left);
          final denTex = _emitNode(right);
          out.removeRange(ls, out.length);
          out.add(_Atom('\\frac{$numTex}{$denTex}'));
          k = re;
          continue;
        }
        out.add(_Atom('/'));
        k++;
        continue;
      }
      out.add(n);
      k++;
    }
    return out;
  }

  String _emitNode(List<_N> seq) {
    // 분자/분모: 단독 괄호 그룹이면 바깥 괄호를 벗긴다
    if (seq.length == 1 && seq.first is _Grp) {
      final g = seq.first as _Grp;
      if (g.open == '(' && g.sup == null && g.sub == null && g.prime.isEmpty) {
        return _emit(g.items).trim();
      }
    }
    return _emit(seq).trim();
  }

  // 출력 ----------------------------------------------------------------

  String _emitWithScripts(_Grp g, {bool stripParens = false}) {
    final inner = _emit(g.items).trim();
    if (stripParens) return inner;
    var open = g.open;
    var close = g.close;
    if (open == '{') {
      open = r'\{';
      close = r'\}';
    }
    var t = '$open$inner$close${g.prime}';
    if (g.sub != null) t = '$t _{${g.sub}}';
    if (g.sup != null) t = '$t ^{${g.sup}}';
    return t;
  }

  String _emit(List<_N> nodes) {
    final sb = StringBuffer();
    _N? prev;
    for (var k = 0; k < nodes.length; k++) {
      final n = nodes[k];
      if (n is _Sp) {
        // 두 "단어형" 사이의 공백만 살린다(연산자·쉼표 주변은 TeX가 간격을 둠)
        final nx = k + 1 < nodes.length ? nodes[k + 1] : null;
        if (prev != null && nx != null && _wordish(prev, end: true) && _wordish(nx, end: false)) {
          sb.write(r'\ ');
        }
        continue;
      }
      if (n is _Atom) {
        sb.write(n.tex);
        if (n.tex.endsWith(' ') == false && _needsSpaceAfterCmd(n.tex)) sb.write(' ');
      } else if (n is _Grp) {
        sb.write(_emitWithScripts(n));
      } else if (n is _Op) {
        sb.write(n.tex);
      } else if (n is _Big) {
        var t = n.tex;
        if (n.sub != null) t = '${t}_{${n.sub}}';
        if (n.sup != null) t = '$t^{${n.sup}}';
        sb.write('$t ');
      } else if (n is _To) {
        sb.write(r'\text{ to }');
      } else if (n is _Slash) {
        sb.write('/');
      } else if (n is _Sqrt) {
        sb.write(r'\surd ');
      }
      prev = n;
    }
    return sb.toString();
  }

  bool _needsSpaceAfterCmd(String t) => RegExp(r'\\[A-Za-z]+$').hasMatch(t);

  bool _wordish(_N n, {required bool end}) {
    if (n is _Atom) {
      if (n.tex == ',' || n.tex == ';' || n.tex == ':' || n.tex == '.') return false;
      return true;
    }
    if (n is _Grp) return true;
    if (n is _Big) return true;
    return false;
  }
}
