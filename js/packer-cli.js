// Generated by CoffeeScript 1.12.6
(function() {
  var Packer, Path, cfg, cfgFromArgs, error, packer, pathForFlag;

  Path = require('path');

  Packer = require('./packer');

  error = null;

  cfg = {
    watch: false,
    bundles: [],
    base: process.cwd(),
    useBabel: true,
    useUglify: false,
    loaderPrefix: 'es6-promise!',
    chunks: './js/chunk_',
    fffMaps: true,
    externalMaps: false
  };

  pathForFlag = function(path, flag, name) {
    if (/^-\w$|^-\w\w$/.test(path)) {
      error = name + ' expected behind ' + flag + ' flag. Got another flag: ' + path;
      path = null;
    } else if (!path || !path.length) {
      error = name + ' expected behind ' + flag + ' flag.';
      path = null;
    }
    return path;
  };

  cfgFromArgs = function() {
    var arg, args, basePath, inPath, index, outPath, prefix, use;
    args = process.argv.slice(2);
    index = 0;
    while (index < args.length) {
      switch (arg = args[index]) {
        case '-p' || '--pack':
          inPath = pathForFlag(args[index + 1], arg, 'Input path');
          if (!error) {
            if (!error) {
              outPath = pathForFlag(args[index + 2], arg, 'Output path');
            }
            if (error) {
              outPath = inPath.replace(/\.js$/, '.pack.js');
              error = null;
              index = index + 2;
              cfg.bundles.push({
                "in": inPath,
                out: outPath
              });
            } else {
              index = index + 3;
              cfg.bundles.push({
                "in": inPath,
                out: outPath
              });
            }
          }
          break;
        case '-bp' || '--base-path':
          basePath = pathForFlag(args[index + 1], arg, 'Base path');
          if (!error) {
            if (Path.isAbsolute(basePath)) {
              cfg.base = basePath;
            } else {
              cfg.base = Path.resolve(process.cwd(), basePath);
            }
            index = index + 2;
          }
          break;
        case '-w' || '--watch':
          use = args[index + 1];
          if (use === 'false' || use === 'true') {
            cfg.watch = use === 'true';
            index = index + 2;
          } else {
            cfg.watch = true;
            ++index;
          }
          break;
        case '-ub' || '--use-babel':
          use = args[index + 1];
          if (use === 'false' || use === 'true') {
            cfg.useBabel = use === 'true';
            index = index + 2;
          } else {
            cfg.useBabel = true;
            ++index;
          }
          break;
        case '-uu' || '--use-uglify':
          use = args[index + 1];
          if (use === 'false' || use === 'true') {
            cfg.useUglify = use === 'true';
            index = index + 2;
          } else {
            cfg.useUglify = true;
            ++index;
          }
          break;
        case '-im' || '--inline-maps':
          use = args[index + 1];
          if (use === 'false' || use === 'true') {
            cfg.fffMaps = use === 'true';
            index = index + 2;
          } else {
            cfg.fffMaps = true;
            ++index;
          }
          break;
        case '-em' || '--external-maps':
          use = args[index + 1];
          if (use === 'false' || use === 'true') {
            cfg.externalMaps = use === 'true';
            index = index + 2;
          } else {
            cfg.externalMaps = true;
            ++index;
          }
          break;
        case '-lp' || '--loader-prefix':
          prefix = args[index + 1];
          if (!prefix) {
            error = 'Prefix expected behind ' + arg + ' flag.';
          }
          if (/^-\w$/.test(prefix)) {
            error = 'Prefix expected behind ' + arg + ' flag. Got another flag: ' + prefix;
          } else {
            cfg.loaderPrefix = prefix;
            index = index + 2;
          }
          break;
        case '-cp' || '--chunk-prefix':
          prefix = args[index + 1];
          if (!prefix) {
            error = 'Prefix expected behind ' + arg + ' flag.';
          }
          if (/^-\w$/.test(prefix)) {
            error = 'Prefix expected behind ' + arg + ' flag. Got another flag: ' + prefix;
          } else {
            cfg.chunks = prefix;
            index = index + 2;
          }
          break;
        default:
          error = 'Unknown or unexpected argument: ' + arg;
      }
      if (error) {
        return;
      }
    }
    return null;
  };

  cfgFromArgs();

  if (error) {
    console.log('Error: ', error);
  } else {
    packer = new Packer(cfg);
  }

}).call(this);