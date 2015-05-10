import sys.FileSystem;
import sys.io.File;

using StringTools;

class PackPHP {
  public static function main() {
    var dir = Sys.getCwd() + 'bin/',
        lib = dir + 'lib',
        main = dir + 'index.php',
        body = File.getContent(main);

    if (body.indexOf('Haxe/PHP') == -1)
      throw "Main file does not seem to be a haxe generated php file";

    body = body.replace(
      "require_once dirname(__FILE__).'/lib/php/Boot.class.php';",
      getClasses(lib)
    );

    File.saveContent(main, body);
  }

  static function getCode(file) {
    return File.getContent(file).substr(6);
  }

  static function getClasses(dir) {
    var body = '';
    FileSystem.readDirectory(dir).map(function(name) {
      var path = dir + '/' + name;
      if (FileSystem.isDirectory(path)) {
        body = getClasses(path) + body;
      } else {
        if (name.substr(-3) == 'php') {
          var content = getCode(path);
          if (name == 'Boot.class.php') {
            body = content + body;
          } else {
            body += content;
          }
        }
        FileSystem.deleteFile(path);
      }
    });
    FileSystem.deleteDirectory(dir);
    return body;
  }
}
