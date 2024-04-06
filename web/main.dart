import "dart:html";
import "dart:math";

import "package:image/image.dart" hide Color;
import "package:image/image.dart" as i show Color;
import "package:archive/archive.dart";
import "package:color/color.dart";

typedef Bytes = List<int>;
typedef Resource = ({String name, Bytes data});
typedef KindResource<K extends ResourceKind> = ({String name, Bytes data, K kind});
typedef FileFormat = ({String name, String ext, String mime});
typedef Triplet<T> = ({T prev, T curr, T next});

void main() {
  final now = DateTime.now();
  final element = document.querySelector("#output") as DivElement;
  element.text = "The time is ${now.hour}:${now.minute}"
      " and your Dart web app is running!";
}
void onLoadInit(FileUploadInputElement input, DivElement output, DivElement explanation, Settings conf){
  
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

class Settings {
  //images: PNG, JPG, GIF, BMP, TIFF, TGA, PVR, ICO, WebP, PSD, EXR
  final List<FileFormat> img = <FileFormat>[(name: "PNG", ext: "", mime: ""), (name: "JPG", ext: "", mime: ""), (name: "GIF", ext: "", mime: ""), (name: "BMP", ext: "", mime: ""), (name: "TIFF", ext: "", mime: ""), (name: "TGA", ext: "", mime: ""), (name: "PVR", ext: "", mime: ""), (name: "ICO", ext: "", mime: ""), (name: "WebP", ext: "", mime: ""), (name: "PSD", ext: "", mime: ""), (name: "EXR", ext: "", mime: "")];
  //archives: Zip, Tar, GZip, BZip2, XZ
  final List<FileFormat> ar = <FileFormat>[(name: "", ext: "", mime: "")];
}
sealed class ResourceKind{}
sealed class SingleStyResource extends ResourceKind {}
sealed class ArchiveStyResource extends ResourceKind {}
sealed class CompressedResource extends ResourceKind {}
final class CArchiveResource extends ArchiveStyResource implements CompressedResource{}
final class COnlyResource extends SingleStyResource implements CompressedResource{}
final class ImageResource extends SingleStyResource{}
final class ArchiveResource extends ArchiveStyResource {}

class AnalysisResult {
  final String name;
  final List<AnalysisResultEntry> result;
  AnalysisResult(this.name, this.result);
  String toJson() {}
  String Yaml() {}
}
class AnalysisResultEntry {
  Color color;
  int pccsHue;
  AnalysisResultEntry._(this.color, this.pccsHue);
  factry AnalysisResultEntry(Color color){}
  String get hexStr
}

extension AnalysisResultIter on Iterable<AnalysisResult> {
  String toJson() {}
  String Yaml() {}
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
    } else if (arf.isEmpty) {}
  }
}

//Under S20
List<int> pccsHuesSU20 = <int>[];
//Over S20
List<int> pccsHuesSO20 = <int>[];
int pccsHues(HsvColor color){
  if(color.s < 20){}else{}
}

String detect(Resource res, {String? name}) {}
KindResource decompress(CompressedResource res) {}
Iterable<KindResource> openArchive(ArchiveStyResource res) {}

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
