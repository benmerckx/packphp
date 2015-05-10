import sys.FileSystem;
import sys.io.File;
import haxe.Json;

using StringTools;

typedef Info = {
  dir: Null<String>,
  front: String,
  lib: String,
  prefix: String
}

class PackPHP {
  static inline var INFO_FILE = 'packphp.json';

  macro public static function writeParams() {
    var info = {
      dir: null,
      front: 'index.php',
      lib: 'lib/',
      prefix: ''
    };
    var args = Sys.args();
    for (i in 0 ... args.length) {
      var arg = args[i];
      switch (arg) {
        case '-php':
          info.dir = args[i+1];
          if (!info.dir.endsWith('/')) info.dir += '/';
        case '--php-front':
          info.front = args[i+1];
        case '--php-lib':
          info.lib = args[i+1];
          if (!info.lib.endsWith('/')) info.lib += '/';
        case '--php-prefix':
          info.prefix = args[i+1];
      }
    }
    if (info.dir == null) return null;
    File.saveContent(INFO_FILE, Json.stringify(info));
    return null;
  }

  static function getInfo(): Null<Info> {
    if (!FileSystem.exists(INFO_FILE))
      return null;
    return Json.parse(File.getContent(INFO_FILE));
  }

  public static function main() {
    var cwd = Sys.args().pop();
    Sys.setCwd(cwd);
    var info = getInfo();
    if (info == null) return;
    var dir = info.dir,
        lib = dir + info.lib,
        main = dir + info.front,
        body = File.getContent(main);

    if (body.indexOf('Haxe/PHP') == -1)
      throw "Main file does not seem to be a haxe generated php file";

    body = body.replace(
      "require_once dirname(__FILE__).'/"+info.lib+"php/"+info.prefix+"Boot.class.php';",
      getClasses(lib)
    );

    File.saveContent(main, body);
    FileSystem.deleteFile(INFO_FILE);
  }

  static function getCode(file) {
    return File.getContent(file).substr(6);
  }

  static function getClasses(dir: String) {
    var body = '';
    if (!dir.endsWith('/')) dir += '/';
    FileSystem.readDirectory(dir).map(function(name) {
      var path = dir + name;
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
