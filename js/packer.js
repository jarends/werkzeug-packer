// Generated by CoffeeScript 1.12.6
(function() {
  var Babel, Babel_es2015, CHUNK_CODE, CSS_REG, Chok, Dict, EMap, ENV, FS, FSE, Indexer, JMin, JS_REG, MULTI_COMMENT_MAP, PACK_CODE, Packer, Path, SINGLE_COMMENT_MAP, getChunkCode, getPackCode,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    slice = [].slice;

  FS = require('fs');

  FSE = require('fs-extra');

  Path = require('path');

  Dict = require('jsdictionary');

  JMin = require('jsonminify');

  EMap = require('emap');

  PACK_CODE = FS.readFileSync(Path.join(__dirname, '../js', 'pack.js'), 'utf8');

  CHUNK_CODE = FS.readFileSync(Path.join(__dirname, '../js', 'chunk.js'), 'utf8');

  MULTI_COMMENT_MAP = /\/\*\s*[@#]\s*sourceMappingURL\s*=\s*([^\s]*)\s*\*\//g;

  SINGLE_COMMENT_MAP = /\/\/\s*[@#]\s*sourceMappingURL\s*=\s*([^\s]*)($|\n|\r\n?)/g;

  ENV = 'development';

  CSS_REG = /\.sass$|\.scss$|\.less$|\.styl$/;

  JS_REG = /\.coffee$|\.ts$/;

  Babel = null;

  Babel_es2015 = null;

  Chok = null;

  getPackCode = function(p) {
    return "(function(pack)\n{\n    var win = window,\n        process = win.process || (win.process = {}),\n        env     = process.env || (process.env = {}),\n        cfg     = {\n        index:      " + p.index + ",\n        total:      " + p.total + ",\n        startIndex: " + p.file.index + ",\n        type:       'addPack" + p.id + "',\n        path:       '" + p.file.path + "',\n        pack:       pack\n    };\n    env.NODE_ENV = env.NODE_ENV || '" + p.env + "'\n    var packer = " + (p.index === 0 ? PACK_CODE : CHUNK_CODE) + "\n    packer.init(cfg);\n})({\n" + p.code + "\n});";
  };

  getChunkCode = function(p) {
    return "(function(pack)\n{\n    var cfg = {\n        type:       'addPack" + p.id + "',\n        path:       '" + p.file.path + "',\n        chunk:      '" + p.chunk + "',\n        pack:       pack\n    };\n    var chunk = " + CHUNK_CODE + "\n    chunk.init(cfg);\n})({\n" + p.code + "\n});";
  };

  Indexer = (function() {
    function Indexer() {
      this.current = -1;
      this.cache = {};
    }

    Indexer.prototype.get = function(path) {
      var cached;
      cached = this.cache[path];
      if (!isNaN(cached)) {
        return cached;
      }
      this.cache[path] = ++this.current;
      return this.current;
    };

    Indexer.prototype.has = function(path) {
      return !isNaN(this.cache[path]);
    };

    return Indexer;

  })();

  Packer = (function() {
    function Packer(cfg) {
      var bundle, bundles, j, len;
      this.cfg = cfg;
      this.updateNow = bind(this.updateNow, this);
      this.indexer = new Indexer();
      this.emap = new EMap();
      this.fileMap = {};
      this.loaders = {};
      this.openFiles = 0;
      this.packed = null;
      this.loaded = null;
      this.packs = null;
      this.chunks = null;
      this.errors = [];
      this.updates = [];
      this.id = '';
      this.useBabel = this.cfg.useBabel !== false;
      this.useUglify = this.cfg.useUglify === true;
      this.NODE_ENV = this.cfg.NODE_ENV || ENV;
      this.out = this.cfg.base;
      if (this.cfg.watch) {
        this.watch();
      }
      bundles = this.cfg.bundles || [];
      for (j = 0, len = bundles.length; j < len; j++) {
        bundle = bundles[j];
        this.readFile(Path.join(this.out, bundle["in"]));
      }
    }

    Packer.prototype.watch = function() {
      if (this.watcher) {
        this.emap.all();
        this.watcher.close();
      }
      Chok = Chok || require('chokidar');
      this.watcher = Chok.watch(null, {
        ignoreInitial: true,
        usePolling: false,
        useFsEvents: true
      });
      this.emap.map(this.watcher, 'add', this.addedHandler, this);
      this.emap.map(this.watcher, 'change', this.changedHandler, this);
      this.emap.map(this.watcher, 'unlink', this.unlinkedHandler, this);
      return null;
    };

    Packer.prototype.updateLater = function() {
      clearTimeout(this.updateTimeout);
      this.updateTimeout = setTimeout(this.updateNow, 100);
      return null;
    };

    Packer.prototype.updateNow = function() {
      if (this.openFiles > 0) {
        this.updateLater();
      } else {
        this.update(this.updates);
        this.updates = [];
      }
      return null;
    };

    Packer.prototype.addedHandler = function(path) {
      if (this.indexer.has(path)) {
        this.updates.push({
          path: path
        });
        this.updateLater();
      }
      return null;
    };

    Packer.prototype.changedHandler = function(path) {
      if (this.indexer.has(path)) {
        this.updates.push({
          path: path
        });
        this.updateLater();
      }
      return null;
    };

    Packer.prototype.unlinkedHandler = function(path) {
      this.updates.push({
        path: path,
        removed: true
      });
      this.updateLater();
      return null;
    };

    Packer.prototype.update = function(files) {
      var e, error, errors, f, file, j, k, len, len1, path, updated;
      try {
        errors = this.errors;
        this.errors = [];
        updated = {};
        for (j = 0, len = files.length; j < len; j++) {
          f = files[j];
          path = f.path;
          file = this.fileMap[path];
          if (!file || updated[path]) {
            continue;
          }
          updated[path] = true;
          this.clear(file);
          if (!f.removed) {
            this.readFile(path);
          }
        }
        for (k = 0, len1 = errors.length; k < len1; k++) {
          error = errors[k];
          path = error.path;
          file = this.fileMap[path];
          if (updated[path]) {
            continue;
          }
          updated[path] = true;
          this.clear(file);
          this.readFile(path);
        }
        if (this.openFiles === 0) {
          this.writePackages();
        }
        if (this.openFiles === 0) {
          this.completed();
        }
      } catch (error1) {
        e = error1;
        console.log('packer error: ', e.toString());
      }
      return null;
    };

    Packer.prototype.clear = function(file) {
      var loaderRefs, loderPath, path, req, reqPath;
      path = file.path;
      for (reqPath in file.req) {
        req = this.fileMap[reqPath];
        if (req) {
          delete req.ref[path];
        }
        delete file.req[reqPath];
      }
      for (loderPath in file.reqAsL) {
        loaderRefs = this.loaders[loderPath];
        if (loaderRefs) {
          delete loaderRefs[path];
          if (!Dict.hasKeys(loaderRefs)) {
            delete this.loaders[loderPath];
          }
        }
        delete file.reqAsL[loderPath];
      }
      delete this.fileMap[path];
      return null;
    };

    Packer.prototype.writePackages = function() {
      var chunk, file, i, j, k, l, len, len1, len2, loader, m, p, pack, packages, path, ref, ref1, ref2;
      if (this.packs) {
        ref = this.packs;
        for (j = 0, len = ref.length; j < len; j++) {
          pack = ref[j];
          this.removeSources(pack.out);
        }
      }
      if (this.chunks) {
        ref1 = this.chunks;
        for (k = 0, len1 = ref1.length; k < len1; k++) {
          chunk = ref1[k];
          this.removeSources(chunk.out);
        }
      }
      this.totalModules = 0;
      this.packed = {};
      this.loaded = {};
      this.packs = [];
      this.chunks = [];
      packages = this.cfg.bundles || [];
      for (path in this.fileMap) {
        file = this.fileMap[path];
        file.loaders = {};
        file.parts = {};
      }
      for (i = l = packages.length - 1; l >= 0; i = l += -1) {
        pack = packages[i];
        path = Path.join(this.out, pack["in"]);
        file = this.fileMap[path];
        if (file.error) {
          continue;
        }
        p = {
          file: file,
          index: i,
          total: packages.length,
          id: this.id,
          out: Path.join(this.out, pack.out),
          req: {},
          loaders: {},
          code: '',
          env: this.NODE_ENV,
          numModules: 0
        };
        this.packs.push(p);
        this.gatherReq(p, file);
      }
      for (path in this.loaders) {
        loader = this.fileMap[path];
        this.gatherChunks(loader, loader);
      }
      for (path in this.loaded) {
        this.cleanupChunks(this.fileMap[path]);
      }
      ref2 = this.packs;
      for (m = 0, len2 = ref2.length; m < len2; m++) {
        p = ref2[m];
        this.writePack(p);
      }
      for (path in this.loaders) {
        loader = this.fileMap[path];
        chunk = this.getChunkPath(loader);
        if (loader.error) {
          continue;
        }
        p = {
          file: loader,
          index: loader.index,
          id: this.id,
          out: Path.join(this.out, chunk),
          chunk: chunk,
          code: '',
          numModules: 0
        };
        this.chunks.push(p);
        this.writeChunk(p);
      }
      if (this.openFiles === 0) {
        this.completed();
      }
      return null;
    };

    Packer.prototype.getChunkPath = function(loader) {
      return this.cfg.chunks + loader.index + '.js';
    };

    Packer.prototype.gatherReq = function(p, file) {
      var lpath, rfile, rpath;
      if (this.packed[file.index]) {
        return null;
      }
      this.packed[file.index] = true;
      p.req[file.path] = true;
      for (rpath in file.req) {
        rfile = this.fileMap[rpath];
        if (!rfile) {
          this.errors.push({
            path: file.path,
            line: -1,
            col: -1,
            error: 'required file not found: ' + rpath
          });
        } else if (!this.packed[rfile.index]) {
          for (lpath in rfile.reqAsL) {
            p.loaders[lpath] = true;
          }
          this.gatherReq(p, rfile);
        }
      }
      return null;
    };

    Packer.prototype.gatherChunks = function(loader, file) {
      var rfile, rpath;
      file.loaders[loader.path] = true;
      loader.parts[file.path] = true;
      this.loaded[file.path] = true;
      for (rpath in file.req) {
        rfile = this.fileMap[rpath];
        if (!rfile) {
          this.errors.push({
            path: file.path,
            line: -1,
            col: -1,
            error: 'required file not found (chunk): ' + rpath
          });
        } else {
          if (!loader.parts[rpath]) {
            this.gatherChunks(loader, rfile);
          }
        }
      }
      return null;
    };

    Packer.prototype.cleanupChunks = function(file) {
      var j, len, loader, lpath, p, packed, path, ref;
      loader = this.getLoader(file);
      path = file.path;
      packed = this.packed[file.index];
      if (packed || !loader) {
        for (lpath in file.loaders) {
          loader = this.fileMap[lpath];
          delete loader.parts[path];
          delete file.loaders[lpath];
          if (!packed) {
            ref = this.packs;
            for (j = 0, len = ref.length; j < len; j++) {
              p = ref[j];
              if (p.loaders[lpath]) {
                p.req[path] = true;
                this.packed[file.index] = true;
                packed = true;
                break;
              }
            }
          }
        }
      }
      return null;
    };

    Packer.prototype.getLoader = function(file) {
      var count, path;
      count = 0;
      for (path in file.loaders) {
        ++count;
        if (count > 1) {
          return null;
        }
      }
      return this.fileMap[path];
    };

    Packer.prototype.initSourceMapping = function(pack, type) {
      var origin;
      if (type === 'pack') {
        if (pack.index === 0) {
          this.lineOffset = 183;
        } else {
          this.lineOffset = 54;
        }
      } else {
        this.lineOffset = 48;
      }
      origin = Path.basename(pack.out);
      this.sourceMap = {
        version: 3,
        file: origin,
        sourceRoot: '',
        sources: [origin],
        sections: []
      };
      return null;
    };

    Packer.prototype.addSourceMap = function(pack, file, singleLine) {
      var i, j, len, map, out, ref, source, srcBase;
      this.lineOffset += singleLine ? 2 : 3;
      map = file.sourceMap;
      if (map) {
        out = Path.dirname(pack.out);
        srcBase = Path.resolve(Path.dirname(file.path), map.sourceRoot || '');
        map.file = Path.relative(out, file.path);
        map.sourceRoot = '';
        ref = map.sources;
        for (i = j = 0, len = ref.length; j < len; i = ++j) {
          source = ref[i];
          map.sources[i] = Path.relative(out, Path.resolve(srcBase, source));
        }
        this.sourceMap.sections.push({
          offset: {
            line: this.lineOffset,
            column: 0
          },
          map: map
        });
      }
      this.lineOffset += 1 + (singleLine ? 1 : file.numLines);
      return null;
    };

    Packer.prototype.writeSourceMap = function(pack) {
      var mapOut;
      mapOut = pack.out + '.map';
      FSE.ensureFileSync(mapOut);
      FS.writeFileSync(mapOut, JSON.stringify(this.sourceMap), 'utf8');
      pack.code += "\r\n//# sourceMappingURL=" + (Path.basename(mapOut));
      return null;
    };

    Packer.prototype.writePack = function(p) {
      var path;
      this.initSourceMapping(p, 'pack');
      for (path in p.req) {
        this.addSource(p, this.fileMap[path]);
      }
      p.code = p.code.slice(0, -3);
      p.code = getPackCode(p);
      ++this.openFiles;
      this.writeSourceMap(p);
      FSE.ensureFileSync(p.out);
      FS.writeFile(p.out, p.code, 'utf8', (function(_this) {
        return function(error) {
          --_this.openFiles;
          if (error) {
            console.log('ERROR in packer.writePack: ', Path.relative(_this.cfg.base, p.out));
          }
          if (_this.openFiles === 0) {
            _this.completed();
          }
          return null;
        };
      })(this));
      return null;
    };

    Packer.prototype.writeChunk = function(p) {
      var path;
      this.initSourceMapping(p, 'chunk');
      for (path in p.file.parts) {
        this.addSource(p, this.fileMap[path]);
      }
      p.code = p.code.slice(0, -3);
      p.code = getChunkCode(p);
      ++this.openFiles;
      this.writeSourceMap(p);
      FSE.ensureFileSync(p.out);
      FS.writeFile(p.out, p.code, 'utf8', (function(_this) {
        return function(error) {
          --_this.openFiles;
          if (error) {
            console.log('ERROR in packer.writeChunk: ', Path.relative(_this.cfg.base, p.out));
          }
          if (_this.openFiles === 0) {
            _this.completed();
          }
          return null;
        };
      })(this));
      return null;
    };

    Packer.prototype.addSource = function(p, file) {
      var code, moduleId, source;
      ++this.totalModules;
      ++p.numModules;
      source = file.source;
      if (this.nga) {
        source = nga(source, {
          add: true
        }).src;
      }
      moduleId = Path.relative(this.out, file.path);
      code = "// " + file.path + "\r\n" + file.index + ": ";
      if (/.js$/.test(file.path)) {
        code += "function(module, exports, require) {\r\nmodule.id = '" + moduleId + "';\r\n" + source + "\r\n},\r\n";
        this.addSourceMap(p, file, false);
      } else {
        source = source.replace(/'/g, function() {
          var args;
          args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
          if (args[2][args[1] - 1] !== '\\') {
            return "\\'";
          } else {
            return "'";
          }
        });
        source = "'" + source + "'";
        if (/.json$/.test(file.path)) {
          source = "JSON.parse(" + (JMin(source)) + ")";
        }
        source = source.replace(/\r\n|\n/g, '\\n');
        if (/.html$/.test(file.path)) {
          source = source.replace(/\${\s*(require\s*\(\s*\d*?\s*\))\s*}/g, "' + $1 + '");
        }
        code += "function(module, exports, require) {\r\nmodule.exports = " + source + ";\r\n},\r\n";
        this.addSourceMap(p, file, true);
      }
      p.code += code;
      return null;
    };

    Packer.prototype.readFile = function(path, parent) {
      var file;
      file = this.fileMap[path];
      if (file) {
        if (parent) {
          parent.req[path] = true;
          file.ref[parent.path] = true;
        }
        return file;
      }
      file = this.fileMap[path] = {
        index: this.indexer.get(path),
        path: path,
        source: '',
        sourceMap: '',
        numLines: 0,
        ref: {},
        req: {},
        reqAsL: {},
        error: false
      };
      if (this.cfg.watch) {
        this.watcher.add(path);
        this.watcher.add(Path.dirname(path));
      }
      if (parent) {
        parent.req[path] = true;
        file.ref[parent.path] = true;
      }
      ++this.openFiles;
      FS.readFile(path, 'utf8', (function(_this) {
        return function(error, source) {
          var absSourcePath, babelOptions, e, fixFF, i, includeExt, j, len, map, mapPath, numLines, ref, result, sourcePath;
          if (error) {
            file.error = error;
            _this.errors.push({
              path: path,
              line: -1,
              col: -1,
              error: 'file read error'
            });
          } else {
            file.error = null;
            if (/\.js$/.test(path)) {
              if (_this.useUglify) {
                source = source.replace(/process\.env\.NODE_ENV/g, 'NODE_ENV');
                source = source.replace(/\r\n|\n/g, '\n');
                map = _this.getJson(path + '.map');
                _this.uglify = _this.uglify || require('uglify-js');
                try {
                  result = _this.uglify.minify(source, {
                    mangle: false,
                    sourceMap: {
                      content: map,
                      url: Path.basename(path) + '.map'
                    },
                    compress: {
                      global_defs: {
                        'NODE_ENV': _this.NODE_ENV
                      }
                    }
                  });
                } catch (error1) {
                  e = error1;
                  console.log('ERROR while uglifying: ', path, e);
                }
                if (result) {
                  source = result.code;
                  map = JSON.parse(result.map);
                }
              }
              if (_this.useBabel && /node_modules/.test(path) && !/\.umd\./.test(path) && /((^| )import )|((^| )class )|((^| )let )|((^| )const |((^| )export ))/gm.test(source)) {
                Babel = Babel || require('babel-core');
                Babel_es2015 = Babel_es2015 || require('babel-preset-es2015');
                babelOptions = babelOptions || {
                  ast: false,
                  compact: false,
                  presets: [Babel_es2015]
                };
                result = Babel.transform(source, babelOptions);
                source = result.code;
              }
            }
            if (/.js$/.test(path)) {
              mapPath = path + '.map';
              source = source.replace(SINGLE_COMMENT_MAP, '');
              source = source.replace(MULTI_COMMENT_MAP, '');
              numLines = (source || '').split(/\r\n|\n/).length;
              fixFF = _this.cfg.fffMaps;
              includeExt = _this.cfg.externalMaps;
              if (_this.isFile(mapPath) && (path.indexOf(_this.out) === 0 || includeExt)) {
                map = map || _this.getJson(mapPath) || {};
                file.sourceMap = map;
                if (fixFF && map && map.sources) {
                  map.sourcesContent = [];
                  ref = map.sources;
                  for (i = j = 0, len = ref.length; j < len; i = ++j) {
                    sourcePath = ref[i];
                    absSourcePath = Path.resolve(Path.dirname(file.path), map.sourceRoot || '', map.sources[0]);
                    if (fixFF && !map.sourcesContent[i]) {
                      if (_this.isFile(absSourcePath)) {
                        map.sourcesContent.push(FS.readFileSync(absSourcePath, 'utf8'));
                      } else {
                        map.sourcesContent.push('');
                      }
                    }
                  }
                }
              }
            }
            file.moduleId = Path.relative(_this.out, path);
            file.source = source;
            file.numLines = numLines;
            _this.parseFile(file);
          }
          if (--_this.openFiles === 0) {
            _this.writePackages();
          }
          return null;
        };
      })(this));
      return file;
    };

    Packer.prototype.parseFile = function(file) {
      var base, loaderRegex, path, regPos, regex;
      path = file.path;
      base = Path.dirname(path);
      regex = /require\s*\(\s*('|")(.*?)('|")\s*\)/gm;
      regPos = 2;
      loaderRegex = new RegExp('^' + this.cfg.loaderPrefix);
      file.source = file.source.replace(regex, (function(_this) {
        return function() {
          var args, isLoader, loaderRefs, modulePath, name, rfile, rpath;
          args = 1 <= arguments.length ? slice.call(arguments, 0) : [];
          name = _this.correctOut(args[regPos]);
          isLoader = loaderRegex.test(name);
          if (isLoader) {
            name = name.replace(loaderRegex, '');
          }
          if (/\.|\//.test(name[0])) {
            modulePath = _this.getRelModulePath(base, name);
          } else {
            modulePath = _this.getNodeModulePath(base, name);
          }
          if (modulePath) {
            rfile = _this.readFile(modulePath, file);
            if (isLoader) {
              rpath = rfile.path;
              loaderRefs = _this.loaders[rpath] || (_this.loaders[rpath] = {});
              loaderRefs[path] = true;
              file.reqAsL[rpath] = true;
              delete file.req[rpath];
              delete rfile.ref[path];
              return "require(" + rfile.index + ", '" + (_this.getChunkPath(rfile)) + "')";
            }
            return "require(" + rfile.index + ")";
          } else {
            if (!_this.isComment(file.source, args[4])) {
              _this.errors.push({
                path: path,
                line: -1,
                col: -1,
                error: 'packer.parseFile: module "' + name + '" not found'
              });
            }
          }
          return args[0];
        };
      })(this));
      return null;
    };

    Packer.prototype.isComment = function(text, index) {
      var behindComment, char1, char2, chars, insideComment, sameLine;
      sameLine = true;
      behindComment = false;
      while (--index > -1) {
        char1 = text[index];
        char2 = text[index + 1];
        chars = char1 + char2;
        sameLine = sameLine && char1 !== '\n';
        insideComment = chars === '/*';
        behindComment = chars === '*/';
        if (sameLine && chars === '//') {
          return true;
        }
        if (insideComment) {
          return true;
        }
        if (behindComment) {
          return false;
        }
      }
      return false;
    };

    Packer.prototype.getRelModulePath = function(base, moduleName) {
      var ext, file, path;
      ext = this.testExt(moduleName, 'js');
      path = Path.resolve(base, moduleName);
      if (this.isFile(file = path + ext)) {
        return file;
      }
      if (this.isFile(file = Path.join(path, 'index.js'))) {
        return file;
      }
      if (ext && this.isFile(path)) {
        return path;
      }
      return null;
    };

    Packer.prototype.getNodeModulePath = function(base, moduleName) {
      var ext, file, json, main, modulePath, nodePath;
      nodePath = Path.join(base, 'node_modules');
      modulePath = Path.join(nodePath, moduleName);
      if (this.isDir(nodePath)) {
        ext = this.testExt(moduleName, 'js');
        if (this.isFile(file = modulePath + ext)) {
          return file;
        }
        file = Path.join(modulePath, 'package.json');
        try {
          json = this.getJson(file);
          main = json != null ? json.main : void 0;
        } catch (error1) {

        }
        if (main) {
          ext = this.testExt(main, 'js');
          if (this.isFile(file = Path.join(modulePath, main + ext))) {
            return file;
          }
        }
        if (this.isFile(file = Path.join(modulePath, 'index.js'))) {
          return file;
        }
      }
      if (base && base !== '/') {
        return this.getNodeModulePath(Path.resolve(base, '..'), moduleName);
      }

      /* TODO: implement this???
       * try modules shipped with werkzeug
      if base != PROCESS_BASE
          return @getNodeModulePath PROCESS_BASE, moduleName
       */
      return null;
    };

    Packer.prototype.completed = function() {
      var d, e, j, len, ref;
      if (this.errors.length) {
        ref = this.errors;
        for (j = 0, len = ref.length; j < len; j++) {
          e = ref[j];
          console.log("ERROR in " + (Path.relative(this.cfg.base, e.path)) + ": " + e.error);
        }
      }
      d = new Date();
      console.log("packer ready " + (this.errors.length ? 'with errors ' : '✓ ') + "(" + (d.getHours()) + ":" + (d.getMinutes()) + ":" + (d.getSeconds()) + " " + (d.getFullYear()) + "." + (d.getMonth()) + "." + (d.getDate()) + ")");
      return null;
    };

    Packer.prototype.testExt = function(name, ext) {
      if (new RegExp('\\' + ext + '$').test(name)) {
        return '';
      }
      return '.' + ext;
    };

    Packer.prototype.isDir = function(path) {
      var stat;
      stat = this.getStat(path);
      return (stat != null ? stat.isDirectory() : void 0) || false;
    };

    Packer.prototype.isFile = function(path) {
      var stat;
      stat = this.getStat(path);
      return (stat != null ? stat.isFile() : void 0) || false;
    };

    Packer.prototype.getStat = function(path) {
      var stat;
      try {
        stat = FS.statSync(path);
      } catch (error1) {}
      return stat;
    };

    Packer.prototype.getText = function(path) {
      var text;
      try {
        text = FS.readFileSync(path, 'utf8');
      } catch (error1) {}
      return text;
    };

    Packer.prototype.getJson = function(path) {
      var json, text;
      text = this.getText(path);
      try {
        json = JSON.parse(text);
      } catch (error1) {}
      return json;
    };

    Packer.prototype.correctOut = function(path) {
      if (CSS_REG.test(path)) {
        return path.replace(CSS_REG, '.css');
      }
      if (JS_REG.test(path)) {
        return path.replace(JS_REG, '.js');
      }
      return path;
    };

    Packer.prototype.isRequired = function(file) {
      return Dict.hasKeys(file.ref || this.loaders[file.path]);
    };

    Packer.prototype.removeSources = function(path) {
      FS.unlinkSync(path);
      FS.unlinkSync(path + '.map');
      return null;
    };

    return Packer;

  })();

  module.exports = Packer;

}).call(this);
