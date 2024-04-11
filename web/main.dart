import "dart:convert";
import "dart:html";
import "dart:math";
import "dart:typed_data";

import "package:archive/archive.dart";
import "package:color/color.dart";
import "package:image/image.dart" hide Color;
import "package:image/image.dart" as i show Color;
import "package:sorted/sorted.dart";
import "package:yaml_writer/yaml_writer.dart";

typedef Bytes = List<int>;
typedef Resource = ({String name, Bytes data});
typedef TypedResource = ({String name, Bytes data, String mime});
typedef KindResource<K extends ResourceKind> = ({String name, Bytes data, K kind});
typedef FileFormat = ({String name, String ext, String mime});
typedef Triplet<T> = ({T prev, T curr, T next});

void main() {
  final now = DateTime.now();
  final element = document.querySelector("#output") as DivElement;
  element.text = "The time is ${now.hour}:${now.minute}"
      " and your Dart web app is running!";
}

void onLoadInit(FileUploadInputElement input, DivElement output, DivElement explanation, Settings conf) {
  noneFilePaint(explanation, "有効なファイル形式は画像形式か書庫形式です。次に掲げる形に対応しています。", options: {"画像形式": (conf.img.names, conf.img.exts).transpose, "書庫形式": (conf.ar.names, conf.ar.exts).transpose});
}

extension FileFormatIter on Iterable<FileFormat> {
  Iterable<String> get names => this.map<String>((FileFormat e) => e.name);
  Iterable<String> get exts => this.map<String>((FileFormat e) => e.ext);
  Iterable<String> get mimes => this.map<String>((FileFormat e) => e.mime);
}

extension ListTuple2Transposer<T> on (Iterable<T>, Iterable<T>) {
  Iterable<(T, T)> get transpose => Iterable<(T, T)>.generate(max<int>(this.$1.length, this.$2.length), (int i) => (this.$1.elementAt(i), this.$2.elementAt(i)));
}

extension Tuple2ListTransposer<T> on Iterable<(T, T)> {
  (Iterable<T>, Iterable<T>) get transpose => (Iterable<T>.generate(this.length, (int i) => (this.elementAt(i).$1)), Iterable<T>.generate(this.length, (int i) => (this.elementAt(i).$2)));
}

extension ColorClsConv on i.Color {
  Color conv() => Color.rgb(this.r, this.g, this.b);
}

extension RingTriplet<T> on Iterable<T> {
  Iterable<Triplet<T>> get ring => Iterable<Triplet<T>>.generate(this.length, (int i) => (prev: this.elementAt((i - 1) % this.length), curr: this.elementAt(i), next: this.elementAt((i + 1) % this.length)));
}

extension BoolXor on bool {
  bool operator ^(bool other) => (this || other) && !(this && other);
}

extension Tuple2MapEntry<K, V> on (K, V) {
  MapEntry<K, V> toEntry() => MapEntry<K, V>(this.$1, this.$2);
}

extension Tuple2MapEntryIter<K, V> on Iterable<(K, V)> {
  Iterable<MapEntry<K, V>> toEntry() => this.map<MapEntry<K, V>>(((K, V) e) => e.toEntry());
}

extension MapEntry2Tuple<K, V> on MapEntry<K, V> {
  (K, V) toTuple() => (this.key, this.value);
}

extension MapEntry2TupleIter<K, V> on Iterable<MapEntry<K, V>> {
  Iterable<(K, V)> toTuple() => this.map<(K, V)>((MapEntry<K, V> e) => e.toTuple());
}

extension Tuple2MapIter<K, V> on Iterable<(K, V)> {
  Map<K, V> toMap() => Map<K, V>.fromEntries(this.toEntry());
}

extension Map2TupleIter<K, V> on Map<K, V> {
  Iterable<(K, V)> toTuple() => this.entries.toTuple();
}

class Settings {
  //images: PNG, JPG, GIF, BMP, TIFF, TGA, PVR, ICO, WebP, PSD, EXR
  final List<FileFormat> img = <FileFormat>[(name: "PNG", ext: "", mime: ""), (name: "JPG", ext: "", mime: ""), (name: "GIF", ext: "", mime: ""), (name: "BMP", ext: "", mime: ""), (name: "TIFF", ext: "", mime: ""), (name: "TGA", ext: "", mime: ""), (name: "PVR", ext: "", mime: ""), (name: "ICO", ext: "", mime: ""), (name: "WebP", ext: "", mime: ""), (name: "PSD", ext: "", mime: ""), (name: "EXR", ext: "", mime: "")];
  //archives: Zip, Tar, GZip, BZip2, XZ
  final List<FileFormat> ar = <FileFormat>[(name: "", ext: "", mime: "")];
}

sealed class ResourceKind {}

final class ImageResource extends ResourceKind {}

final class ArchiveResource extends ResourceKind {}

final class CompressedResource extends ResourceKind {}

sealed class StringObject {
  //String or Map or List
  Object get _object;
}

final class ScalarObject extends StringObject {
  final String data;
  ScalarObject(this.data);
  factory ScalarObject.date(DateTime dt, {bool utc = false, bool timestamp = false, bool second = false}) => ScalarObject(timestamp ? ((utc ? dt.toUtc() : dt).millisecond ~/ 1000).toString() : (utc ? dt.toUtc() : dt).copyWith(millisecond: 0, microsecond: 0).toIso8601String());
  factory ScalarObject.number(num number, {bool round = false, bool ceil = false, bool floor = true, int digit = 0}) {
    if (round) {
      num temp = pow(number, digit);
      late int temp2;
      if (!(ceil ^ floor)) {
        temp2 = temp.round();
      } else if (ceil) {
        temp2 = temp.ceil();
      } else {
        temp2 = temp.floor();
      }
      return ScalarObject(temp2.toString());
    } else {
      return ScalarObject(number.toString());
    }
  }
  factory ScalarObject.binary(List<int> bin, {bool base64 = true}) => ScalarObject(base64 ? base64Encode(bin) : "x${bin.map<String>((int e) => e.toRadixString(16).toLowerCase().padLeft(2, "0")).join()}");

  @override
  Object get _object => this.data;
}

final class MapObject<K extends StringObject, V extends StringObject> extends StringObject {
  final Map<K, V> data;
  MapObject(this.data);

  @override
  Object get _object => this.data.map<Object, Object>((K key, V value) => MapEntry<Object, Object>(key._object, value._object));
}

final class ListObject<E extends StringObject> extends StringObject {
  final Iterable<E> data;
  ListObject(this.data);

  @override
  Object get _object => this.data.map<Object>((E e) => e._object).toList();
}

abstract class StringObjectSerializable {
  StringObject toObject();
  String toJson() => jsonIndent(jsonEncode(this.toObject()._object));
  String toYaml() => YamlWriter().write(this.toObject()._object);
}

extension AnalysisResultIter on Iterable<StringObjectSerializable> {
  ListObject toObject() => ListObject(this.map<StringObject>((StringObjectSerializable e) => e.toObject()));
  String toJson() => jsonIndent(jsonEncode(this.toObject()._object));
  String toYaml() => YamlWriter().write(this.toObject()._object);
}

extension IndexedMap<E> on Iterable<E> {
  Iterable<R> indexedMap<R>(R Function(int, E) fn) => this.toList().asMap().entries.map<R>((MapEntry<int, E> e) => fn(e.key, e.value));
}

class AnalysisResult extends StringObjectSerializable {
  final int status;
  final String name;
  final Bytes data;
  final String mime;
  final List<AnalysisResultEntry> result;
  AnalysisResult(this.name, this.data, this.mime, this.status, this.result);
  factory AnalysisResult.fromResource(TypedResource res, int status, List<AnalysisResultEntry> result) => AnalysisResult(res.name, res.data, res.mime, status, result);

  @override
  StringObject toObject() => MapObject<ScalarObject, StringObject>(<ScalarObject, StringObject>{ScalarObject("status"): ScalarObject.number(this.status), ScalarObject("name"): ScalarObject(this.name), ScalarObject("result"): this.result.toObject()});
  String toUriQE() => XZEncoder().encode(data).map<String>((int e) => e.toRadixString(16)).join();
}

class AnalysisResultEntry extends StringObjectSerializable {
  Color color;
  int pccsHue;
  AnalysisResultEntry._(this.color, this.pccsHue);
  factory AnalysisResultEntry(Color color) => AnalysisResultEntry._(color, pccsHues(color.toHsvColor()));
  String get hexStr => this.color.toHexColor().toCssString();
  int get hex => int.parse(this.hexStr.substring(1), radix: 16);

  @override
  StringObject toObject() => MapObject<ScalarObject, ScalarObject>(<ScalarObject, ScalarObject>{ScalarObject("color"): ScalarObject(this.hexStr), ScalarObject("pccsHue"): ScalarObject.number(this.pccsHue)});
}

void process(FileUploadInputElement input, DivElement output, Settings conf) {
  final FileReader reader = FileReader();
  final List<File>? fl = input.files;
  if (fl == null) {
    noneFilePaint(output, "ファイルが選択されていません。選択してください。");
  } else {
    final Iterable<File> arf = fl.where((File f) => conf.ar.mimes.any((String mime) => f.type == mime));
    final Iterable<File> imf = fl.where((File f) => conf.img.mimes.any((String mime) => f.type == mime));
    if (arf.isEmpty && imf.isEmpty) {
      noneFilePaint(output, "有効なファイル形式のファイルが一つもありません。有効な形式は画像形式か書庫形式です。", options: {"画像形式": (conf.img.names, conf.img.exts).transpose, "書庫形式": (conf.ar.names, conf.ar.exts).transpose});
    } else {
      List<Resource> imr = <Resource>[];
      List<Resource> arr = <Resource>[];
      imr.addAll(imf.map<Resource>((File e) {
        reader.readAsArrayBuffer(e);
        return (name: e.name, data: reader.result as Bytes);
      }));
      arr.addAll(arf.map<Resource>((File e) {
        reader.readAsArrayBuffer(e);
        return (name: e.name, data: reader.result as Bytes);
      }));
    }
  }
}

class Ring<N extends num> {
  final int modulo;
  Ring(this.modulo);
  N add(N a, N b) => switch ((a, b)) { (int a, int b) => (a + b) % this.modulo, (double a, double b) => (a + b) % this.modulo, _ => throw Error() } as N;
  N subtract(N a, N b) => this.subtract(a, -b as N);
  N mult(N a, int b) => switch (b) { int b when b == 0 => 0, int b when b == 1 => 0, int b when b > 0 => 0, int b when b < 0 => 0, _ => throw Error() } as N;
  N difference(N basis, N target, {bool directional = false, bool long = false}) => 0 as N;
  double averageInterval(int count) => this.modulo / count;
  N scale(N target, N actualInterval, int count) => switch (target) { (int target, int actualInterval) => target * (this.averageInterval(count) / actualInterval).floor(), (double target, double actualInterval) => (target * this.averageInterval(count) / actualInterval), _ => throw Error() } as N;
}

//Under S20
List<int> pccsHuesSU20 = <int>[];
//Over S20
List<int> pccsHuesSO20 = <int>[];

int pccsHues(HsvColor color) {
  //hue diff
  late Iterable<(int, double)> temp = color.s < 20 ? _pccsHuesInternal(pccsHuesSU20, color.h) : _pccsHuesInternal(pccsHuesSO20, color.h);
  temp.sorted([SortedComparable<(int, double), double>(((int, double) e) => e.$2)]);
  throw UnimplementedError();
}

Iterable<(int, double)> _pccsHuesInternal(List<int> hueRing, num targetHue) {
  final Ring<double> r = Ring<double>(360);
  return hueRing.ring.map<(int, double)>((Triplet<int> t) => switch (r.difference(t.curr.toDouble(), targetHue.toDouble(), directional: true)) { double x when x == 0 => (t.curr, 0), double x when x > 0 => (t.curr, r.scale(x.abs(), t.next.toDouble(), hueRing.length)), double x when x < 0 => (t.curr, r.scale(x.abs(), t.prev.toDouble(), hueRing.length)), _ => throw Error() });
}

AnalysisResult analyze(KindResource<ImageResource> res, int retCount) {
  Image? im = decodeImage(Uint8List.fromList(res.data));
  if (im == null) {
    return AnalysisResult(res.name, res.data, "", -1, <AnalysisResultEntry>[]);
  }
  Map<String, int> ret = Iterable<Iterable<Pixel>>.generate(im.height, (int i) => Iterable<Pixel>.generate(im.width, (int j) => im.getPixel(i, j))).expand((Iterable<Pixel> e) => e).fold<Map<String, int>>(<String, int>{}, (Map<String, int> prev, Pixel el) {
    prev.update(RgbColor(el.r, el.g, el.b).toHexColor().toCssString(), (int cnt) => cnt + 1, ifAbsent: () => 1);
    return prev;
  });
  List<AnalysisResultEntry> ent = ret.toTuple().sorted([SortedComparable<(String, int), int>(((String, int) e) => e.$2, invert: true), SortedComparable<(String, int), int>(((String, int) e) => int.parse(e.$1.substring(1), radix: 16))]).take(retCount).map<AnalysisResultEntry>(((String, int) e) => AnalysisResultEntry(HexColor(e.$1.substring(1)))).toList();
  return AnalysisResult(res.name, res.data, "", 1, ent);
}

String detect(Resource res, Settings conf, {String? ext}) {
  throw UnimplementedError();
}

KindResource lift(Resource res, Settings conf, {String? ext}) {
  String mime = detect(res, conf, ext: ext);
  if (conf.img.mimes.any((String el) => el == mime)) {
    return (name: res.name, data: res.data, kind: ImageResource());
  } else if (conf.ar.mimes.any((String el) => el == mime)) {
    if (conf.ar.where((FileFormat e) => <String>["tar", "zip"].any((String el) => e.ext == el)).mimes.any((String el) => el == mime)) {
      return (name: res.name, data: res.data, kind: ArchiveResource());
    } else {
      return (name: res.name, data: res.data, kind: CompressedResource());
    }
  } else {
    throw Error();
  }
}

KindResource decompress(KindResource<CompressedResource> res, Settings conf) {
  throw UnimplementedError();
}

Iterable<KindResource> openArchive(KindResource<ArchiveResource> res, Settings conf) {
  late Archive ar;
  if (res.name.endsWith(".zip")) {
    ZipDecoder zd = ZipDecoder();
    ar = zd.decodeBuffer(InputStream(res.data));
  } else {
    TarDecoder td = TarDecoder();
    ar = td.decodeBuffer(InputStream(res.data));
  }
  return ar.files.map<KindResource?>((ArchiveFile af) {
    InputStreamBase? rc = af.rawContent;
    if (rc == null) {
      return null;
    }
    if (af.isCompressed) {
      return decompress((name: "${res.name}/${af.name}", data: rc.toUint8List(), kind: CompressedResource()), conf);
    } else {
      return lift((name: "${res.name}/${af.name}", data: rc.toUint8List()), conf);
    }
  }).whereType<KindResource>();
}

void noneFilePaint(DivElement output, String massage, {Map<String, Iterable<(String, String)>>? options}) {
  output.children = <Element>[SpanElement()..text = massage];
  if (options != null) {
    List<LIElement> xl = options
        .map<String, LIElement>((String kind, Iterable<(String, String)> e) {
          UListElement iu = UListElement();
          List<LIElement> il = e.map<LIElement>(((String, String) e) {
            LIElement el = LIElement();
            el.innerHtml = "${e.$1} (<code>${e.$2}</code>)";
            return el;
          }).toList();
          iu.children = il;
          LIElement l = LIElement();
          l.children = <UListElement>[iu];
          return MapEntry<String, LIElement>(kind, l);
        })
        .values
        .toList();
    UListElement xu = UListElement();
    xu.children = xl;
    output.children.add(xu);
  }
}

String jsonIndent(String json, {String ln = "\n", int indent = 2}) {
  final List<String> beginnings = <String>["{", "["];
  final List<String> endings = <String>["}", "]"];
  final String delim = ",";
  final String con = ":";
  final String quote = "\"";
  int indentCount = 0;
  bool isInQuote = false;
  String s1 = "";
  String ret = "";
  for (int i = 0; i < json.length; i++) {
    s1 = json.substring(i, i + 1);
    //print("loc: $i\nchar: <$s1>");
    if (beginnings.contains(s1) && !isInQuote) {
      //print("- is beg [1]");
      indentCount++;
      ret += s1 + ln + (" " * indentCount * indent);
    } else if (endings.contains(s1) && !isInQuote) {
      //print("- is end [2]");
      indentCount--;
      ret = ret.substring(0, ret.length - (" " * (indent - 1)).length + ln.length);
      ret += ln + (" " * indentCount * indent) + s1;
    } else if (delim == s1 && !isInQuote) {
      //print("- is dlm [3]");
      ret += s1 + ln + (" " * indentCount * indent);
    } else if (con == s1 && !isInQuote) {
      ret += "$s1 ";
    } else if (quote == s1) {
      isInQuote = !isInQuote;
      ret += s1;
    } else {
      //print("- is otr [4]");
      ret += s1;
    }
    //print("!curr ret : $ret");
  }
  return ret;
}
