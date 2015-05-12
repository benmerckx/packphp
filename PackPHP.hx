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
  position: Int,
  type: String
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

    var classes = getClasses(dir.split('/').length-1, lib);
    var classMap = new Map<String, ClassFile>();
    classes.map(function(item) {
      classMap.set(item.name, item);
    });

    classes.sort(function(a, b) {
      return getPosition(classMap, a.name) - getPosition(classMap, b.name);
    });

    body = body.replace(
      "require_once dirname(__FILE__).'/"+info.lib+"php/"+info.prefix+"Boot.class.php';",
      [for (item in classes) {
		var output = '';  
		if (!isBoot(item.name))
		  output += '\n_hx_register_type(new _hx_${phpType(item.type)}("${item.name}", "${item.name.split("_").join(".")}", "${main}"));';
		output += item.body;
	  }].join('\n')
    );

    File.saveContent(main, body);
    FileSystem.deleteFile(INFO_FILE);
  }
  
  static function phpType(type: String) {
    return switch (type) {
	  case 'class': 'class';
	  case 'enum': 'enum';
	  case 'interface': 'interface';
	  case 'extern': 'class';
	  default: '';
	}
  }
  
  static function isBoot(name: String) {
	return name.endsWith('Boot') && name.substr(0, 3) == 'php';
  }

  static function getPosition(map: Map<String, ClassFile>, name: String) {
    if (isBoot(name)) return -1;
    if (!map.exists(name)) return 0;
    var item = map.get(name);
    if (item.extend != '') {
      return 1 + getPosition(map, item.extend);
    }
    return 0;
  }

  static function getCode(file) {
	var code = File.getContent(file).substr(6);
	var externCheck = ~/require_once (.+?)\.extern\.php';/g;
	code = externCheck.replace(code, '');
    return code;
  }

  static function getClasses(packagesCount: Int, dir: String) {
    var classes = [];
    if (!dir.endsWith('/')) dir += '/';
    FileSystem.readDirectory(dir).map(function(name) {
      var path = dir + name;
      if (FileSystem.isDirectory(path)) {
        classes = classes.concat(getClasses(packagesCount, path));
      } else {
        if (name.substr(-3) == 'php') {
		  var pack = dir.split('/');
		  pack.splice(0, packagesCount+1);
		  var info = name.split('.');
          var className = pack.join('_')+info[0];
          var content = getCode(path);
          var extendMatch = ~/ extends (.+?) /;

          classes.push({
            file: name,
            body: content,
            name: className,//nameMatch.match(content) ? nameMatch.matched(1) : '',
            extend: extendMatch.match(content) ? extendMatch.matched(1) : '',
            position: 0,
			type: info[1]
          });
        }
        FileSystem.deleteFile(path);
      }
    });
    FileSystem.deleteDirectory(dir);
    return classes;
  }
}
