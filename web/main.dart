import "dart:html";
import "dart:math";

import "package:image/image.dart";
import "package:archive/archive.dart";

typedef Bytes = List<int>;

void main() {
  final now = DateTime.now();
  final element = document.querySelector("#output") as DivElement;
  element.text = "The time is ${now.hour}:${now.minute}"
      " and your Dart web app is running!";
}

typedef FileFormat = ({String name, String ext, String mime});

extension FileFormatIter on Iterable<FileFormat> {
  Iterable<String> get names => this.map<String>((FileFormat e) => e.name);
  Iterable<String> get exts => this.map<String>((FileFormat e) => e.ext);
  Iterable<String> get mimes => this.map<String>((FileFormat e) => e.mime);
}
extension ListTuple2Transposer<T> on (Iterable<T>, Iterable<T>){
  Iterable<(T, T)> get transpose => Iterable.generate(max<int>(this.$1.length, this.$2.length), (int i) => (this.$1.elementAt(i), this.$2.elementAt(i)));
}
extension Tuple2ListTransposer<T> on Iterable<(T, T)>{
  (Iterable<T>, Iterable<T>) get transpose => ;
}

class Settings {
  //images: PNG, JPG, GIF, BMP, TIFF, TGA, PVR, ICO, WebP, PSD, EXR
  final List<FileFormat> img = <FileFormat>[(name: "PNG", ext: "", mime: ""), (name: "JPG", ext: "", mime: ""), (name: "GIF", ext: "", mime: ""), (name: "BMP", ext: "", mime: ""), (name: "TIFF", ext: "", mime: ""), (name: "TGA", ext: "", mime: ""), (name: "PVR", ext: "", mime: ""), (name: "ICO", ext: "", mime: ""), (name: "WebP", ext: "", mime: ""), (name: "PSD", ext: "", mime: ""), (name: "EXR", ext: "", mime: "")];
  //archives: Zip, Tar, GZip, BZip2, 
  final List<FileFormat> ar = <FileFormat>[(name: "", ext: "", mime: "")];
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

void noneFilePaint(DivElement output, String massage, {Map<String, Iterable<(String, String)>>? options}) {
  output.children = <Element>[SpanElement()..text = massage];
  if(options != null){
    UListElement()
  }
}
