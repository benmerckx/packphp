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

typedef ClassFile = {
  file: String,
  name: String,
  extend: String,
  body: String,
  position: Int
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

    var classes = getClasses(lib);
    var classMap = new Map<String, ClassFile>();
    classes.map(function(item) {
      classMap.set(item.name, item);
    });

    classes.sort(function(a, b) {
      return getPosition(classMap, a.name) - getPosition(classMap, b.name);
    });

    body = body.replace(
      "require_once dirname(__FILE__).'/"+info.lib+"php/"+info.prefix+"Boot.class.php';",
      [for(item in classes) '//'+item.name+'-'+item.extend+'-\n'/*+item.body*/].join('\n')
    );

    File.saveContent(main, body);
    FileSystem.deleteFile(INFO_FILE);
  }

  static function getPosition(map: Map<String, ClassFile>, name: String) {
    if (!map.exists(name)) return 0;
    var item = map.get(name);
    if (item.extend != '') {
      return 1 + getPosition(map, item.extend);
    }
    return 0;
  }

  static function getCode(file) {
    return File.getContent(file).substr(6);
  }

  static function getClasses(dir: String) {
    var classes = [];
    if (!dir.endsWith('/')) dir += '/';
    FileSystem.readDirectory(dir).map(function(name) {
      var path = dir + name;
      if (FileSystem.isDirectory(path)) {
        classes = classes.concat(getClasses(path));
      } else {
        if (name.substr(-3) == 'php') {
          var name = '';
          var content = getCode(path);
          var nameMatch = ~/class (.+?) /;
          var extendMatch = ~/ extends (.+?) /;

          classes.push({
            file: name,
            body: content,
            name: nameMatch.match(content) ? nameMatch.matched(1) : '',
            extend: extendMatch.match(content) ? extendMatch.matched(1) : '',
            position: 0
          });
        }
        FileSystem.deleteFile(path);
      }
    });
    FileSystem.deleteDirectory(dir);
    return classes;
  }
}
